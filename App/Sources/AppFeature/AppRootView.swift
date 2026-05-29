#if canImport(AICoachChatFeature)
import AICoachChatFeature
#endif
#if canImport(AuthenticationFeature)
import AuthenticationFeature
#endif
#if canImport(Core)
import Core
#endif
#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

public struct AppRootView: View {
    @StateObject private var viewModel: AppShellViewModel

    public init(dependencies: AppDependencies = .live()) {
        _viewModel = StateObject(wrappedValue: AppShellViewModel(dependencies: dependencies))
    }

    public var body: some View {
        Group {
            if viewModel.isBootstrapping {
                bootstrappingView
            } else {
                switch viewModel.authenticationState {
                case .signedOut:
                    AuthenticationView(viewModel: viewModel.authenticationViewModel)
                case .signedIn:
                    if let dashboardViewModel = viewModel.dashboardViewModel,
                       let calorieTrackingViewModel = viewModel.calorieTrackingViewModel,
                       let workoutRecommendationsViewModel = viewModel.workoutRecommendationsViewModel,
                       let exerciseCameraAnalysisViewModel = viewModel.exerciseCameraAnalysisViewModel,
                       let coachChatViewModel = viewModel.coachChatViewModel {
                        MainTabView(
                            dashboardViewModel: dashboardViewModel,
                            calorieTrackingViewModel: calorieTrackingViewModel,
                            workoutRecommendationsViewModel: workoutRecommendationsViewModel,
                            exerciseCameraAnalysisViewModel: exerciseCameraAnalysisViewModel,
                            coachChatViewModel: coachChatViewModel,
                            settingsViewModel: viewModel.settingsViewModel,
                            analyticsViewModel: viewModel.analyticsViewModel
                        )
                    } else {
                        bootstrappingView
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .preferredColorScheme(.dark)
    }

    private var bootstrappingView: some View {
        ZStack {
            FitnessTheme.background.ignoresSafeArea()

            VStack(spacing: FitnessSpacing.medium) {
                ProgressView()
                    .tint(FitnessTheme.accent)

                Text("Preparing your coaching plan...")
                    .font(FitnessTypography.body)
                    .foregroundStyle(FitnessTheme.secondaryText)
            }
        }
    }
}

#if DEBUG
struct AppRootView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AppRootView(dependencies: .previewSignedOut())
                .previewDisplayName("Signed Out")

            AppRootView(dependencies: .previewSignedIn())
                .previewDisplayName("Signed In")
        }
        .previewDevice("iPhone 14")
    }
}
#endif
