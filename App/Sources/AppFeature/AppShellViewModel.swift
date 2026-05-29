#if canImport(AICoachChatFeature)
import AICoachChatFeature
#endif
#if canImport(AnalyticsFeature)
import AnalyticsFeature
#endif
#if canImport(AuthenticationFeature)
import AuthenticationFeature
#endif
#if canImport(CalorieTrackingFeature)
import CalorieTrackingFeature
#endif
import Combine
#if canImport(Core)
import Core
#endif
#if canImport(DashboardFeature)
import DashboardFeature
#endif
#if canImport(ExerciseCameraAnalysisFeature)
import ExerciseCameraAnalysisFeature
#endif
import Foundation
#if canImport(SettingsFeature)
import SettingsFeature
#endif
#if canImport(WorkoutRecommendationsFeature)
import WorkoutRecommendationsFeature
#endif

@MainActor
public final class AppShellViewModel: ObservableObject {
    public let analyticsViewModel: AnalyticsViewModel
    public let authenticationViewModel: AuthenticationViewModel
    public let settingsViewModel: SettingsViewModel

    @Published public private(set) var authenticationState: AuthenticationState = .signedOut
    @Published public private(set) var isBootstrapping = true
    @Published public private(set) var calorieTrackingViewModel: CalorieTrackingViewModel?
    @Published public private(set) var coachChatViewModel: CoachChatViewModel?
    @Published public private(set) var dashboardViewModel: DashboardViewModel?
    @Published public private(set) var exerciseCameraAnalysisViewModel: ExerciseCameraAnalysisViewModel?
    @Published public private(set) var workoutRecommendationsViewModel: WorkoutRecommendationsViewModel?

    private let dependencies: AppDependencies
    private var activeUserID: UUID?
    private var cancellables = Set<AnyCancellable>()
    private var hasLoaded = false

    public init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        analyticsViewModel = AnalyticsViewModel(settingsStore: dependencies.settingsStore)
        authenticationViewModel = AuthenticationViewModel(authenticationProvider: dependencies.authenticationProvider)
        settingsViewModel = SettingsViewModel(settingsStore: dependencies.settingsStore)

        authenticationViewModel.onStateChange = { [weak self] in
            self?.configureAuthenticatedExperience()
        }

        settingsViewModel.onSignOutRequested = { [weak self] in
            Task { await self?.authenticationViewModel.signOut() }
        }

        settingsViewModel.$calorieGoal
            .dropFirst()
            .sink { [weak self] kcal in
                guard let self else { return }
                let goal = CalorieGoal(activeEnergyGoal: kcal)
                self.dashboardViewModel?.updateCalorieGoal(goal)
                self.calorieTrackingViewModel?.updateGoal(goal)
            }
            .store(in: &cancellables)
    }

    public func load() async {
        guard hasLoaded == false else {
            return
        }

        hasLoaded = true
        defer { isBootstrapping = false }
        await analyticsViewModel.load()
        await settingsViewModel.load()
        await authenticationViewModel.load()
        configureAuthenticatedExperience()
    }

    private func configureAuthenticatedExperience() {
        authenticationState = authenticationViewModel.authenticationState

        switch authenticationState {
        case .signedOut:
            activeUserID = nil
            coachChatViewModel = nil
            dashboardViewModel = nil
            calorieTrackingViewModel = nil
            workoutRecommendationsViewModel = nil
            exerciseCameraAnalysisViewModel = nil
        case .signedIn(let user):
            guard activeUserID != user.id else {
                return
            }

            activeUserID = user.id
            let effectiveGoal = CalorieGoal(activeEnergyGoal: settingsViewModel.calorieGoal)
            let effectiveProfile = UserProfile(
                id: user.id,
                analyticsConsent: user.analyticsConsent,
                dailyCalorieGoal: effectiveGoal,
                displayName: user.displayName
            )

            dashboardViewModel = DashboardViewModel(
                profile: effectiveProfile,
                healthDataProvider: dependencies.healthDataProvider,
                recommendationProvider: dependencies.workoutRecommendationProvider,
                analyticsTracker: dependencies.analyticsTracker
            )
            calorieTrackingViewModel = CalorieTrackingViewModel(
                goal: effectiveGoal,
                healthDataProvider: dependencies.healthDataProvider
            )
            workoutRecommendationsViewModel = WorkoutRecommendationsViewModel(
                profile: effectiveProfile,
                healthDataProvider: dependencies.healthDataProvider,
                recommendationProvider: dependencies.workoutRecommendationProvider,
                sessionStore: dependencies.workoutSessionStore
            )
            exerciseCameraAnalysisViewModel = ExerciseCameraAnalysisViewModel(
                exerciseAnalysisProvider: dependencies.exerciseAnalysisProvider,
                workoutSessionStore: dependencies.workoutSessionStore
            )
            coachChatViewModel = CoachChatViewModel(
                groqService: dependencies.groqCoachingService,
                userProfile: effectiveProfile,
                calorieGoal: effectiveGoal.activeEnergyGoal
            )
        }
    }
}
