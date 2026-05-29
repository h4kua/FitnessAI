#if canImport(SwiftData)
#if canImport(Core)
import Core
#endif
import Foundation
import SwiftData

@available(iOS 17.0, macOS 14.0, *)
@Model
public final class WorkoutSessionRecord {
    public var id: UUID
    public var date: Date
    public var title: String
    public var estimatedCalories: Double
    public var durationMinutes: Int

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

    public var asSummary: WorkoutSessionSummary {
        WorkoutSessionSummary(
            id: id,
            date: date,
            title: title,
            estimatedCalories: estimatedCalories,
            durationMinutes: durationMinutes
        )
    }
}

@available(iOS 17.0, macOS 14.0, *)
public extension WorkoutSessionSummary {
    var asRecord: WorkoutSessionRecord {
        WorkoutSessionRecord(
            id: id,
            date: date,
            title: title,
            estimatedCalories: estimatedCalories,
            durationMinutes: durationMinutes
        )
    }
}
#endif

