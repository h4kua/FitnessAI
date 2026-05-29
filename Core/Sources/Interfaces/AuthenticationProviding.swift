import Foundation

public protocol AuthenticationProviding: Sendable {
    func currentState() async -> AuthenticationState
    /// Sign in with email + password. Throws on failure (bad credentials, network, etc.)
    func signInWithEmail(email: String, password: String) async throws -> AuthenticationState
    /// Register a new account with email + password + display name.
    /// Throws AuthServiceError.emailAlreadyInUse if the account exists.
    func registerWithEmail(email: String, password: String, displayName: String) async throws -> AuthenticationState
    /// Google Sign-In. Must be called from the main thread.
    func signInWithGoogle() async throws -> AuthenticationState
    /// Send a password-reset email. Throws if the email is not registered or network fails.
    func sendPasswordReset(email: String) async throws
    /// Start phone OTP flow. Returns a verificationID to pass to signInWithPhone.
    /// Throws AuthServiceError.phoneVerificationFailed on failure.
    func verifyPhoneNumber(_ phoneNumber: String) async throws -> String
    /// Complete phone OTP sign-in. Throws AuthServiceError.invalidOTP for wrong codes.
    func signInWithPhone(verificationID: String, otp: String) async throws -> AuthenticationState
    func signOut() async
}

/// Typed errors surfaced to the UI layer.
public enum AuthServiceError: LocalizedError, Sendable {
    case emailAlreadyInUse
    case wrongPassword
    case userNotFound
    case weakPassword
    case networkError
    case googleSignInCancelled
    case tooManyRequests
    case phoneVerificationFailed
    case invalidOTP
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .emailAlreadyInUse:
            return "This email is already registered. Try signing in or reset your password."
        case .wrongPassword:
            return "Incorrect password. Please try again or reset your password."
        case .userNotFound:
            return "No account found for this email. Try registering."
        case .weakPassword:
            return "Password must be at least 8 characters with uppercase, lowercase and a number."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .googleSignInCancelled:
            return "Google sign-in was cancelled."
        case .tooManyRequests:
            return "Too many failed attempts. Please wait a few minutes and try again."
        case .phoneVerificationFailed:
            return "Could not send verification code. Check the number and try again."
        case .invalidOTP:
            return "Invalid verification code. Please check the code and try again."
        case .unknown(let msg):
            return msg
        }
    }
}
