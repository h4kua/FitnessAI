public enum AuthenticationState: Sendable, Equatable {
    case signedOut
    case signedIn(UserProfile)
}
