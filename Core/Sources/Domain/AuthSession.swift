import Foundation

public struct AuthSession: Sendable, Equatable, Codable {
    public let accessToken: String
    public let expiresAt: Date
    public let refreshToken: String
    public let userProfile: UserProfile

    public init(
        accessToken: String,
        expiresAt: Date,
        refreshToken: String,
        userProfile: UserProfile
    ) {
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.refreshToken = refreshToken
        self.userProfile = userProfile
    }

    public var isExpired: Bool {
        expiresAt <= Date()
    }

    public var requiresRefresh: Bool {
        expiresAt.timeIntervalSinceNow <= 120
    }
}
