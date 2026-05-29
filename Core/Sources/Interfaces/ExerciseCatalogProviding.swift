public protocol ExerciseCatalogProviding: Sendable {
    func exercises(matching query: ExerciseSearchQuery) async throws -> [ExerciseTemplate]
}
