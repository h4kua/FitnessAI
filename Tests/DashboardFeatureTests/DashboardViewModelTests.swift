import Core
import DashboardFeature
import TestSupport
import XCTest

@MainActor
final class DashboardViewModelTests: XCTestCase {
    private let defaultProfile = UserProfile(
        analyticsConsent: true,
        dailyCalorieGoal: CalorieGoal(activeEnergyGoal: 600),
        displayName: "Taylor"
    )
    private let defaultSummary = CalorieSummary(
        date: Date(),
        activeEnergyBurned: 240,
        goal: CalorieGoal(activeEnergyGoal: 600)
    )

    func testLoadProducesSummaryAndPlan() async {
        let analyticsTracker = MockAnalyticsTracker()
        let viewModel = DashboardViewModel(
            profile: defaultProfile,
            healthDataProvider: MockHealthDataProvider(summary: defaultSummary),
            recommendationProvider: MockWorkoutRecommendationProvider(planToReturn: .stub),
            analyticsTracker: analyticsTracker
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.calorieSummary, defaultSummary)
        XCTAssertNotNil(viewModel.workoutPlan)
        XCTAssertEqual(viewModel.healthAuthorizationStatus, .authorized)
        let events = await analyticsTracker.events
        XCTAssertEqual(events.last?.name, "dashboard_loaded")
    }

    func testDeniedAuthorizationLoadsGracefullyWithMessage() async {
        let viewModel = DashboardViewModel(
            profile: defaultProfile,
            healthDataProvider: MockHealthDataProvider(
                status: .denied,
                summary: defaultSummary
            ),
            recommendationProvider: MockWorkoutRecommendationProvider(),
            analyticsTracker: MockAnalyticsTracker()
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertNil(viewModel.calorieSummary)
        XCTAssertNil(viewModel.workoutPlan)
        XCTAssertNotNil(viewModel.healthStatusMessage)
        XCTAssertEqual(viewModel.healthAuthorizationStatus, .denied)
    }

    func testNotDeterminedStatusShowsConnectCardWithoutFetchingData() async {
        let viewModel = DashboardViewModel(
            profile: defaultProfile,
            healthDataProvider: MockHealthDataProvider(
                status: .notDetermined,
                summary: defaultSummary
            ),
            recommendationProvider: MockWorkoutRecommendationProvider(),
            analyticsTracker: MockAnalyticsTracker()
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertNil(viewModel.calorieSummary)
        XCTAssertNil(viewModel.workoutPlan)
        XCTAssertEqual(viewModel.healthAuthorizationStatus, .notDetermined)
        XCTAssertNil(viewModel.healthStatusMessage)
    }

    func testRequestHealthAccessLoadsDataOnAuthorization() async {
        let summary = CalorieSummary(
            date: Date(),
            activeEnergyBurned: 300,
            goal: CalorieGoal(activeEnergyGoal: 600)
        )
        let viewModel = DashboardViewModel(
            profile: defaultProfile,
            healthDataProvider: MockHealthDataProvider(
                requestedAuthorizationStatus: .authorized,
                status: .notDetermined,
                summary: summary
            ),
            recommendationProvider: MockWorkoutRecommendationProvider(planToReturn: .stub),
            analyticsTracker: MockAnalyticsTracker()
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.healthAuthorizationStatus, .notDetermined)

        await viewModel.requestHealthAccess()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.calorieSummary, summary)
        XCTAssertNotNil(viewModel.workoutPlan)
        XCTAssertEqual(viewModel.healthAuthorizationStatus, .authorized)
    }

    func testRequestHealthAccessWithDeniedResponseRemainsInConnectState() async {
        let viewModel = DashboardViewModel(
            profile: defaultProfile,
            healthDataProvider: MockHealthDataProvider(
                requestedAuthorizationStatus: .denied,
                status: .notDetermined,
                summary: defaultSummary
            ),
            recommendationProvider: MockWorkoutRecommendationProvider(),
            analyticsTracker: MockAnalyticsTracker()
        )

        await viewModel.load()
        await viewModel.requestHealthAccess()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertNil(viewModel.calorieSummary)
        XCTAssertEqual(viewModel.healthAuthorizationStatus, .denied)
    }

    func testUnavailableHealthDataLoadsWithMessageAndNilSummary() async {
        let viewModel = DashboardViewModel(
            profile: defaultProfile,
            healthDataProvider: MockHealthDataProvider(
                status: .unavailable,
                summary: defaultSummary
            ),
            recommendationProvider: MockWorkoutRecommendationProvider(),
            analyticsTracker: MockAnalyticsTracker()
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertNil(viewModel.calorieSummary)
        XCTAssertNil(viewModel.workoutPlan)
        XCTAssertNotNil(viewModel.healthStatusMessage)
        XCTAssertEqual(viewModel.healthAuthorizationStatus, .unavailable)
    }

    func testUpdateCalorieGoalResetsLoadState() async {
        let viewModel = DashboardViewModel(
            profile: defaultProfile,
            healthDataProvider: MockHealthDataProvider(summary: defaultSummary),
            recommendationProvider: MockWorkoutRecommendationProvider(planToReturn: .stub),
            analyticsTracker: MockAnalyticsTracker()
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.loadState, .loaded)

        viewModel.updateCalorieGoal(CalorieGoal(activeEnergyGoal: 800))

        XCTAssertEqual(viewModel.loadState, .idle)
    }
}
