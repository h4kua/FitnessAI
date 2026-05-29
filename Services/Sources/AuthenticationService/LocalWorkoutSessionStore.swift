#if canImport(Core)
import Core
#endif
import Foundation

/// Stores workout sessions as JSON in the app's Application Support directory.
/// Replaces FirebaseWorkoutSessionStore — no network or gRPC dependency.
public actor LocalWorkoutSessionStore: WorkoutSessionStoring {
    private let fileURL: URL

    public init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FitnessCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("workout_sessions.json")
    }

    public func save(_ session: WorkoutSessionSummary) async throws {
        var all = (try? load()) ?? []
        all.removeAll { $0.id == session.id }
        all.insert(session, at: 0)
        let data = try JSONEncoder().encode(all)
        try data.write(to: fileURL, options: .atomic)
    }

    public func fetchRecent(limit: Int) async throws -> [WorkoutSessionSummary] {
        let all = (try? load()) ?? []
        return Array(all.prefix(limit))
    }

    // MARK: - Private

    private func load() throws -> [WorkoutSessionSummary] {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([WorkoutSessionSummary].self, from: data)
    }
}
