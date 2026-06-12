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
#if canImport(ExerciseTutorialFeature)
import ExerciseTutorialFeature
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
        return CommandLine.arguments.contains("--AutoSignIn") ? 3 : 0
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

            MyPlanView(
                workoutViewModel: workoutRecommendationsViewModel,
                nutritionViewModel: calorieTrackingViewModel
            )
            .tabItem {
                Label("Plan", systemImage: selectedTab == 1 ? "list.bullet.clipboard.fill" : "list.bullet.clipboard")
            }
            .tag(1)

            ExerciseCameraAnalysisView(viewModel: exerciseCameraAnalysisViewModel)
                .tabItem {
                    Label("Form", systemImage: "camera.viewfinder")
                }
                .tag(2)

            CoachChatView(viewModel: coachChatViewModel)
                .tabItem {
                    Label("Coach", systemImage: selectedTab == 3 ? "brain.head.profile" : "brain")
                }
                .tag(3)

            SettingsView(viewModel: settingsViewModel)
                .tabItem {
                    Label("Profile", systemImage: selectedTab == 4 ? "person.circle.fill" : "person.circle")
                }
                .tag(4)

            AnalyticsView(viewModel: analyticsViewModel)
                .tabItem {
                    Label("Privacy", systemImage: "lock.shield.fill")
                }
                .tag(5)

            ExerciseTutorialView()
                .tabItem {
                    Label("Tutorial", systemImage: selectedTab == 6 ? "play.circle.fill" : "play.circle")
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

// MARK: - Combined Training + Nutrition tab

private struct MyPlanView: View {
    let workoutViewModel: WorkoutRecommendationsViewModel
    let nutritionViewModel: CalorieTrackingViewModel
    @State private var selectedSection = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedSection) {
                Text("Training").tag(0)
                Text("Nutrition").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, FitnessSpacing.large)
            .padding(.top, FitnessSpacing.medium)
            .padding(.bottom, FitnessSpacing.small)
            .background(FitnessTheme.background)

            if selectedSection == 0 {
                WorkoutRecommendationsView(viewModel: workoutViewModel)
            } else {
                CalorieTrackingView(viewModel: nutritionViewModel)
            }
        }
        .background(FitnessTheme.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: selectedSection)
    }
}
