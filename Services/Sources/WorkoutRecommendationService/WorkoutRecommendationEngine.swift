#if canImport(Core)
import Core
#endif
#if canImport(Infrastructure)
import Infrastructure
#endif
import Foundation

public actor WorkoutRecommendationEngine: WorkoutRecommendationProviding {
    private let catalog: any ExerciseCatalogProviding
    private let calorieEstimator: any CalorieEstimating
    private let safetyChecker: any WorkoutSafetyChecking
    private let logger: AppLogger

    public init(
        catalog: any ExerciseCatalogProviding,
        calorieEstimator: any CalorieEstimating,
        safetyChecker: any WorkoutSafetyChecking,
        logger: AppLogger
    ) {
        self.catalog = catalog
        self.calorieEstimator = calorieEstimator
        self.safetyChecker = safetyChecker
        self.logger = logger
    }

    public func recommend(for input: RecommendationInput) async throws -> WorkoutPlan {
        logger.info("Generating workout plan — target: \(Int(input.targetCalories)) kcal, available: \(input.availableMinutes) min")

        let candidates = try await fetchCandidates(for: input)
        let scored = score(candidates: candidates, input: input)
        let best = scored.prefix(5).map(\.template)

        let plan = try await buildPlan(from: best, input: input)
        let checked = applySafetyCheck(plan: plan, input: input)
        return checked
    }

    // MARK: - Private

    private func fetchCandidates(for input: RecommendationInput) async throws -> [ExerciseTemplate] {
        let exerciseType = exerciseType(for: input)
        let query = ExerciseSearchQuery(
            type: exerciseType,
            difficulty: input.preferredIntensity
        )

        do {
            let results = try await catalog.exercises(matching: query)
            if results.isEmpty {
                return builtInFallbacks(for: input)
            }
            return results
        } catch {
            logger.warning("Catalog fetch failed: \(error). Using built-in fallbacks.")
            return builtInFallbacks(for: input)
        }
    }

    private struct ScoredTemplate {
        let template: ExerciseTemplate
        let score: Double
    }

    private func score(candidates: [ExerciseTemplate], input: RecommendationInput) -> [ScoredTemplate] {
        let remainingCalories = input.targetCalories - input.activeEnergyBurned
        let completionRatio = min(input.activeEnergyBurned / max(input.targetCalories, 1), 1.0)

        return candidates.map { template in
            let calorieFit = calorieFitScore(template: template, remaining: remainingCalories, input: input)
            let durationFit = durationFitScore(template: template, available: input.availableMinutes)
            let intensityFit = intensityFitScore(template: template, preferred: input.preferredIntensity)
            let noveltyFit = noveltyFitScore(template: template, recentSessions: input.recentSessions)
            let equipmentFit = equipmentFitScore(template: template)
            let safetyPenalty = safetyPenaltyScore(completionRatio: completionRatio, template: template)

            let total = calorieFit * 0.45
                + durationFit * 0.20
                + intensityFit * 0.20
                + noveltyFit * 0.10
                + equipmentFit * 0.05
                - safetyPenalty

            return ScoredTemplate(template: template, score: total)
        }.sorted { $0.score > $1.score }
    }

    private func calorieFitScore(template: ExerciseTemplate, remaining: Double, input: RecommendationInput) -> Double {
        guard remaining > 0 else { return 0.3 }
        let durationMatch = Double(input.availableMinutes)
        let isHighBurn = template.type == .cardio || template.type == .plyometrics
        let estimatedBurn = isHighBurn ? durationMatch * 8 : durationMatch * 5
        let ratio = min(estimatedBurn / remaining, 2.0)
        return max(0, 1 - abs(ratio - 1))
    }

    private func durationFitScore(template: ExerciseTemplate, available: Int) -> Double {
        let typicalDuration: Double
        switch template.type {
        case .cardio, .plyometrics: typicalDuration = 30
        case .strength, .powerlifting, .olympicWeightlifting, .strongman: typicalDuration = 40
        case .stretching: typicalDuration = 15
        }
        let ratio = Double(available) / typicalDuration
        return max(0, 1 - abs(ratio - 1) * 0.5)
    }

    private func intensityFitScore(template: ExerciseTemplate, preferred: WorkoutIntensity) -> Double {
        template.difficulty == preferred ? 1.0 : 0.3
    }

    private func noveltyFitScore(template: ExerciseTemplate, recentSessions: [WorkoutSessionSummary]) -> Double {
        let recentTitles = Set(recentSessions.prefix(7).map { $0.title.lowercased() })
        return recentTitles.contains(template.name.lowercased()) ? 0.2 : 1.0
    }

    private func equipmentFitScore(template: ExerciseTemplate) -> Double {
        let bodyweightTypes = ["body only", "none", ""]
        let isBodyweight = template.equipment.isEmpty
            || template.equipment.allSatisfy { bodyweightTypes.contains($0.lowercased()) }
        return isBodyweight ? 1.0 : 0.6
    }

    private func safetyPenaltyScore(completionRatio: Double, template: ExerciseTemplate) -> Double {
        if completionRatio > 0.85 && template.difficulty == .high {
            return 0.4
        }
        return 0
    }

    private func buildPlan(from templates: [ExerciseTemplate], input: RecommendationInput) async throws -> WorkoutPlan {
        guard let primary = templates.first else {
            return builtInPlan(for: input)
        }

        let timePerExercise = max(5, input.availableMinutes / max(templates.count, 1))

        var totalCalories: Double = 0
        var exercises: [ExerciseBlock] = []

        for template in templates {
            let estimate: CalorieEstimate
            do {
                estimate = try await calorieEstimator.estimate(
                    activityName: template.name,
                    durationMinutes: timePerExercise,
                    weightPounds: input.bodyWeightPounds
                )
            } catch {
                estimate = CalorieEstimate(
                    activityName: template.name,
                    estimatedCalories: Double(timePerExercise) * 5,
                    durationMinutes: timePerExercise
                )
            }

            totalCalories += estimate.estimatedCalories
            exercises.append(ExerciseBlock(
                id: template.id,
                name: template.name,
                durationMinutes: timePerExercise,
                instructions: template.instructions,
                safetyNote: template.safetyInfo
            ))
        }

        let remaining = input.targetCalories - input.activeEnergyBurned
        let rationale = buildRationale(primary: primary, remaining: remaining, input: input)

        return WorkoutPlan(
            title: primary.name,
            estimatedCalories: totalCalories,
            durationMinutes: input.availableMinutes,
            intensity: input.preferredIntensity,
            exercises: exercises,
            sourceProvider: primary.sourceProvider,
            safetyNotes: templates.compactMap(\.safetyInfo),
            rationale: rationale
        )
    }

    private func applySafetyCheck(plan: WorkoutPlan, input: RecommendationInput) -> WorkoutPlan {
        let result = safetyChecker.check(plan: plan, input: input)
        switch result {
        case .approved:
            return plan
        case .approvedWithWarnings(let warnings):
            return WorkoutPlan(
                id: plan.id,
                title: plan.title,
                estimatedCalories: plan.estimatedCalories,
                durationMinutes: plan.durationMinutes,
                intensity: plan.intensity,
                exercises: plan.exercises,
                sourceProvider: plan.sourceProvider,
                safetyNotes: plan.safetyNotes + warnings,
                rationale: plan.rationale
            )
        case .needsLowerIntensity:
            let adjusted = adjustIntensityDown(plan: plan)
            logger.info("Safety: plan intensity reduced to \(adjusted.intensity.rawValue)")
            return adjusted
        case .needsShorterDuration:
            let adjusted = shortenPlan(plan: plan)
            logger.info("Safety: plan duration reduced to \(adjusted.durationMinutes) min")
            return adjusted
        }
    }

    private func adjustIntensityDown(plan: WorkoutPlan) -> WorkoutPlan {
        let newIntensity: WorkoutIntensity = plan.intensity == .high ? .moderate : .low
        return WorkoutPlan(
            id: plan.id,
            title: plan.title,
            estimatedCalories: plan.estimatedCalories * 0.8,
            durationMinutes: plan.durationMinutes,
            intensity: newIntensity,
            exercises: plan.exercises,
            sourceProvider: plan.sourceProvider,
            safetyNotes: plan.safetyNotes + ["Intensity reduced for recovery."],
            rationale: plan.rationale
        )
    }

    private func shortenPlan(plan: WorkoutPlan) -> WorkoutPlan {
        let newDuration = max(10, plan.durationMinutes - 10)
        let ratio = Double(newDuration) / Double(plan.durationMinutes)
        return WorkoutPlan(
            id: plan.id,
            title: plan.title,
            estimatedCalories: plan.estimatedCalories * ratio,
            durationMinutes: newDuration,
            intensity: plan.intensity,
            exercises: plan.exercises,
            sourceProvider: plan.sourceProvider,
            safetyNotes: plan.safetyNotes + ["Duration shortened for safety."],
            rationale: plan.rationale
        )
    }

    private func buildRationale(primary: ExerciseTemplate, remaining: Double, input: RecommendationInput) -> String {
        let remainingInt = Int(remaining)
        let rationale: String
        if remaining <= 0 {
            rationale = "You've met today's active energy goal. This recovery session helps you stay consistent tomorrow."
        } else if remaining > 300 {
            rationale = "\(remainingInt) kcal remaining — \(primary.name) at \(input.preferredIntensity.rawValue) intensity is an efficient way to close the gap in \(input.availableMinutes) minutes."
        } else {
            rationale = "\(remainingInt) kcal left for the day. A \(input.preferredIntensity.rawValue) \(primary.name) session fits your schedule and completes your goal."
        }
        return rationale
    }

    private func exerciseType(for input: RecommendationInput) -> ExerciseType {
        let remaining = input.targetCalories - input.activeEnergyBurned
        if remaining > 250 {
            return .cardio
        } else if remaining > 100 {
            return .strength
        } else {
            return .stretching
        }
    }

    // MARK: - Built-in fallbacks (offline / API unavailable)

    private func builtInFallbacks(for input: RecommendationInput) -> [ExerciseTemplate] {
        [
            ExerciseTemplate(
                id: "builtin-cardio-walk",
                name: "Brisk Walk",
                type: .cardio,
                difficulty: .low,
                equipment: [],
                instructions: "Walk at a brisk pace, maintaining a conversational effort level.",
                sourceProvider: "Built-in"
            ),
            ExerciseTemplate(
                id: "builtin-bodyweight-squat",
                name: "Bodyweight Squat",
                type: .strength,
                difficulty: .moderate,
                equipment: [],
                instructions: "Stand feet shoulder-width apart, lower until thighs are parallel, then drive back up.",
                sourceProvider: "Built-in"
            ),
            ExerciseTemplate(
                id: "builtin-stretch-hip",
                name: "Hip Flexor Stretch",
                type: .stretching,
                difficulty: .low,
                equipment: [],
                instructions: "Kneel on one knee, shift hips forward gently for 30 seconds each side.",
                sourceProvider: "Built-in"
            )
        ]
    }

    private func builtInPlan(for input: RecommendationInput) -> WorkoutPlan {
        WorkoutPlan(
            title: "Quick Movement Break",
            estimatedCalories: Double(input.availableMinutes) * 5,
            durationMinutes: input.availableMinutes,
            intensity: .low,
            exercises: [
                ExerciseBlock(
                    id: "builtin-walk",
                    name: "Brisk Walk",
                    durationMinutes: input.availableMinutes,
                    instructions: "Walk at a brisk pace.",
                    safetyNote: nil
                )
            ],
            sourceProvider: "Built-in",
            safetyNotes: [],
            rationale: "A short movement break to keep you active today."
        )
    }
}
