#if canImport(SwiftData)
#if canImport(Core)
import Core
#endif
import Foundation
import SwiftData

@available(iOS 17.0, macOS 14.0, *)
public actor SwiftDataWorkoutSessionStore: WorkoutSessionStoring {
    private let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public func save(_ session: WorkoutSessionSummary) async throws {
        let context = ModelContext(container)
        let record = session.asRecord
        context.insert(record)
        try context.save()
    }

    public func fetchRecent(limit: Int) async throws -> [WorkoutSessionSummary] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<WorkoutSessionRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let records = try context.fetch(descriptor)
        return records.map(\.asSummary)
    }
}
#endif
