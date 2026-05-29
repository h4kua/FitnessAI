public protocol WorkoutRecommendationProviding: Sendable {
    func recommend(for input: RecommendationInput) async throws -> WorkoutPlan
}
