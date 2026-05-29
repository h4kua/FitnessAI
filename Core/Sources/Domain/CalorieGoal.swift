public struct CalorieGoal: Sendable, Equatable, Codable {
    public let activeEnergyGoal: Double

    public init(activeEnergyGoal: Double) {
        self.activeEnergyGoal = activeEnergyGoal
    }
}
