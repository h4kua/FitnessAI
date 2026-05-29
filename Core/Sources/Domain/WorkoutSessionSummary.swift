import Foundation

public struct WorkoutSessionSummary: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let date: Date
    public let title: String
    public let estimatedCalories: Double
    public let durationMinutes: Int

    public init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        estimatedCalories: Double,
        durationMinutes: Int
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.estimatedCalories = estimatedCalories
        self.durationMinutes = durationMinutes
    }
}
