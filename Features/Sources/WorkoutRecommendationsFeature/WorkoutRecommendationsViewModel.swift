import Combine
#if canImport(Core)
import Core
#endif
import Foundation

@MainActor
public final class WorkoutRecommendationsViewModel: ObservableObject {
    @Published public private(set) var healthStatusMessage: String?
    @Published public private(set) var loadState: LoadState = .idle
    @Published public private(set) var plan: WorkoutPlan?
    @Published public var availableMinutes: Int = 30
    @Published public var preferredIntensity: WorkoutIntensity = .moderate

    private let healthDataProvider: any HealthDataProviding
    private let profile: UserProfile
    private let recommendationProvider: any WorkoutRecommendationProviding
    private let sessionStore: any WorkoutSessionStoring

    public init(
        profile: UserProfile,
        healthDataProvider: any HealthDataProviding,
        recommendationProvider: any WorkoutRecommendationProviding,
        sessionStore: any WorkoutSessionStoring
    ) {
        self.profile = profile
        self.healthDataProvider = healthDataProvider
        self.recommendationProvider = recommendationProvider
        self.sessionStore = sessionStore
    }

    public func refresh() async {
        guard loadState != .loading else {
            return
        }

        loadState = .loading
        healthStatusMessage = nil

        let authStatus = await healthDataProvider.authorizationStatus()

        if authStatus == .denied || authStatus == .unavailable {
            healthStatusMessage = "Apple Health access was declined or is unavailable on this build, so recommendations that depend on live active energy can't be shown."
        }

        let activeEnergyBurned: Double
        do {
            let summary = try await healthDataProvider.calorieSummary(
                for: Date(),
                goal: profile.dailyCalorieGoal
            )
            activeEnergyBurned = summary.activeEnergyBurned
        } catch {
            activeEnergyBurned = 0
        }

        let recentSessions: [WorkoutSessionSummary]
        do {
            recentSessions = try await sessionStore.fetchRecent(limit: 7)
        } catch {
            recentSessions = []
        }

        let input = RecommendationInput(
            targetCalories: profile.dailyCalorieGoal.activeEnergyGoal,
            activeEnergyBurned: activeEnergyBurned,
            availableMinutes: availableMinutes,
            preferredIntensity: preferredIntensity,
            recentSessions: recentSessions
        )

        do {
            plan = try await recommendationProvider.recommend(for: input)
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }
}
