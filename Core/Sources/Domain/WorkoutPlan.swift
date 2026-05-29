import Foundation

public struct WorkoutPlan: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    public let title: String
    public let estimatedCalories: Double
    public let durationMinutes: Int
    public let intensity: WorkoutIntensity
    public let exercises: [ExerciseBlock]
    public let sourceProvider: String
    public let safetyNotes: [String]
    public let rationale: String

    public init(
        id: String = UUID().uuidString,
        title: String,
        estimatedCalories: Double,
        durationMinutes: Int,
        intensity: WorkoutIntensity,
        exercises: [ExerciseBlock],
        sourceProvider: String,
        safetyNotes: [String] = [],
        rationale: String
    ) {
        self.id = id
        self.title = title
        self.estimatedCalories = estimatedCalories
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.exercises = exercises
        self.sourceProvider = sourceProvider
        self.safetyNotes = safetyNotes
        self.rationale = rationale
    }
}
