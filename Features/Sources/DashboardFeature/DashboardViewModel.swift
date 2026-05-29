import Combine
#if canImport(Core)
import Core
#endif
import Foundation

@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public private(set) var calorieSummary: CalorieSummary?
    @Published public private(set) var healthAuthorizationStatus: HealthAuthorizationStatus = .notDetermined
    @Published public private(set) var healthStatusMessage: String?
    @Published public private(set) var loadState: LoadState = .idle
    @Published public private(set) var workoutPlan: WorkoutPlan?
    /// True when the active-energy goal for today has been reached.
    /// Sticks for the rest of the day and resets automatically at midnight.
    @Published public private(set) var isGoalCompletedToday: Bool = false

    private let analyticsTracker: any AnalyticsTracking
    private let healthDataProvider: any HealthDataProviding
    private let profile: UserProfile
    private let recommendationProvider: any WorkoutRecommendationProviding
    private var currentCalorieGoal: CalorieGoal

    private static let completedDateKey = "goal.completedDate"
    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    public init(
        profile: UserProfile,
        healthDataProvider: any HealthDataProviding,
        recommendationProvider: any WorkoutRecommendationProviding,
        analyticsTracker: any AnalyticsTracking
    ) {
        self.profile = profile
        self.currentCalorieGoal = profile.dailyCalorieGoal
        self.healthDataProvider = healthDataProvider
        self.recommendationProvider = recommendationProvider
        self.analyticsTracker = analyticsTracker
        // Restore the persisted completion flag on init
        restoreGoalCompletion()
    }

    public func updateCalorieGoal(_ goal: CalorieGoal) {
        currentCalorieGoal = goal
        if loadState == .loaded {
            loadState = .idle
        }
    }

    public func requestHealthAccess() async {
        do {
            let status = try await healthDataProvider.requestAuthorization()
            healthAuthorizationStatus = status
            if status == .authorized {
                loadState = .loading
                try await fetchAuthorizedData()
            } else {
                healthStatusMessage = "Apple Health access is turned off. Go to Settings > Privacy & Security > Health to allow access."
            }
        } catch {
            healthAuthorizationStatus = await healthDataProvider.authorizationStatus()
            if loadState == .loading {
                loadState = .failed(error.localizedDescription)
            }
        }
    }

    public func load() async {
        guard loadState != .loading else { return }

        loadState = .loading
        healthStatusMessage = nil
        restoreGoalCompletion()     // refresh in case the day rolled over

        do {
            let authStatus = await healthDataProvider.authorizationStatus()
            healthAuthorizationStatus = authStatus

            switch authStatus {
            case .denied:
                healthStatusMessage = "Apple Health access is turned off. Go to Settings > Privacy & Security > Health to allow access."
                calorieSummary = nil
                workoutPlan = nil
                loadState = .loaded
            case .unavailable:
                healthStatusMessage = "Apple Health isn't connected in this build. Live active energy won't be shown."
                calorieSummary = nil
                workoutPlan = nil
                loadState = .loaded
            case .notDetermined:
                calorieSummary = nil
                workoutPlan = nil
                loadState = .loaded
            case .authorized:
                try await fetchAuthorizedData()
            }
        } catch {
            loadState = .failed(error.localizedDescription)

            await analyticsTracker.track(
                event: AnalyticsEvent(
                    name: "dashboard_load_failed",
                    metadata: ["reason": error.localizedDescription]
                )
            )
        }
    }

    private func fetchAuthorizedData() async throws {
        let summary = try await healthDataProvider.calorieSummary(for: Date(), goal: currentCalorieGoal)

        let input = RecommendationInput(
            targetCalories: currentCalorieGoal.activeEnergyGoal,
            activeEnergyBurned: summary.activeEnergyBurned,
            availableMinutes: 30,
            preferredIntensity: .moderate
        )
        let plan = try await recommendationProvider.recommend(for: input)

        calorieSummary = summary
        workoutPlan = plan
        loadState = .loaded

        // Persist goal completion once the ratio crosses 100%
        markGoalCompletedIfNeeded(ratio: summary.completionRatio)

        await analyticsTracker.track(
            event: AnalyticsEvent(
                name: "dashboard_loaded",
                metadata: ["plan_title": plan.title]
            )
        )
    }

    // MARK: - Goal Completion Persistence

    private func markGoalCompletedIfNeeded(ratio: Double) {
        guard ratio >= 1.0, !isGoalCompletedToday else { return }
        let todayStr = Self.dayFormatter.string(from: Date())
        UserDefaults.standard.set(todayStr, forKey: Self.completedDateKey)
        isGoalCompletedToday = true
    }

    /// Checks whether the persisted completion date matches today.
    /// Called on init and at the top of every `load()` so the flag auto-resets at midnight.
    private func restoreGoalCompletion() {
        let todayStr = Self.dayFormatter.string(from: Date())
        let stored = UserDefaults.standard.string(forKey: Self.completedDateKey) ?? ""
        isGoalCompletedToday = (stored == todayStr)
    }
}
