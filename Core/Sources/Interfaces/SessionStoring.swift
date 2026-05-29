public protocol SessionStoring: Sendable {
    func loadSession() async throws -> AuthSession?
    func saveSession(_ session: AuthSession) async throws
    func clearSession() async throws
}
