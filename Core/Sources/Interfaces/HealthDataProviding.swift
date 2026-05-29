import Foundation

public protocol HealthDataProviding: Sendable {
    func authorizationStatus() async -> HealthAuthorizationStatus
    func calorieSummary(for date: Date, goal: CalorieGoal) async throws -> CalorieSummary
    func requestAuthorization() async throws -> HealthAuthorizationStatus
}
