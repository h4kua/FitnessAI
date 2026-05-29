import Core
import Foundation
import Infrastructure

public enum MockServiceError: Error {
    case forcedFailure
}

public extension ExerciseBlock {
    static let stub = ExerciseBlock(
        id: "stub-block",
        name: "Stub Block",
        durationMinutes: 10,
        instructions: "Perform the exercise."
    )
}

public extension WorkoutPlan {
    static let stub = WorkoutPlan(
        id: "stub-plan",
        title: "Stub Workout",
        estimatedCalories: 200,
        durationMinutes: 30,
        intensity: .moderate,
        exercises: [.stub],
        sourceProvider: "Test",
        rationale: "Stub rationale"
    )
}

public extension ExerciseTemplate {
    static let stub = ExerciseTemplate(
        id: "stub-exercise",
        name: "Stub Exercise",
        type: .strength,
        difficulty: .moderate,
        equipment: [],
        instructions: "Do the thing.",
        sourceProvider: "Test"
    )
}

public struct MockHealthDataProvider: HealthDataProviding, Sendable {
    public let requestedAuthorizationStatus: HealthAuthorizationStatus
    public let status: HealthAuthorizationStatus
    public let summary: CalorieSummary
    public let throwsOnSummary: Bool

    public init(
        requestedAuthorizationStatus: HealthAuthorizationStatus = .authorized,
        status: HealthAuthorizationStatus = .authorized,
        summary: CalorieSummary,
        throwsOnSummary: Bool = false
    ) {
        self.requestedAuthorizationStatus = requestedAuthorizationStatus
        self.status = status
        self.summary = summary
        self.throwsOnSummary = throwsOnSummary
    }

    public func authorizationStatus() async -> HealthAuthorizationStatus {
        status
    }

    public func calorieSummary(for date: Date, goal: CalorieGoal) async throws -> CalorieSummary {
        switch status {
        case .authorized:
            break
        case .notDetermined:
            if requestedAuthorizationStatus != .authorized {
                throw AppError.authorizationDenied("Health access is required to read active energy.")
            }
        case .denied:
            throw AppError.authorizationDenied("Health access is denied. Update permissions in Settings.")
        case .unavailable:
            throw AppError.unavailable("Health data is unavailable on this device.")
        }

        if throwsOnSummary {
            throw MockServiceError.forcedFailure
        }

        return summary
    }

    public func requestAuthorization() async throws -> HealthAuthorizationStatus {
        requestedAuthorizationStatus
    }
}

public struct MockWorkoutRecommendationProvider: WorkoutRecommendationProviding, Sendable {
    public let planToReturn: WorkoutPlan

    public init(planToReturn: WorkoutPlan = .stub) {
        self.planToReturn = planToReturn
    }

    public func recommend(for input: RecommendationInput) async throws -> WorkoutPlan {
        planToReturn
    }
}

public actor MockWorkoutSessionStore: WorkoutSessionStoring {
    public private(set) var savedSessions: [WorkoutSessionSummary] = []
    private let sessionsToReturn: [WorkoutSessionSummary]

    public init(sessionsToReturn: [WorkoutSessionSummary] = []) {
        self.sessionsToReturn = sessionsToReturn
    }

    public func save(_ session: WorkoutSessionSummary) async throws {
        savedSessions.append(session)
    }

    public func fetchRecent(limit: Int) async throws -> [WorkoutSessionSummary] {
        Array(sessionsToReturn.prefix(limit))
    }
}

public struct MockExerciseCatalog: ExerciseCatalogProviding, Sendable {
    public let templates: [ExerciseTemplate]

    public init(templates: [ExerciseTemplate] = [.stub]) {
        self.templates = templates
    }

    public func exercises(matching query: ExerciseSearchQuery) async throws -> [ExerciseTemplate] {
        templates
    }
}

public struct MockCalorieEstimator: CalorieEstimating, Sendable {
    public let caloriesPerMinute: Double

    public init(caloriesPerMinute: Double = 8) {
        self.caloriesPerMinute = caloriesPerMinute
    }

    public func estimate(activityName: String, durationMinutes: Int, weightPounds: Double?) async throws -> CalorieEstimate {
        CalorieEstimate(
            activityName: activityName,
            estimatedCalories: Double(durationMinutes) * caloriesPerMinute,
            durationMinutes: durationMinutes
        )
    }
}

public struct MockSafetyChecker: WorkoutSafetyChecking, Sendable {
    public let result: SafetyResult

    public init(result: SafetyResult = .approved) {
        self.result = result
    }

    public func check(plan: WorkoutPlan, input: RecommendationInput) -> SafetyResult {
        result
    }
}

public actor MockAnalyticsTracker: AnalyticsTracking {
    public private(set) var events: [AnalyticsEvent] = []

    public init() {}

    public func track(event: AnalyticsEvent) async {
        events.append(event)
    }
}

public actor MockSettingsStore: SettingsStoring {
    public private(set) var savedSettings: [AppSettings] = []
    private let loadedSettings: AppSettings

    public init(loadedSettings: AppSettings) {
        self.loadedSettings = loadedSettings
    }

    public func load() async -> AppSettings {
        loadedSettings
    }

    public func save(_ settings: AppSettings) async {
        savedSettings.append(settings)
    }
}

public actor MockSessionStore: SessionStoring {
    public private(set) var clearCallCount = 0
    public private(set) var loadCallCount = 0
    public private(set) var savedSessions: [AuthSession] = []
    private var session: AuthSession?

    public init(session: AuthSession? = nil) {
        self.session = session
    }

    public func loadSession() async throws -> AuthSession? {
        loadCallCount += 1
        return session
    }

    public func saveSession(_ session: AuthSession) async throws {
        self.session = session
        savedSessions.append(session)
    }

    public func clearSession() async throws {
        clearCallCount += 1
        session = nil
    }
}

public actor MockHTTPClient: HTTPClient {
    public enum Response {
        case failure(Error)
        case success(HTTPResponse)
    }

    public private(set) var requests: [APIRequest] = []
    private var queuedResponses: [Response]

    public init(queuedResponses: [Response]) {
        self.queuedResponses = queuedResponses
    }

    public func send(_ request: APIRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard queuedResponses.isEmpty == false else {
            throw MockServiceError.forcedFailure
        }

        let response = queuedResponses.removeFirst()
        switch response {
        case .failure(let error):
            throw error
        case .success(let response):
            return response
        }
    }
}

public actor MockAuthenticationProvider: AuthenticationProviding {
    public enum Behavior {
        case succeed(UserProfile)
        case fail(Error)
    }

    public private(set) var currentAuthenticationState: AuthenticationState
    public private(set) var signInCallCount = 0
    public private(set) var signOutCallCount = 0

    private let signInBehavior: Behavior
    private let signInDelayNanoseconds: UInt64

    public init(
        currentAuthenticationState: AuthenticationState = .signedOut,
        signInBehavior: Behavior,
        signInDelayNanoseconds: UInt64 = 0
    ) {
        self.currentAuthenticationState = currentAuthenticationState
        self.signInBehavior = signInBehavior
        self.signInDelayNanoseconds = signInDelayNanoseconds
    }

    public func currentState() async -> AuthenticationState {
        currentAuthenticationState
    }

    public func signIn(displayName: String?) async throws -> AuthenticationState {
        signInCallCount += 1

        if signInDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: signInDelayNanoseconds)
        }

        switch signInBehavior {
        case .succeed(let user):
            let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let resolvedUser = UserProfile(
                id: user.id,
                analyticsConsent: user.analyticsConsent,
                dailyCalorieGoal: user.dailyCalorieGoal,
                displayName: trimmedName.isEmpty ? user.displayName : trimmedName
            )
            let state: AuthenticationState = .signedIn(resolvedUser)
            currentAuthenticationState = state
            return state
        case .fail(let error):
            throw error
        }
    }

    public func signOut() async {
        signOutCallCount += 1
        currentAuthenticationState = .signedOut
    }
}

public actor MockExerciseAnalysisProvider: ExerciseAnalysisProviding {
    public enum Behavior {
        case succeed(ExerciseAnalysis)
        case fail(Error)
    }

    public private(set) var analyzeCallCount = 0
    private let behavior: Behavior
    private let delayNanoseconds: UInt64

    public init(
        behavior: Behavior,
        delayNanoseconds: UInt64 = 0
    ) {
        self.behavior = behavior
        self.delayNanoseconds = delayNanoseconds
    }

    public func analyze(sample: BodyPoseSample) async throws -> ExerciseAnalysis {
        analyzeCallCount += 1

        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }

        switch behavior {
        case .succeed(let analysis):
            return analysis
        case .fail(let error):
            throw error
        }
    }
}
