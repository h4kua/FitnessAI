import Combine
#if canImport(Core)
import Core
#endif
import Foundation

@MainActor
public final class SettingsViewModel: ObservableObject {

    // MARK: - App Settings (via SettingsStoring)
    @Published public var analyticsEnabled    = AppSettings.default.analyticsEnabled
    @Published public var coachingHintsEnabled = AppSettings.default.coachingHintsEnabled
    @Published public var calorieGoal: Double  = AppSettings.default.dailyCalorieGoal.activeEnergyGoal
    @Published public private(set) var loadState: LoadState = .idle

    // MARK: - Body Profile (via UserDefaults directly)
    @Published public var heightCm: Double = 170
    @Published public var weightKg: Double = 70
    @Published public var age: Int = 25
    @Published public var isMale: Bool = true
    @Published public var activityLevelRaw: String = ActivityLevel.moderate.rawValue

    // MARK: - Body Goal
    @Published public var goalTypeRaw: String = BodyGoalType.buildMuscle.rawValue
    @Published public var goalDurationMonths: Int = 3
    @Published public var goalStartTimestamp: Double = 0

    /// Set this from the app shell to trigger sign-out via the auth provider.
    public var onSignOutRequested: (() -> Void)?

    private let settingsStore: any SettingsStoring
    private let defaults = UserDefaults.standard

    // MARK: - Computed Body Profile

    public var bodyProfile: BodyProfile {
        BodyProfile(
            heightCm: heightCm,
            weightKg: weightKg,
            age: age,
            isMale: isMale,
            activityLevel: ActivityLevel(rawValue: activityLevelRaw) ?? .moderate
        )
    }

    public var bodyGoal: BodyGoal {
        let ts = goalStartTimestamp > 0 ? goalStartTimestamp : Date().timeIntervalSinceReferenceDate
        return BodyGoal(
            goalType: BodyGoalType(rawValue: goalTypeRaw) ?? .buildMuscle,
            durationMonths: max(1, goalDurationMonths),
            startDate: Date(timeIntervalSinceReferenceDate: ts)
        )
    }

    // MARK: - Init

    public init(settingsStore: any SettingsStoring) {
        self.settingsStore = settingsStore
    }

    // MARK: - Load

    public func load() async {
        guard loadState != .loading else { return }
        loadState = .loading

        let settings = await settingsStore.load()
        analyticsEnabled    = settings.analyticsEnabled
        coachingHintsEnabled = settings.coachingHintsEnabled
        calorieGoal         = settings.dailyCalorieGoal.activeEnergyGoal

        // Body profile from UserDefaults
        let h = defaults.double(forKey: "profile.heightCm")
        heightCm = h > 0 ? h : 170
        let w = defaults.double(forKey: "profile.weightKg")
        weightKg = w > 0 ? w : 70
        let a = defaults.integer(forKey: "profile.age")
        age = a > 0 ? a : 25
        if defaults.object(forKey: "profile.isMale") != nil {
            isMale = defaults.bool(forKey: "profile.isMale")
        }
        activityLevelRaw = defaults.string(forKey: "profile.activityLevel") ?? ActivityLevel.moderate.rawValue
        goalTypeRaw      = defaults.string(forKey: "goal.type")             ?? BodyGoalType.buildMuscle.rawValue
        let gd = defaults.integer(forKey: "goal.durationMonths")
        goalDurationMonths  = gd > 0 ? gd : 3
        goalStartTimestamp  = defaults.double(forKey: "goal.startTimestamp")

        loadState = .loaded
    }

    // MARK: - App Settings Mutations

    public func updateAnalytics(enabled: Bool) async {
        analyticsEnabled = enabled
        await persist()
    }

    public func updateCoachingHints(enabled: Bool) async {
        coachingHintsEnabled = enabled
        await persist()
    }

    public func updateCalorieGoal(_ kcal: Double) async {
        calorieGoal = kcal
        await persist()
    }

    // MARK: - Body Profile Mutations

    public func updateBodyProfile(
        heightCm: Double,
        weightKg: Double,
        age: Int,
        isMale: Bool,
        activityLevel: ActivityLevel
    ) {
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.age = age
        self.isMale = isMale
        self.activityLevelRaw = activityLevel.rawValue

        defaults.set(heightCm,              forKey: "profile.heightCm")
        defaults.set(weightKg,              forKey: "profile.weightKg")
        defaults.set(age,                   forKey: "profile.age")
        defaults.set(isMale,                forKey: "profile.isMale")
        defaults.set(activityLevel.rawValue, forKey: "profile.activityLevel")
    }

    public func updateGoal(type: BodyGoalType, durationMonths: Int) {
        goalTypeRaw        = type.rawValue
        goalDurationMonths = durationMonths
        goalStartTimestamp = Date().timeIntervalSinceReferenceDate

        defaults.set(type.rawValue,                        forKey: "goal.type")
        defaults.set(durationMonths,                       forKey: "goal.durationMonths")
        defaults.set(goalStartTimestamp,                   forKey: "goal.startTimestamp")
    }

    // MARK: - Sign Out

    public func signOut() {
        onSignOutRequested?()
    }

    // MARK: - Private

    private func persist() async {
        await settingsStore.save(
            AppSettings(
                analyticsEnabled:    analyticsEnabled,
                coachingHintsEnabled: coachingHintsEnabled,
                dailyCalorieGoal:    CalorieGoal(activeEnergyGoal: calorieGoal)
            )
        )
    }
}
