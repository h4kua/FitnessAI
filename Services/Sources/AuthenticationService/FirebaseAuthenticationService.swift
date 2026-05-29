#if canImport(Core)
import Core
#endif
import FirebaseAuth
import FirebaseFirestore
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import Foundation
import UIKit

public actor FirebaseAuthenticationService: AuthenticationProviding {
    private let logger: AppLogger
    private let db = Firestore.firestore()

    public init(logger: AppLogger) {
        self.logger = logger
    }

    // MARK: - Current State

    /// Called on app launch to restore session.
    /// Also (re-)writes the Firestore user document so existing users who signed in
    /// before Firestore rules were opened will get their document created.
    public func currentState() async -> AuthenticationState {
        guard let user = Auth.auth().currentUser else { return .signedOut }
        // Skip anonymous users — they have no meaningful profile to persist
        if !user.isAnonymous {
            await saveUserDocument(user, displayName: nil)
        }
        return .signedIn(profile(from: user))
    }

    // MARK: - Email / Password

    public func signInWithEmail(email: String, password: String) async throws -> AuthenticationState {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            logger.info("Email sign-in succeeded: \(result.user.uid)")
            await saveUserDocument(result.user, displayName: nil)
            return .signedIn(profile(from: result.user))
        } catch {
            throw mapped(error)
        }
    }

    public func registerWithEmail(email: String, password: String, displayName: String) async throws -> AuthenticationState {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
            let finalName = trimmedName.isEmpty ? "Athlete" : trimmedName
            let req = result.user.createProfileChangeRequest()
            req.displayName = finalName
            try await req.commitChanges()
            logger.info("Email registration succeeded: \(result.user.uid)")
            await saveUserDocument(result.user, displayName: finalName)
            return .signedIn(profile(from: result.user, displayName: finalName))
        } catch {
            throw mapped(error)
        }
    }

    // MARK: - Password Reset

    public func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email.trimmingCharacters(in: .whitespaces))
            logger.info("Password reset email sent to \(email)")
        } catch {
            throw mapped(error)
        }
    }

    // MARK: - Phone Number OTP
    // Prerequisites (set up once in Firebase Console + Xcode):
    //   1. Enable "Phone" sign-in provider in Firebase Console → Auth → Sign-in methods.
    //   2. Add your Apple Developer Team ID and upload an APNs Auth Key under Project Settings → Cloud Messaging.
    //   3. Register your bundle ID for APNs in Apple Developer portal.
    //   4. For testing on Simulator, add test phone numbers under Firebase Console → Auth → Sign-in methods → Phone → Test phone numbers.

    public func verifyPhoneNumber(_ phoneNumber: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            // Firebase silently handles APNs; reCAPTCHA fallback needs no extra setup.
            PhoneAuthProvider.provider()
                .verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
                    if let verificationID = verificationID {
                        continuation.resume(returning: verificationID)
                    } else {
                        continuation.resume(throwing: AuthServiceError.phoneVerificationFailed)
                    }
                }
        }
    }

    public func signInWithPhone(verificationID: String, otp: String) async throws -> AuthenticationState {
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: otp
        )
        do {
            let result = try await Auth.auth().signIn(with: credential)
            logger.info("Phone sign-in succeeded: \(result.user.uid)")
            await saveUserDocument(result.user, displayName: nil)
            return .signedIn(profile(from: result.user))
        } catch {
            let mapped = mapped(error)
            if case .unknown = mapped {
                // Firebase returns invalidVerificationCode for bad OTP
                let nsErr = error as NSError
                if nsErr.code == AuthErrorCode.invalidVerificationCode.rawValue
                    || nsErr.code == AuthErrorCode.invalidVerificationID.rawValue {
                    throw AuthServiceError.invalidOTP
                }
            }
            throw mapped
        }
    }

    // MARK: - Google Sign-In

    @MainActor
    public func signInWithGoogle() async throws -> AuthenticationState {
        #if canImport(GoogleSignIn)
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        else {
            throw AuthServiceError.unknown("Could not find root view controller.")
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthServiceError.unknown("Missing Google ID token.")
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            logger.info("Google sign-in succeeded: \(authResult.user.uid)")
            await saveUserDocument(authResult.user, displayName: authResult.user.displayName)
            return .signedIn(profile(from: authResult.user))
        } catch let error as GIDSignInError where error.code == .canceled {
            throw AuthServiceError.googleSignInCancelled
        } catch let e as AuthServiceError {
            throw e
        } catch {
            throw mapped(error)
        }
        #else
        throw AuthServiceError.unknown("Google Sign-In SDK not available.")
        #endif
    }

    // MARK: - Sign Out

    public func signOut() async {
        do {
            try Auth.auth().signOut()
            logger.info("Sign-out succeeded")
        } catch {
            logger.error("Sign-out failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Firestore User Document

    /// Creates or updates the user document in Firestore.
    /// Uses merge so existing fields (e.g. dailyCalorieGoal) are never overwritten on re-login.
    private func saveUserDocument(_ user: FirebaseAuth.User, displayName: String?) async {
        let name = displayName ?? user.displayName ?? "Athlete"
        let data: [String: Any] = [
            "uid":          user.uid,
            "email":        user.email ?? "",
            "displayName":  name,
            "photoURL":     user.photoURL?.absoluteString ?? "",
            "createdAt":    FieldValue.serverTimestamp(),
            "lastLoginAt":  FieldValue.serverTimestamp(),
            "provider":     user.providerData.first?.providerID ?? "unknown",
            "appVersion":   Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
        logger.info("[Firestore] Writing user doc for uid=\(user.uid) email=\(user.email ?? "none")")
        do {
            try await db.collection("users").document(user.uid)
                .setData(data, merge: true)
            logger.info("[Firestore] ✅ User document saved: users/\(user.uid)")
        } catch {
            logger.error("[Firestore] ❌ Write failed: \(error.localizedDescription) — check Security Rules in Firebase Console")
        }
    }

    // MARK: - Helpers

    nonisolated private func profile(from user: FirebaseAuth.User, displayName: String? = nil) -> UserProfile {
        UserProfile(
            id: UUID(uuidString: user.uid) ?? UUID(),
            analyticsConsent: false,
            dailyCalorieGoal: CalorieGoal(activeEnergyGoal: 500),
            displayName: displayName ?? user.displayName ?? "Athlete"
        )
    }

    nonisolated private func mapped(_ error: Error) -> AuthServiceError {
        let code = AuthErrorCode(_bridgedNSError: error as NSError)
        switch code?.code {
        case .emailAlreadyInUse:        return .emailAlreadyInUse
        case .wrongPassword:            return .wrongPassword
        case .invalidCredential:        return .wrongPassword   // Firebase SDK ≥ 10 combines wrong pw + user not found
        case .userNotFound:             return .userNotFound
        case .weakPassword:             return .weakPassword
        case .networkError:             return .networkError
        case .tooManyRequests:          return .tooManyRequests
        case .invalidVerificationCode,
             .invalidVerificationID:    return .invalidOTP
        default:                        return .unknown(error.localizedDescription)
        }
    }
}
