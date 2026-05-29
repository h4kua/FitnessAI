#if canImport(AnalyticsService)
import AnalyticsService
#endif
#if canImport(AuthenticationService)
import AuthenticationService
#endif
#if canImport(Core)
import Core
#endif
#if canImport(HealthKitService)
import HealthKitService
#endif
#if canImport(Infrastructure)
import Infrastructure
#endif
#if canImport(VisionMLService)
import VisionMLService
#endif
#if canImport(WorkoutRecommendationService)
import WorkoutRecommendationService
#endif
import Foundation

public struct AppDependencies: Sendable {
    public let analyticsTracker: any AnalyticsTracking
    public let authenticationProvider: any AuthenticationProviding
    public let exerciseAnalysisProvider: any ExerciseAnalysisProviding
    public let groqCoachingService: GroqCoachingService?
    public let healthDataProvider: any HealthDataProviding
    public let sessionStore: any SessionStoring
    public let settingsStore: any SettingsStoring
    public let workoutRecommendationProvider: any WorkoutRecommendationProviding
    public let workoutSessionStore: any WorkoutSessionStoring

    public init(
        analyticsTracker: any AnalyticsTracking,
        authenticationProvider: any AuthenticationProviding,
        exerciseAnalysisProvider: any ExerciseAnalysisProviding,
        groqCoachingService: GroqCoachingService? = nil,
        healthDataProvider: any HealthDataProviding,
        sessionStore: any SessionStoring,
        settingsStore: any SettingsStoring,
        workoutRecommendationProvider: any WorkoutRecommendationProviding,
        workoutSessionStore: any WorkoutSessionStoring
    ) {
        self.analyticsTracker = analyticsTracker
        self.authenticationProvider = authenticationProvider
        self.exerciseAnalysisProvider = exerciseAnalysisProvider
        self.groqCoachingService = groqCoachingService
        self.healthDataProvider = healthDataProvider
        self.sessionStore = sessionStore
        self.settingsStore = settingsStore
        self.workoutRecommendationProvider = workoutRecommendationProvider
        self.workoutSessionStore = workoutSessionStore
    }
}

public extension AppDependencies {
    static func live(environment: AppEnvironment = .live()) -> AppDependencies {
        let logger = AppLogger(category: "FitnessCoach")
        let httpClient = URLSessionHTTPClient(logger: logger)
        let settingsStore = UserDefaultsSettingsStore(logger: logger)
        let sessionStore = KeychainSessionStore()
        let analyticsTracker = LiveAnalyticsService(
            settingsStore: settingsStore,
            logger: logger
        )

        let authenticationProvider: any AuthenticationProviding = FirebaseAuthenticationService(logger: logger)
        logger.info("Firebase authentication configured")

        let healthDataProvider: any HealthDataProviding
        if environment.usesDemoHealthData {
            healthDataProvider = DemoHealthDataProvider()
            logger.info("Using demo health data provider for build \(environment.buildConfiguration)")
        } else {
            healthDataProvider = LiveHealthKitService(logger: logger)
        }

        let safetyPolicy = WorkoutSafetyPolicy()
        let workoutRecommendationProvider: any WorkoutRecommendationProviding
        if let apiNinjasKey = environment.apiNinjasKey {
            workoutRecommendationProvider = WorkoutRecommendationEngine(
                catalog: ApiNinjasExerciseCatalogService(apiKey: apiNinjasKey, httpClient: httpClient, requestTimeout: environment.requestTimeout),
                calorieEstimator: ApiNinjasCalorieEstimatingService(apiKey: apiNinjasKey, httpClient: httpClient, requestTimeout: environment.requestTimeout),
                safetyChecker: safetyPolicy,
                logger: logger
            )
            logger.info("Workout recommendations using API Ninjas")
        } else {
            workoutRecommendationProvider = WorkoutRecommendationEngine(
                catalog: BuiltInExerciseCatalog(),
                calorieEstimator: LocalCalorieEstimator(),
                safetyChecker: safetyPolicy,
                logger: logger
            )
            logger.info("Workout recommendations using built-in catalog (no API_NINJAS_KEY set)")
        }

        let workoutSessionStore: any WorkoutSessionStoring = FirebaseWorkoutSessionStore()
        logger.info("Firestore workout session store configured")

        let groqCoaching: GroqCoachingService?
        if let groqKey = environment.groqApiKey {
            groqCoaching = GroqCoachingService(apiKey: groqKey, httpClient: httpClient, logger: logger)
            logger.info("Groq coaching service enabled")
        } else {
            groqCoaching = nil
            logger.info("Groq coaching disabled (GROK_ENV not set — add it to Xcode scheme environment variables)")
        }

        let exerciseAnalysisProvider = VisionExerciseAnalysisService(logger: logger, groqCoaching: groqCoaching)
        logger.info("Bootstrapping app environment \(environment.buildConfiguration)")

        return AppDependencies(
            analyticsTracker: analyticsTracker,
            authenticationProvider: authenticationProvider,
            exerciseAnalysisProvider: exerciseAnalysisProvider,
            groqCoachingService: groqCoaching,
            healthDataProvider: healthDataProvider,
            sessionStore: sessionStore,
            settingsStore: settingsStore,
            workoutRecommendationProvider: workoutRecommendationProvider,
            workoutSessionStore: workoutSessionStore
        )
    }
}

private struct BuiltInExerciseCatalog: ExerciseCatalogProviding {
    func exercises(matching query: ExerciseSearchQuery) async throws -> [ExerciseTemplate] {
        [
            ExerciseTemplate(id: "builtin-walk", name: "Brisk Walk", type: .cardio, difficulty: .low, equipment: [], instructions: "Walk at a brisk pace, keeping a conversational effort level.", sourceProvider: "Built-in"),
            ExerciseTemplate(id: "builtin-squat", name: "Bodyweight Squat", type: .strength, difficulty: .moderate, equipment: [], instructions: "Stand shoulder-width apart, lower until thighs are parallel, then drive back up.", sourceProvider: "Built-in"),
            ExerciseTemplate(id: "builtin-pushup", name: "Push-Up", type: .strength, difficulty: .moderate, equipment: [], instructions: "Keep body in a straight line, lower chest to the floor, then push back up.", sourceProvider: "Built-in"),
            ExerciseTemplate(id: "builtin-jog", name: "Light Jog", type: .cardio, difficulty: .moderate, equipment: [], instructions: "Run at a comfortable, sustainable pace. Breathe through your nose if possible.", sourceProvider: "Built-in"),
            ExerciseTemplate(id: "builtin-hip-stretch", name: "Hip Flexor Stretch", type: .stretching, difficulty: .low, equipment: [], instructions: "Kneel on one knee, shift hips forward for 30 seconds each side.", sourceProvider: "Built-in")
        ]
    }
}

private struct LocalCalorieEstimator: CalorieEstimating {
    private let metTable: [String: Double] = [
        "brisk walk": 4.0,
        "light jog": 7.0,
        "bodyweight squat": 5.0,
        "push-up": 4.5,
        "hip flexor stretch": 2.5
    ]

    func estimate(activityName: String, durationMinutes: Int, weightPounds: Double?) async throws -> CalorieEstimate {
        let met = metTable[activityName.lowercased()] ?? 5.0
        let weightKg = (weightPounds ?? 154) * 0.453592
        let calories = met * weightKg * (Double(durationMinutes) / 60.0)
        return CalorieEstimate(activityName: activityName, estimatedCalories: calories, durationMinutes: durationMinutes)
    }
}

private struct DemoHealthDataProvider: HealthDataProviding {
    func authorizationStatus() async -> HealthAuthorizationStatus {
        .unavailable
    }

    func calorieSummary(for date: Date, goal: CalorieGoal) async throws -> CalorieSummary {
        let burned = max(goal.activeEnergyGoal * 0.68, 420)
        return CalorieSummary(
            date: date,
            activeEnergyBurned: burned,
            goal: goal
        )
    }

    func requestAuthorization() async throws -> HealthAuthorizationStatus {
        .unavailable
    }
}
