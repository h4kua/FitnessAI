import Combine
#if canImport(Core)
import Core
#endif
import Foundation

@MainActor
public final class AuthenticationViewModel: ObservableObject {

    // MARK: - Auth mode

    public enum AuthMode: Equatable {
        case signIn
        case register
        case forgotPassword
        case phoneNumber
        case phoneOTP(verificationID: String)
    }

    @Published public var authMode: AuthMode = .signIn

    // MARK: - Form fields

    @Published public var email = ""
    @Published public var password = ""
    @Published public var confirmPassword = ""
    @Published public var displayName = ""
    @Published public var resetEmail = ""
    @Published public var phoneNumber = ""
    @Published public var otp = ""

    // MARK: - State

    @Published public private(set) var authenticationState: AuthenticationState = .signedOut
    @Published public private(set) var loadState: LoadState = .idle
    @Published public private(set) var errorMessage: String?
    /// Non-nil when a password-reset email is successfully dispatched.
    @Published public private(set) var forgotPasswordSuccess: String?
    /// True when the error is specifically "email already in use" — drives the "Sign In Instead" action.
    @Published public private(set) var isEmailAlreadyInUse: Bool = false

    public var onStateChange: (() -> Void)?

    // MARK: - Password validation

    public struct PasswordRule {
        public let label: String
        public let isMet: Bool
    }

    public var passwordRules: [PasswordRule] {
        [
            PasswordRule(label: "At least 8 characters",      isMet: password.count >= 8),
            PasswordRule(label: "One uppercase letter (A-Z)", isMet: password.contains { $0.isUppercase }),
            PasswordRule(label: "One lowercase letter (a-z)", isMet: password.contains { $0.isLowercase }),
            PasswordRule(label: "One number (0-9)",           isMet: password.contains { $0.isNumber }),
        ]
    }

    public var isPasswordValid: Bool { passwordRules.allSatisfy(\.isMet) }

    public var isRegisterFormValid: Bool {
        !email.isEmpty &&
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        isPasswordValid &&
        password == confirmPassword
    }

    public var isSignInFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    public var isForgotPasswordFormValid: Bool {
        !resetEmail.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var isPhoneFormValid: Bool {
        phoneNumber.trimmingCharacters(in: .whitespaces).count >= 8
    }

    public var isOTPFormValid: Bool {
        otp.count == 6
    }

    // MARK: - Init

    private let authenticationProvider: any AuthenticationProviding

    public init(authenticationProvider: any AuthenticationProviding) {
        self.authenticationProvider = authenticationProvider
    }

    // MARK: - Load (restore session on launch)

    public func load() async {
        authenticationState = await restoredState()
        onStateChange?()
    }

    public func clearError() {
        errorMessage = nil
        isEmailAlreadyInUse = false
        forgotPasswordSuccess = nil
    }

    // MARK: - Email / Password

    public func signInWithEmail() async {
        guard loadState != .loading else { return }
        clearError()
        loadState = .loading
        do {
            authenticationState = try await authenticationProvider.signInWithEmail(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
            loadState = .loaded
            onStateChange?()
        } catch {
            loadState = .idle
            handleAuthError(error)
        }
    }

    public func registerWithEmail() async {
        guard loadState != .loading else { return }
        clearError()
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match."
            return
        }
        loadState = .loading
        do {
            authenticationState = try await authenticationProvider.registerWithEmail(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespaces)
            )
            loadState = .loaded
            onStateChange?()
        } catch {
            loadState = .idle
            handleAuthError(error)
        }
    }

    // MARK: - Password Reset

    public func sendPasswordReset() async {
        guard loadState != .loading else { return }
        clearError()
        loadState = .loading
        do {
            try await authenticationProvider.sendPasswordReset(
                email: resetEmail.trimmingCharacters(in: .whitespaces)
            )
            loadState = .idle
            forgotPasswordSuccess = "Reset link sent! Check \(resetEmail.trimmingCharacters(in: .whitespaces)) — it may take a minute."
        } catch {
            loadState = .idle
            handleAuthError(error)
        }
    }

    // MARK: - Phone Number Auth

    public func verifyPhoneNumber() async {
        guard loadState != .loading else { return }
        clearError()
        loadState = .loading
        do {
            let verificationID = try await authenticationProvider.verifyPhoneNumber(
                phoneNumber.trimmingCharacters(in: .whitespaces)
            )
            loadState = .idle
            authMode = .phoneOTP(verificationID: verificationID)
        } catch {
            loadState = .idle
            handleAuthError(error)
        }
    }

    public func signInWithPhone(verificationID: String) async {
        guard loadState != .loading else { return }
        clearError()
        loadState = .loading
        do {
            authenticationState = try await authenticationProvider.signInWithPhone(
                verificationID: verificationID,
                otp: otp.trimmingCharacters(in: .whitespaces)
            )
            loadState = .loaded
            onStateChange?()
        } catch {
            loadState = .idle
            handleAuthError(error)
        }
    }

    // MARK: - Google Sign-In

    public func signInWithGoogle() async {
        guard loadState != .loading else { return }
        clearError()
        loadState = .loading
        do {
            authenticationState = try await authenticationProvider.signInWithGoogle()
            loadState = .loaded
            onStateChange?()
        } catch {
            loadState = .idle
            if let svcErr = error as? AuthServiceError, svcErr == .googleSignInCancelled { return }
            handleAuthError(error)
        }
    }

    // MARK: - Sign Out

    public func signOut() async {
        await authenticationProvider.signOut()
        authenticationState = .signedOut
        loadState = .idle
        clearError()
        authMode = .signIn
        email = ""
        password = ""
        onStateChange?()
    }

    // MARK: - Guest / Skip

    /// Lets the user enter the app without an account.
    /// All data stays local-only; Firestore writes are skipped automatically
    /// because there is no authenticated Firebase user.
    public func continueAsGuest() {
        let guest = UserProfile(
            analyticsConsent: false,
            dailyCalorieGoal: CalorieGoal(activeEnergyGoal: 500),
            displayName: "Guest"
        )
        authenticationState = .signedIn(guest)
        onStateChange?()
    }

    // MARK: - Navigation helpers

    public func switchToSignIn() {
        authMode = .signIn
        clearError()
    }

    public func switchToForgotPassword() {
        resetEmail = email          // pre-fill with whatever email was typed
        authMode = .forgotPassword
        clearError()
    }

    public func goBack() {
        switch authMode {
        case .forgotPassword, .phoneNumber:
            authMode = .signIn
        case .phoneOTP:
            authMode = .phoneNumber
            otp = ""
        default:
            break
        }
        clearError()
    }

    // MARK: - Private

    private func handleAuthError(_ error: Error) {
        if let svcErr = error as? AuthServiceError {
            isEmailAlreadyInUse = (svcErr == .emailAlreadyInUse)
        }
        errorMessage = error.localizedDescription
    }

    private func restoredState() async -> AuthenticationState {
        await withTaskGroup(of: AuthenticationState?.self) { group in
            group.addTask { await self.authenticationProvider.currentState() }
            group.addTask {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                return nil
            }
            let result = await group.next() ?? .signedOut
            group.cancelAll()
            return result ?? .signedOut
        }
    }
}

extension AuthServiceError: Equatable {
    public static func == (lhs: AuthServiceError, rhs: AuthServiceError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
