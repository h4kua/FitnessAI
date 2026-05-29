public struct ExerciseBlock: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let name: String
    public let durationMinutes: Int
    public let sets: Int?
    public let reps: Int?
    public let instructions: String
    public let safetyNote: String?

    public init(
        id: String,
        name: String,
        durationMinutes: Int,
        sets: Int? = nil,
        reps: Int? = nil,
        instructions: String,
        safetyNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
        self.sets = sets
        self.reps = reps
        self.instructions = instructions
        self.safetyNote = safetyNote
    }
}
