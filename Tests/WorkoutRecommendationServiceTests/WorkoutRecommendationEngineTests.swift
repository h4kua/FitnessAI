import Core
import Infrastructure
import TestSupport
import WorkoutRecommendationService
import XCTest

final class WorkoutRecommendationEngineTests: XCTestCase {
    private func makeEngine(
        catalogTemplates: [ExerciseTemplate] = [.stub],
        caloriesPerMinute: Double = 8,
        safetyResult: SafetyResult = .approved
    ) -> WorkoutRecommendationEngine {
        WorkoutRecommendationEngine(
            catalog: MockExerciseCatalog(templates: catalogTemplates),
            calorieEstimator: MockCalorieEstimator(caloriesPerMinute: caloriesPerMinute),
            safetyChecker: MockSafetyChecker(result: safetyResult),
            logger: AppLogger(category: "Tests")
        )
    }

    private func makeInput(
        targetCalories: Double = 600,
        activeEnergyBurned: Double = 200,
        availableMinutes: Int = 30,
        preferredIntensity: WorkoutIntensity = .moderate,
        recentSessions: [WorkoutSessionSummary] = []
    ) -> RecommendationInput {
        RecommendationInput(
            targetCalories: targetCalories,
            activeEnergyBurned: activeEnergyBurned,
            availableMinutes: availableMinutes,
            preferredIntensity: preferredIntensity,
            recentSessions: recentSessions
        )
    }

    func testReturnsWorkoutPlanWithExercises() async throws {
        let engine = makeEngine()
        let plan = try await engine.recommend(for: makeInput())

        XCTAssertFalse(plan.exercises.isEmpty)
        XCTAssertGreaterThan(plan.estimatedCalories, 0)
    }

    func testPlanDurationMatchesAvailableMinutes() async throws {
        let engine = makeEngine()
        let plan = try await engine.recommend(for: makeInput(availableMinutes: 45))

        XCTAssertEqual(plan.durationMinutes, 45)
    }

    func testPlanIntensityMatchesPreferred() async throws {
        let engine = makeEngine()
        let plan = try await engine.recommend(for: makeInput(preferredIntensity: .high))

        XCTAssertEqual(plan.intensity, .high)
    }

    func testSafetyWarningsAreAppendedToSafetyNotes() async throws {
        let warnings = ["You've had two high-intensity sessions recently."]
        let engine = makeEngine(safetyResult: .approvedWithWarnings(warnings))
        let plan = try await engine.recommend(for: makeInput())

        XCTAssertTrue(plan.safetyNotes.contains(where: { warnings.contains($0) }))
    }

    func testNeedsLowerIntensityReducesIntensity() async throws {
        let engine = makeEngine(safetyResult: .needsLowerIntensity)
        let plan = try await engine.recommend(for: makeInput(preferredIntensity: .high))

        XCTAssertNotEqual(plan.intensity, .high)
    }

    func testNeedsShorterDurationReducesDuration() async throws {
        let engine = makeEngine(safetyResult: .needsShorterDuration)
        let plan = try await engine.recommend(for: makeInput(availableMinutes: 40))

        XCTAssertLessThan(plan.durationMinutes, 40)
    }

    func testFallsBackToBuiltInsWhenCatalogReturnsEmpty() async throws {
        let emptyCatalog = MockExerciseCatalog(templates: [])
        let engine = WorkoutRecommendationEngine(
            catalog: emptyCatalog,
            calorieEstimator: MockCalorieEstimator(),
            safetyChecker: MockSafetyChecker(),
            logger: AppLogger(category: "Tests")
        )
        let plan = try await engine.recommend(for: makeInput())

        XCTAssertFalse(plan.exercises.isEmpty)
    }

    func testRationaleIsNotEmpty() async throws {
        let engine = makeEngine()
        let plan = try await engine.recommend(for: makeInput())

        XCTAssertFalse(plan.rationale.isEmpty)
    }
}
