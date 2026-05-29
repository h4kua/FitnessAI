public struct CalorieEstimate: Sendable, Equatable {
    public let activityName: String
    public let estimatedCalories: Double
    public let durationMinutes: Int

    public init(activityName: String, estimatedCalories: Double, durationMinutes: Int) {
        self.activityName = activityName
        self.estimatedCalories = estimatedCalories
        self.durationMinutes = durationMinutes
    }
}
