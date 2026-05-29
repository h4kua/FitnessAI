import Foundation

public struct UserProfile: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public var analyticsConsent: Bool
    public var dailyCalorieGoal: CalorieGoal
    public var displayName: String

    public init(
        id: UUID = UUID(),
        analyticsConsent: Bool,
        dailyCalorieGoal: CalorieGoal,
        displayName: String
    ) {
        self.id = id
        self.analyticsConsent = analyticsConsent
        self.dailyCalorieGoal = dailyCalorieGoal
        self.displayName = displayName
    }
}
