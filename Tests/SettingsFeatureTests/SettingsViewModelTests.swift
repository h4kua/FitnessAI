import Core
import SettingsFeature
import TestSupport
import XCTest

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testLoadHydratesSettingsFromStore() async {
        let viewModel = SettingsViewModel(
            settingsStore: MockSettingsStore(
                loadedSettings: AppSettings(
                    analyticsEnabled: false,
                    coachingHintsEnabled: true
                )
            )
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertFalse(viewModel.analyticsEnabled)
        XCTAssertTrue(viewModel.coachingHintsEnabled)
    }

    func testUpdatingAnalyticsPersistsNewValue() async {
        let settingsStore = MockSettingsStore(loadedSettings: .default)
        let viewModel = SettingsViewModel(settingsStore: settingsStore)

        await viewModel.load()
        await viewModel.updateAnalytics(enabled: false)

        let savedSettings = await settingsStore.savedSettings
        XCTAssertEqual(savedSettings.last?.analyticsEnabled, false)
        XCTAssertEqual(savedSettings.last?.coachingHintsEnabled, true)
    }

    func testUpdatingCalorieGoalPersistsNewValue() async {
        let settingsStore = MockSettingsStore(loadedSettings: .default)
        let viewModel = SettingsViewModel(settingsStore: settingsStore)

        await viewModel.load()
        await viewModel.updateCalorieGoal(750)

        XCTAssertEqual(viewModel.calorieGoal, 750)
        let savedSettings = await settingsStore.savedSettings
        XCTAssertEqual(savedSettings.last?.dailyCalorieGoal.activeEnergyGoal, 750)
    }

    func testLoadHydratesCalorieGoalFromStore() async {
        let viewModel = SettingsViewModel(
            settingsStore: MockSettingsStore(
                loadedSettings: AppSettings(
                    analyticsEnabled: true,
                    coachingHintsEnabled: true,
                    dailyCalorieGoal: CalorieGoal(activeEnergyGoal: 850)
                )
            )
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.calorieGoal, 850)
    }
}
