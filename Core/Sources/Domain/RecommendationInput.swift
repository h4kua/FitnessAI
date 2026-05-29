public struct RecommendationInput: Sendable, Equatable {
    public let targetCalories: Double
    public let activeEnergyBurned: Double
    public let availableMinutes: Int
    public let preferredIntensity: WorkoutIntensity
    public let bodyWeightPounds: Double?
    public let recentSessions: [WorkoutSessionSummary]

    public init(
        targetCalories: Double,
        activeEnergyBurned: Double,
        availableMinutes: Int,
        preferredIntensity: WorkoutIntensity,
        bodyWeightPounds: Double? = nil,
        recentSessions: [WorkoutSessionSummary] = []
    ) {
        self.targetCalories = targetCalories
        self.activeEnergyBurned = activeEnergyBurned
        self.availableMinutes = availableMinutes
        self.preferredIntensity = preferredIntensity
        self.bodyWeightPounds = bodyWeightPounds
        self.recentSessions = recentSessions
    }
}
