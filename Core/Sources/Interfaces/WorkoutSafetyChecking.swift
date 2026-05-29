public protocol WorkoutSafetyChecking: Sendable {
    func check(plan: WorkoutPlan, input: RecommendationInput) -> SafetyResult
}
