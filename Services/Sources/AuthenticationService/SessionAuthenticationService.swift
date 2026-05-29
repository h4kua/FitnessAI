#if canImport(Core)
import Core
#endif
import Foundation

/// In-memory auth service used on the iOS Simulator for quick iteration.
/// Every sign-in/register call succeeds immediately without a network round-trip.
public actor SessionAuthenticationService: AuthenticationProviding {
    private var authenticationState: AuthenticationState = .signedOut
    private let logger: AppLogger

    public init(logger: AppLogger) {
        self.logger = logger
    }

    public func currentState() async -> AuthenticationState { authenticationState }

    public func signInWithEmail(email: String, password: String) async throws -> AuthenticationState {
        let user = makeProfile(displayName: nameFromEmail(email))
        authenticationState = .signedIn(user)
        logger.info("Simulator: email sign-in as \(email)")
        return authenticationState
    }

    public func registerWithEmail(email: String, password: String, displayName: String) async throws -> AuthenticationState {
        let name = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? nameFromEmail(email) : displayName
        let user = makeProfile(displayName: name)
        authenticationState = .signedIn(user)
        logger.info("Simulator: registered \(email) as \(name)")
        return authenticationState
    }

    public func signInWithGoogle() async throws -> AuthenticationState {
        let user = makeProfile(displayName: "Google User")
        authenticationState = .signedIn(user)
        logger.info("Simulator: Google sign-in (mocked)")
        return authenticationState
    }

    public func sendPasswordReset(email: String) async throws {
        // No-op on Simulator — just log so it's visible in console
        logger.info("Simulator: password reset email sent to \(email) (no-op)")
    }

    public func verifyPhoneNumber(_ phoneNumber: String) async throws -> String {
        logger.info("Simulator: phone verification for \(phoneNumber)")
        return "simulator-verification-id"
    }

    public func signInWithPhone(verificationID: String, otp: String) async throws -> AuthenticationState {
        // Accept any OTP on Simulator; reject "000000" to let developers test the error path
        if otp == "000000" {
            throw AuthServiceError.invalidOTP
        }
        let user = makeProfile(displayName: "Phone User")
        authenticationState = .signedIn(user)
        logger.info("Simulator: phone sign-in (mocked)")
        return authenticationState
    }

    public func signOut() async {
        authenticationState = .signedOut
        logger.info("Simulator: sign-out")
    }

    // MARK: - Private

    private func makeProfile(displayName: String) -> UserProfile {
        UserProfile(
            analyticsConsent: true,
            dailyCalorieGoal: CalorieGoal(activeEnergyGoal: 600),
            displayName: displayName
        )
    }

    private func nameFromEmail(_ email: String) -> String {
        email.components(separatedBy: "@").first ?? "Athlete"
    }
}
