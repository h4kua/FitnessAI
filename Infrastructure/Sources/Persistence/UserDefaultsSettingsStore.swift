#if canImport(Core)
import Core
#endif
import Foundation

public actor UserDefaultsSettingsStore: SettingsStoring {
    private enum Key {
        static let analyticsEnabled = "settings.analyticsEnabled"
        static let coachingHintsEnabled = "settings.coachingHintsEnabled"
        static let dailyCalorieGoal = "settings.dailyCalorieGoal"
    }

    private let logger: AppLogger
    private let userDefaults = UserDefaults.standard

    public init(logger: AppLogger) {
        self.logger = logger
    }

    public func load() async -> AppSettings {
        let defaults = AppSettings.default
        let analyticsEnabled = userDefaults.object(forKey: Key.analyticsEnabled) as? Bool ?? defaults.analyticsEnabled
        let coachingHintsEnabled = userDefaults.object(forKey: Key.coachingHintsEnabled) as? Bool ?? defaults.coachingHintsEnabled
        let calorieGoalKcal = userDefaults.object(forKey: Key.dailyCalorieGoal) as? Double ?? defaults.dailyCalorieGoal.activeEnergyGoal

        return AppSettings(
            analyticsEnabled: analyticsEnabled,
            coachingHintsEnabled: coachingHintsEnabled,
            dailyCalorieGoal: CalorieGoal(activeEnergyGoal: calorieGoalKcal)
        )
    }

    public func save(_ settings: AppSettings) async {
        userDefaults.set(settings.analyticsEnabled, forKey: Key.analyticsEnabled)
        userDefaults.set(settings.coachingHintsEnabled, forKey: Key.coachingHintsEnabled)
        userDefaults.set(settings.dailyCalorieGoal.activeEnergyGoal, forKey: Key.dailyCalorieGoal)
        logger.info("Persisted settings")
    }
}
