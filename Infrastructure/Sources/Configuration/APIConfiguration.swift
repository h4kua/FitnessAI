import Foundation

public struct APIConfiguration: Sendable, Equatable {
    public let analyticsBaseURL: URL?
    public let apiBaseURL: URL
    public let requestTimeout: TimeInterval
    public let supportsGraphQL: Bool

    public init(
        analyticsBaseURL: URL?,
        apiBaseURL: URL,
        requestTimeout: TimeInterval,
        supportsGraphQL: Bool
    ) {
        self.analyticsBaseURL = analyticsBaseURL
        self.apiBaseURL = apiBaseURL
        self.requestTimeout = requestTimeout
        self.supportsGraphQL = supportsGraphQL
    }
}
