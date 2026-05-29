#if canImport(Core)
import Core
#endif
import Foundation
#if canImport(Infrastructure)
import Infrastructure
#endif

public actor RemoteAuthenticationService: AuthenticationProviding {
    private struct RefreshPayload: Encodable {
        let refreshToken: String
    }

    private struct SignInPayload: Encodable {
        let displayName: String
    }

    private struct SessionResponse: Decodable {
        let accessToken: String
        let expiresAt: Date
        let refreshToken: String
        let user: UserResponse
    }

    private struct UserResponse: Decodable {
        let analyticsConsent: Bool
        let dailyCalorieGoal: Double
        let displayName: String
        let id: UUID
    }

    private let client: HTTPClient
    private let logger: AppLogger
    private let requestBuilder: APIRequestBuilder
    private let sessionStore: any SessionStoring

    public init(
        client: HTTPClient,
        configuration: APIConfiguration,
        sessionStore: any SessionStoring,
        logger: AppLogger
    ) {
        self.client = client
        self.requestBuilder = APIRequestBuilder(configuration: configuration)
        self.sessionStore = sessionStore
        self.logger = logger
    }

    public func currentState() async -> AuthenticationState {
        do {
            guard let session = try await resolvedSession() else {
                return .signedOut
            }

            return .signedIn(session.userProfile)
        } catch {
            try? await sessionStore.clearSession()
            logger.error("Failed to restore remote session: \(error.localizedDescription)")
            return .signedOut
        }
    }

    public func signInWithEmail(email: String, password: String) async throws -> AuthenticationState {
        let endpoint = try makeJSONEndpoint(
            path: "v1/auth/sessions",
            method: .post,
            body: SignInPayload(displayName: email),
            requiresAuthorization: false
        )
        let request = try requestBuilder.build(endpoint: endpoint)
        let response = try await client.send(request)
        let session = try decodeSession(from: response.body)
        try await sessionStore.saveSession(session)
        logger.info("Remote email sign-in succeeded for \(session.userProfile.displayName)")
        return .signedIn(session.userProfile)
    }

    public func registerWithEmail(email: String, password: String, displayName: String) async throws -> AuthenticationState {
        let resolvedName = sanitizedDisplayName(displayName)
        let endpoint = try makeJSONEndpoint(
            path: "v1/auth/register",
            method: .post,
            body: SignInPayload(displayName: resolvedName),
            requiresAuthorization: false
        )
        let request = try requestBuilder.build(endpoint: endpoint)
        let response = try await client.send(request)
        let session = try decodeSession(from: response.body)
        try await sessionStore.saveSession(session)
        logger.info("Remote registration succeeded for \(session.userProfile.displayName)")
        return .signedIn(session.userProfile)
    }

    public func signInWithGoogle() async throws -> AuthenticationState {
        // Google Sign-In is handled via Firebase on the client; remote service is not used for this flow.
        throw AuthServiceError.unknown("Google sign-in is not supported by RemoteAuthenticationService.")
    }

    public func sendPasswordReset(email: String) async throws {
        // Remote backend: not implemented. Firebase handles this directly.
        throw AuthServiceError.unknown("Password reset is not supported by RemoteAuthenticationService.")
    }

    public func verifyPhoneNumber(_ phoneNumber: String) async throws -> String {
        throw AuthServiceError.unknown("Phone verification is not supported by RemoteAuthenticationService.")
    }

    public func signInWithPhone(verificationID: String, otp: String) async throws -> AuthenticationState {
        throw AuthServiceError.unknown("Phone sign-in is not supported by RemoteAuthenticationService.")
    }

    public func signOut() async {
        do {
            try await sessionStore.clearSession()
            logger.info("Remote session cleared")
        } catch {
            logger.error("Failed to clear remote session: \(error.localizedDescription)")
        }
    }
}

private extension RemoteAuthenticationService {
    func decodeSession(from data: Data) throws -> AuthSession {
        let sessionResponse = try JSONCoder.decoder().decode(SessionResponse.self, from: data)
        return AuthSession(
            accessToken: sessionResponse.accessToken,
            expiresAt: sessionResponse.expiresAt,
            refreshToken: sessionResponse.refreshToken,
            userProfile: UserProfile(
                id: sessionResponse.user.id,
                analyticsConsent: sessionResponse.user.analyticsConsent,
                dailyCalorieGoal: CalorieGoal(activeEnergyGoal: sessionResponse.user.dailyCalorieGoal),
                displayName: sessionResponse.user.displayName
            )
        )
    }

    func makeJSONEndpoint<Body: Encodable>(
        path: String,
        method: HTTPMethod,
        body: Body,
        requiresAuthorization: Bool
    ) throws -> APIEndpoint {
        APIEndpoint(
            path: path,
            method: method,
            headers: ["Content-Type": "application/json"],
            body: try JSONCoder.encoder().encode(body),
            requiresAuthorization: requiresAuthorization
        )
    }

    func refreshSession(using session: AuthSession) async throws -> AuthSession {
        let endpoint = try makeJSONEndpoint(
            path: "v1/auth/refresh",
            method: .post,
            body: RefreshPayload(refreshToken: session.refreshToken),
            requiresAuthorization: false
        )
        let request = try requestBuilder.build(endpoint: endpoint)
        let response = try await client.send(request)
        let refreshedSession = try decodeSession(from: response.body)
        try await sessionStore.saveSession(refreshedSession)
        logger.info("Remote session refreshed")
        return refreshedSession
    }

    func resolvedSession() async throws -> AuthSession? {
        guard let session = try await sessionStore.loadSession() else {
            return nil
        }

        if session.isExpired {
            return try await refreshSession(using: session)
        }

        if session.requiresRefresh {
            return try await refreshSession(using: session)
        }

        return session
    }

    func sanitizedDisplayName(_ displayName: String?) -> String {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Athlete" : trimmed
    }
}
