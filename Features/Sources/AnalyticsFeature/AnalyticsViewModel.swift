import Combine
#if canImport(Core)
import Core
#endif

@MainActor
public final class AnalyticsViewModel: ObservableObject {
    @Published public private(set) var analyticsEnabled = AppSettings.default.analyticsEnabled
    @Published public private(set) var loadState: LoadState = .idle

    private let settingsStore: any SettingsStoring

    public init(settingsStore: any SettingsStoring) {
        self.settingsStore = settingsStore
    }

    public func load() async {
        guard loadState != .loading else {
            return
        }

        loadState = .loading
        let settings = await settingsStore.load()
        analyticsEnabled = settings.analyticsEnabled
        loadState = .loaded
    }
}
