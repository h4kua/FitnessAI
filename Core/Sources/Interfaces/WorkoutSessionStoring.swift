import Foundation

public protocol WorkoutSessionStoring: Sendable {
    func save(_ session: WorkoutSessionSummary) async throws
    func fetchRecent(limit: Int) async throws -> [WorkoutSessionSummary]
}
