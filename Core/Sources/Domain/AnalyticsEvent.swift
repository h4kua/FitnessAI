import Foundation

public struct AnalyticsEvent: Sendable, Equatable, Codable {
    public let name: String
    public let metadata: [String: String]
    public let occurredAt: Date

    public init(
        name: String,
        metadata: [String: String] = [:],
        occurredAt: Date = Date()
    ) {
        self.name = name
        self.metadata = metadata
        self.occurredAt = occurredAt
    }
}
