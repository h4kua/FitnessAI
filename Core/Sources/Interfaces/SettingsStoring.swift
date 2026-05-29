public protocol SettingsStoring: Sendable {
    func load() async -> AppSettings
    func save(_ settings: AppSettings) async
}
