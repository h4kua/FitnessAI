#if canImport(Core)
import Core
#endif
#if canImport(Infrastructure)
import Infrastructure
#endif

public actor LiveAnalyticsService: AnalyticsTracking {
    private let settingsStore: any SettingsStoring
    private let logger: AppLogger

    public init(
        settingsStore: any SettingsStoring,
        logger: AppLogger
    ) {
        self.settingsStore = settingsStore
        self.logger = logger
    }

    public func track(event: AnalyticsEvent) async {
        let settings = await settingsStore.load()
        guard settings.analyticsEnabled else {
            return
        }

        logger.info("Tracked event \(event.name)")
    }
}
