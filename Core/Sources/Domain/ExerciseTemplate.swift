public struct ExerciseTemplate: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let name: String
    public let type: ExerciseType
    public let difficulty: WorkoutIntensity
    public let primaryMuscle: String?
    public let equipment: [String]
    public let instructions: String
    public let safetyInfo: String?
    public let sourceProvider: String

    public init(
        id: String,
        name: String,
        type: ExerciseType,
        difficulty: WorkoutIntensity,
        primaryMuscle: String? = nil,
        equipment: [String] = [],
        instructions: String,
        safetyInfo: String? = nil,
        sourceProvider: String
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.difficulty = difficulty
        self.primaryMuscle = primaryMuscle
        self.equipment = equipment
        self.instructions = instructions
        self.safetyInfo = safetyInfo
        self.sourceProvider = sourceProvider
    }
}
