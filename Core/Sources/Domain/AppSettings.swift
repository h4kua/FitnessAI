public struct AppSettings: Sendable, Equatable, Codable {
    public var analyticsEnabled: Bool
    public var coachingHintsEnabled: Bool
    public var dailyCalorieGoal: CalorieGoal

    public init(
        analyticsEnabled: Bool,
        coachingHintsEnabled: Bool,
        dailyCalorieGoal: CalorieGoal = CalorieGoal(activeEnergyGoal: 600)
    ) {
        self.analyticsEnabled = analyticsEnabled
        self.coachingHintsEnabled = coachingHintsEnabled
        self.dailyCalorieGoal = dailyCalorieGoal
    }
}

public extension AppSettings {
    static let `default` = AppSettings(
        analyticsEnabled: true,
        coachingHintsEnabled: true,
        dailyCalorieGoal: CalorieGoal(activeEnergyGoal: 600)
    )
}
