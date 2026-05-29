#if canImport(Core)
import Core
#endif
import Foundation

enum AppPreviewData {
    static let profile = UserProfile(
        analyticsConsent: true,
        dailyCalorieGoal: CalorieGoal(activeEnergyGoal: 650),
        displayName: "Juju"
    )

    static let summary = CalorieSummary(
        date: .now,
        activeEnergyBurned: 420,
        goal: profile.dailyCalorieGoal
    )

    static let workoutPlan = WorkoutPlan(
        title: "Strength Circuit",
        estimatedCalories: 210,
        durationMinutes: 30,
        intensity: .moderate,
        exercises: [
            ExerciseBlock(id: "1", name: "Push-Up", durationMinutes: 10, instructions: "Keep body straight, lower to floor, push up."),
            ExerciseBlock(id: "2", name: "Bodyweight Squat", durationMinutes: 10, instructions: "Stand shoulder-width, lower until thighs are parallel."),
            ExerciseBlock(id: "3", name: "Hip Flexor Stretch", durationMinutes: 10, instructions: "Kneel on one knee, shift hips forward for 30 s each side.")
        ],
        sourceProvider: "Preview",
        rationale: "Upper-body volume is fresh today — this circuit keeps training quality high."
    )

    static let analysis = ExerciseAnalysis(
        classification: "Squat",
        coachingCue: "Keep your chest lifted through the bottom position.",
        postureConfidence: 0.92,
        status: .excellent
    )
}

actor PreviewAuthenticationProvider: AuthenticationProviding {
    private let initialState: AuthenticationState

    init(initialState: AuthenticationState) {
        self.initialState = initialState
    }

    func currentState() async -> AuthenticationState {
        initialState
    }

    func signInWithEmail(email: String, password: String) async throws -> AuthenticationState {
        .signedIn(AppPreviewData.profile)
    }

    func registerWithEmail(email: String, password: String, displayName: String) async throws -> AuthenticationState {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return .signedIn(
            UserProfile(
                id: AppPreviewData.profile.id,
                analyticsConsent: AppPreviewData.profile.analyticsConsent,
                dailyCalorieGoal: AppPreviewData.profile.dailyCalorieGoal,
                displayName: name.isEmpty ? AppPreviewData.profile.displayName : name
            )
        )
    }

    func signInWithGoogle() async throws -> AuthenticationState {
        .signedIn(AppPreviewData.profile)
    }

    func sendPasswordReset(email: String) async throws {
        // Preview: no-op
    }

    func verifyPhoneNumber(_ phoneNumber: String) async throws -> String {
        "preview-verification-id"
    }

    func signInWithPhone(verificationID: String, otp: String) async throws -> AuthenticationState {
        .signedIn(AppPreviewData.profile)
    }

    func signOut() async {}
}

struct PreviewHealthDataProvider: HealthDataProviding {
    let authorizationStatusValue: HealthAuthorizationStatus
    let summary: CalorieSummary

    func authorizationStatus() async -> HealthAuthorizationStatus {
        authorizationStatusValue
    }

    func calorieSummary(for date: Date, goal: CalorieGoal) async throws -> CalorieSummary {
        CalorieSummary(
            date: date,
            activeEnergyBurned: summary.activeEnergyBurned,
            goal: goal
        )
    }

    func requestAuthorization() async throws -> HealthAuthorizationStatus {
        authorizationStatusValue
    }
}

struct PreviewWorkoutRecommendationProvider: WorkoutRecommendationProviding {
    let plan: WorkoutPlan

    func recommend(for input: RecommendationInput) async throws -> WorkoutPlan {
        plan
    }
}

actor PreviewWorkoutSessionStore: WorkoutSessionStoring {
    func save(_ session: WorkoutSessionSummary) async throws {}

    func fetchRecent(limit: Int) async throws -> [WorkoutSessionSummary] {
        []
    }
}

struct PreviewExerciseAnalysisProvider: ExerciseAnalysisProviding {
    let analysis: ExerciseAnalysis

    func analyze(sample: BodyPoseSample) async throws -> ExerciseAnalysis {
        analysis
    }
}

actor PreviewAnalyticsTracker: AnalyticsTracking {
    func track(event: AnalyticsEvent) async {}
}

actor PreviewSettingsStore: SettingsStoring {
    private var settings: AppSettings

    init(settings: AppSettings = .default) {
        self.settings = settings
    }

    func load() async -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) async {
        self.settings = settings
    }
}

actor PreviewSessionStore: SessionStoring {
    func loadSession() async throws -> AuthSession? {
        nil
    }

    func saveSession(_ session: AuthSession) async throws {}

    func clearSession() async throws {}
}

extension AppDependencies {
    static func previewSignedOut() -> AppDependencies {
        AppDependencies(
            analyticsTracker: PreviewAnalyticsTracker(),
            authenticationProvider: PreviewAuthenticationProvider(initialState: .signedOut),
            exerciseAnalysisProvider: PreviewExerciseAnalysisProvider(analysis: AppPreviewData.analysis),
            healthDataProvider: PreviewHealthDataProvider(
                authorizationStatusValue: .unavailable,
                summary: AppPreviewData.summary
            ),
            sessionStore: PreviewSessionStore(),
            settingsStore: PreviewSettingsStore(),
            workoutRecommendationProvider: PreviewWorkoutRecommendationProvider(plan: AppPreviewData.workoutPlan),
            workoutSessionStore: PreviewWorkoutSessionStore()
        )
    }

    static func previewSignedIn() -> AppDependencies {
        AppDependencies(
            analyticsTracker: PreviewAnalyticsTracker(),
            authenticationProvider: PreviewAuthenticationProvider(
                initialState: .signedIn(AppPreviewData.profile)
            ),
            exerciseAnalysisProvider: PreviewExerciseAnalysisProvider(analysis: AppPreviewData.analysis),
            healthDataProvider: PreviewHealthDataProvider(
                authorizationStatusValue: .authorized,
                summary: AppPreviewData.summary
            ),
            sessionStore: PreviewSessionStore(),
            settingsStore: PreviewSettingsStore(),
            workoutRecommendationProvider: PreviewWorkoutRecommendationProvider(plan: AppPreviewData.workoutPlan),
            workoutSessionStore: PreviewWorkoutSessionStore()
        )
    }
}
