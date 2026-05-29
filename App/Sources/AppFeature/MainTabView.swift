#if canImport(AICoachChatFeature)
import AICoachChatFeature
#endif
#if canImport(AuthenticationFeature)
import AuthenticationFeature
#endif
#if canImport(AnalyticsFeature)
import AnalyticsFeature
#endif
#if canImport(CalorieTrackingFeature)
import CalorieTrackingFeature
#endif
#if canImport(DashboardFeature)
import DashboardFeature
#endif
#if canImport(ExerciseCameraAnalysisFeature)
import ExerciseCameraAnalysisFeature
#endif
#if canImport(DesignSystem)
import DesignSystem
#endif
#if canImport(SettingsFeature)
import SettingsFeature
#endif
import SwiftUI
#if canImport(WorkoutRecommendationsFeature)
import WorkoutRecommendationsFeature
#endif

public struct MainTabView: View {
    let dashboardViewModel: DashboardViewModel
    let calorieTrackingViewModel: CalorieTrackingViewModel
    let workoutRecommendationsViewModel: WorkoutRecommendationsViewModel
    let exerciseCameraAnalysisViewModel: ExerciseCameraAnalysisViewModel
    let coachChatViewModel: CoachChatViewModel
    let settingsViewModel: SettingsViewModel
    let analyticsViewModel: AnalyticsViewModel

    public init(
        dashboardViewModel: DashboardViewModel,
        calorieTrackingViewModel: CalorieTrackingViewModel,
        workoutRecommendationsViewModel: WorkoutRecommendationsViewModel,
        exerciseCameraAnalysisViewModel: ExerciseCameraAnalysisViewModel,
        coachChatViewModel: CoachChatViewModel,
        settingsViewModel: SettingsViewModel,
        analyticsViewModel: AnalyticsViewModel
    ) {
        self.dashboardViewModel = dashboardViewModel
        self.calorieTrackingViewModel = calorieTrackingViewModel
        self.workoutRecommendationsViewModel = workoutRecommendationsViewModel
        self.exerciseCameraAnalysisViewModel = exerciseCameraAnalysisViewModel
        self.coachChatViewModel = coachChatViewModel
        self.settingsViewModel = settingsViewModel
        self.analyticsViewModel = analyticsViewModel
    }

    @AppStorage("onboarding.didComplete") private var onboardingDidComplete = false

    // In simulator with --AutoSignIn, open directly on the Coach tab for easy testing.
    @State private var selectedTab: Int = {
        #if targetEnvironment(simulator)
        return CommandLine.arguments.contains("--AutoSignIn") ? 4 : 0
        #else
        return 0
        #endif
    }()

    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: dashboardViewModel)
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            CalorieTrackingView(viewModel: calorieTrackingViewModel)
                .tabItem {
                    Label("Nutrition", systemImage: selectedTab == 1 ? "fork.knife.circle.fill" : "fork.knife")
                }
                .tag(1)

            WorkoutRecommendationsView(viewModel: workoutRecommendationsViewModel)
                .tabItem {
                    Label("Train", systemImage: selectedTab == 2 ? "figure.run.circle.fill" : "figure.run")
                }
                .tag(2)

            ExerciseCameraAnalysisView(viewModel: exerciseCameraAnalysisViewModel)
                .tabItem {
                    Label("Form", systemImage: "camera.viewfinder")
                }
                .tag(3)

            CoachChatView(viewModel: coachChatViewModel)
                .tabItem {
                    Label("Coach", systemImage: selectedTab == 4 ? "brain.head.profile" : "brain")
                }
                .tag(4)

            SettingsView(viewModel: settingsViewModel)
                .tabItem {
                    Label("Profile", systemImage: selectedTab == 5 ? "person.circle.fill" : "person.circle")
                }
                .tag(5)

            AnalyticsView(viewModel: analyticsViewModel)
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield.fill")
                }
                .tag(6)
        }
        .tint(FitnessTheme.accent)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingDidComplete },
            set: { _ in }
        )) {
            OnboardingView()
        }
    }
}
