public struct ExerciseSearchQuery: Sendable, Equatable {
    public let type: ExerciseType?
    public let muscle: String?
    public let difficulty: WorkoutIntensity?
    public let offset: Int

    public init(
        type: ExerciseType? = nil,
        muscle: String? = nil,
        difficulty: WorkoutIntensity? = nil,
        offset: Int = 0
    ) {
        self.type = type
        self.muscle = muscle
        self.difficulty = difficulty
        self.offset = offset
    }
}
