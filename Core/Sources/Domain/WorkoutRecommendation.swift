import Foundation

public enum WorkoutCategory: String, Sendable, Equatable, Codable {
    case cardio
    case mobility
    case recovery
    case strength
}

public struct WorkoutRecommendation: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let category: WorkoutCategory
    public let durationMinutes: Int
    public let intensity: String
    public let rationale: String
    public let summary: String
    public let title: String

    public init(
        id: UUID = UUID(),
        category: WorkoutCategory,
        durationMinutes: Int,
        intensity: String,
        rationale: String,
        summary: String,
        title: String
    ) {
        self.id = id
        self.category = category
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.rationale = rationale
        self.summary = summary
        self.title = title
    }
}
