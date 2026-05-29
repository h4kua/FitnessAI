#if canImport(Core)
import Core
#endif

public struct WorkoutSafetyPolicy: WorkoutSafetyChecking {
    public init() {}

    public func check(plan: WorkoutPlan, input: RecommendationInput) -> SafetyResult {
        let completionRatio = input.activeEnergyBurned / max(input.targetCalories, 1)
        var warnings: [String] = []

        // Already well above goal — flag high-intensity plans
        if completionRatio > 1.2 && plan.intensity == .high {
            return .needsLowerIntensity
        }

        // Duration exceeds available time
        if plan.durationMinutes > input.availableMinutes + 5 {
            return .needsShorterDuration
        }

        // Consecutive high-intensity days
        let recentHighDays = input.recentSessions.prefix(2).filter { session in
            session.estimatedCalories > 400
        }.count
        if recentHighDays >= 2 && plan.intensity == .high {
            warnings.append("You've had two high-intensity sessions recently. Consider extra recovery time.")
        }

        return warnings.isEmpty ? .approved : .approvedWithWarnings(warnings)
    }
}
