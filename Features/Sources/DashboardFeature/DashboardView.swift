#if canImport(Core)
import Core
#endif
#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

public struct DashboardView: View {
    @ObservedObject private var viewModel: DashboardViewModel

    // Body profile from UserDefaults (shared with SettingsViewModel)
    @AppStorage("profile.displayName") private var displayName: String = ""
    @AppStorage("profile.heightCm")    private var heightCm: Double = 170
    @AppStorage("profile.weightKg")    private var weightKg: Double = 70
    @AppStorage("profile.age")         private var age: Int = 25
    @AppStorage("profile.isMale")      private var isMale: Bool = true
    @AppStorage("profile.activityLevel") private var activityLevelRaw: String = ActivityLevel.moderate.rawValue
    @AppStorage("goal.type")           private var goalTypeRaw: String = BodyGoalType.buildMuscle.rawValue
    @AppStorage("goal.durationMonths") private var goalDurationMonths: Int = 3
    @AppStorage("goal.startTimestamp") private var goalStartTimestamp: Double = 0

    private var bodyProfile: BodyProfile {
        BodyProfile(heightCm: heightCm, weightKg: weightKg, age: age, isMale: isMale,
                    activityLevel: ActivityLevel(rawValue: activityLevelRaw) ?? .moderate)
    }

    private var bodyGoal: BodyGoal {
        let ts = goalStartTimestamp > 0 ? goalStartTimestamp : Date().timeIntervalSinceReferenceDate
        return BodyGoal(
            goalType: BodyGoalType(rawValue: goalTypeRaw) ?? .buildMuscle,
            durationMonths: max(1, goalDurationMonths),
            startDate: Date(timeIntervalSinceReferenceDate: ts)
        )
    }

    private var todayTraining: TrainingDay {
        TrainingDay.day(for: bodyGoal.goalType, day: bodyGoal.currentDay)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        return df
    }()

    public init(viewModel: DashboardViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FitnessSpacing.medium) {
                    heroBanner
                    statsRow
                    if let message = viewModel.healthStatusMessage { previewModeCard(message) }

                    switch viewModel.loadState {
                    case .idle, .loading:
                        ScreenStateCard(
                            title: "Loading your data",
                            message: "Syncing activity and building your daily coaching snapshot.",
                            imageSystemName: "bolt.heart"
                        )
                    case .failed(let message):
                        ScreenStateCard(
                            title: "Health data unavailable",
                            message: message,
                            imageSystemName: "exclamationmark.triangle",
                            tint: FitnessTheme.caution,
                            actionTitle: "Try Again",
                            onAction: reload
                        )
                    case .loaded:
                        loadedContent
                    }
                }
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.bottom, FitnessSpacing.xLarge)
            }
            .background(FitnessTheme.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationBarHidden(true)
            .task {
                guard viewModel.loadState == .idle else { return }
                await viewModel.load()
            }
            .refreshable { await viewModel.load() }
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        GradientCard(gradient: FitnessTheme.heroGradient) {
            VStack(alignment: .leading, spacing: FitnessSpacing.small) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.dateFormatter.string(from: Date()))
                            .font(FitnessTypography.tiny)
                            .foregroundStyle(FitnessTheme.secondaryText)
                            .tracking(0.5)
                        Text("\(greeting), \(displayName.isEmpty ? "Champion" : displayName)!")
                            .font(FitnessTypography.sectionTitle)
                            .foregroundStyle(FitnessTheme.primaryText)
                    }
                    Spacer()
                    // Goal badge
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: bodyGoal.goalType.systemImage)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(goalTint)
                        Text(bodyGoal.goalType.rawValue)
                            .font(FitnessTypography.tiny)
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }
                }

                // Day progress
                VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                    HStack {
                        Text("Day \(bodyGoal.currentDay) of \(bodyGoal.totalDays)")
                            .font(FitnessTypography.subtitle)
                            .foregroundStyle(FitnessTheme.primaryText)
                        Spacer()
                        Text("\(bodyGoal.daysRemaining) days left")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(FitnessTheme.progressTrack)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(goalTint)
                                .frame(width: max(8, geo.size.width * bodyGoal.progressRatio))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.top, FitnessSpacing.xSmall)
            }
        }
    }

    // MARK: - Stats Row (mini rings)

    private var statsRow: some View {
        HStack(spacing: FitnessSpacing.small) {
            let ratio: Double = viewModel.calorieSummary.map { $0.completionRatio } ?? 0
            let kcal  = Int(viewModel.calorieSummary?.activeEnergyBurned ?? 0)

            MiniRingView(
                progress: ratio,
                tint: FitnessTheme.energy,
                icon: "flame.fill",
                label: "Calories",
                value: "\(kcal) kcal"
            )

            MiniRingView(
                progress: bodyGoal.progressRatio,
                tint: goalTint,
                icon: bodyGoal.goalType.systemImage,
                label: "Goal",
                value: "\(Int(bodyGoal.progressRatio * 100))%"
            )

            MiniRingView(
                progress: min(1, Double(bodyGoal.currentDay) / 7.0),
                tint: FitnessTheme.strength,
                icon: "calendar",
                label: "Day",
                value: "D\(bodyGoal.currentDay)"
            )
        }
    }

    // MARK: - Loaded Content

    @ViewBuilder
    private var loadedContent: some View {
        // 🎉 Daily goal completion banner — shown once the target is hit
        if viewModel.isGoalCompletedToday {
            goalCompletedBanner
        }

        // Apple Health connect prompt
        if viewModel.healthAuthorizationStatus == .notDetermined {
            healthConnectCard
        }

        // Today's workout from plan
        todayWorkoutCard

        // Calorie progress card
        if let summary = viewModel.calorieSummary {
            calorieCard(summary: summary)
        }

        // Workout recommendation
        if let plan = viewModel.workoutPlan {
            recommendedWorkoutCard(plan: plan)
        }

        // AI coaching tip
        coachTipCard
    }

    // MARK: - Goal Completed Banner

    private var goalCompletedBanner: some View {
        GradientCard(gradient: FitnessTheme.accentGradient) {
            HStack(spacing: FitnessSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Text("🏆")
                        .font(.system(size: 28))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Goal Achieved!")
                        .font(FitnessTypography.sectionTitle)
                        .foregroundStyle(.black)
                    Text("You've hit your active-energy target for today. Great work — rest up and come back stronger tomorrow.")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(.black.opacity(0.75))
                        .lineLimit(3)
                }
                Spacer()
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Health Connect Card

    private var healthConnectCard: some View {
        FitnessCard {
            HStack(spacing: FitnessSpacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(FitnessTheme.energy.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(FitnessTheme.energy)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect Apple Health")
                        .font(FitnessTypography.subtitle)
                        .foregroundStyle(FitnessTheme.primaryText)
                    Text("Sync calories, steps & activity to unlock full tracking.")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }
                Spacer()
            }

            Button {
                Task { await viewModel.requestHealthAccess() }
            } label: {
                Label("Connect", systemImage: "heart.text.square")
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .padding(.top, FitnessSpacing.small)
        }
    }

    // MARK: - Today's Workout from Plan

    private var todayWorkoutCard: some View {
        GradientCard(gradient: trainingGradient) {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                HStack {
                    Label("TODAY'S SESSION", systemImage: "bolt.fill")
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(.black.opacity(0.60))
                        .tracking(1)
                    Spacer()
                    Text("Day \(bodyGoal.currentDay)")
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(.black.opacity(0.60))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.12)))
                }

                Text(todayTraining.title)
                    .font(FitnessTypography.sectionTitle)
                    .foregroundStyle(.black.opacity(0.90))

                Text(todayTraining.focusArea)
                    .font(FitnessTypography.body)
                    .foregroundStyle(.black.opacity(0.70))

                HStack {
                    Label(todayTraining.sessionLabel, systemImage: "bolt.heart")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(.black.opacity(0.70))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.black.opacity(0.10)))
                    Spacer()
                    if !todayTraining.isRest {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.black.opacity(0.80))
                    }
                }
            }
        }
    }

    // MARK: - Calorie Card

    private func calorieCard(summary: CalorieSummary) -> some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                HStack {
                    Label("ACTIVE ENERGY", systemImage: "flame.fill")
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(FitnessTheme.energy)
                        .tracking(1)
                    Spacer()
                    if viewModel.isGoalCompletedToday {
                        Label("Goal Complete", systemImage: "checkmark.circle.fill")
                            .font(FitnessTypography.tiny)
                            .foregroundStyle(FitnessTheme.success)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(FitnessTheme.success.opacity(0.12))
                            .clipShape(Capsule())
                    } else {
                        Text("\(Int(summary.completionRatio * 100))% of goal")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }
                }

                HStack(alignment: .center, spacing: FitnessSpacing.large) {
                    CircularProgressView(progress: summary.completionRatio, tint: FitnessTheme.energy)
                        .frame(width: 80, height: 80)
                        .overlay(
                            VStack(spacing: 0) {
                                Text("\(Int(summary.completionRatio * 100))%")
                                    .font(FitnessTypography.subtitle)
                                    .foregroundStyle(FitnessTheme.primaryText)
                                Text("done")
                                    .font(FitnessTypography.tiny)
                                    .foregroundStyle(FitnessTheme.secondaryText)
                            }
                        )

                    VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                        Text("\(Int(summary.activeEnergyBurned)) kcal")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(FitnessTheme.primaryText)
                        Text("burned today")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                        Text(summary.remainingEnergy > 0
                             ? "\(Int(summary.remainingEnergy)) kcal remaining"
                             : "Daily target reached! 🎉")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(summary.remainingEnergy > 0 ? FitnessTheme.caution : FitnessTheme.success)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active energy: \(Int(summary.activeEnergyBurned)) of \(Int(summary.goal.activeEnergyGoal)) kilocalories")
    }

    // MARK: - Recommended Workout

    private func recommendedWorkoutCard(plan: WorkoutPlan) -> some View {
        FitnessCard(title: "AI Recommendation") {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(FitnessTypography.subtitle)
                            .foregroundStyle(FitnessTheme.primaryText)
                        Text(plan.rationale)
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                            .lineLimit(2)
                    }
                    Spacer()
                }

                HStack(spacing: FitnessSpacing.small) {
                    MetricBadge(systemImage: "timer", text: "\(plan.durationMinutes) min")
                    MetricBadge(systemImage: "flame.fill", text: "\(Int(plan.estimatedCalories)) kcal", tint: FitnessTheme.energy)
                    MetricBadge(systemImage: "bolt", text: plan.intensity.rawValue.capitalized, tint: FitnessTheme.strength)
                }
            }
        }
    }

    // MARK: - Coach Tip

    private var coachTipCard: some View {
        FitnessCard {
            HStack(alignment: .top, spacing: FitnessSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(FitnessTheme.accentGradient)
                        .frame(width: 40, height: 40)
                    Image(systemName: "brain")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }

                VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                    Text("AI Coach Tip")
                        .font(FitnessTypography.subtitle)
                        .foregroundStyle(FitnessTheme.primaryText)
                    Text(coachTip)
                        .font(FitnessTypography.body)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }
            }
        }
    }

    // MARK: - Preview Mode Card

    private func previewModeCard(_ message: String) -> some View {
        FitnessCard {
            Label(message, systemImage: "info.circle")
                .font(FitnessTypography.caption)
                .foregroundStyle(FitnessTheme.secondaryText)
        }
    }

    // MARK: - Computed

    private var goalTint: Color {
        switch bodyGoal.goalType {
        case .loseFat:     return FitnessTheme.energy
        case .buildMuscle: return FitnessTheme.strength
        case .athletic:    return FitnessTheme.purple
        case .maintain:    return FitnessTheme.accent
        }
    }

    private var trainingGradient: LinearGradient {
        switch bodyGoal.goalType {
        case .loseFat:     return FitnessTheme.energyGradient
        case .buildMuscle: return FitnessTheme.strengthGradient
        case .athletic:    return FitnessTheme.goalGradient
        case .maintain:    return FitnessTheme.accentGradient
        }
    }

    private var coachTip: String {
        let tips: [String] = {
            switch bodyGoal.goalType {
            case .loseFat:
                return [
                    "Prioritize protein at every meal — it keeps you full and preserves muscle while you cut.",
                    "HIIT is 3× more effective for fat loss than steady cardio per unit of time.",
                    "Drink water before meals to naturally reduce calorie intake by ~75–90 kcal.",
                ]
            case .buildMuscle:
                return [
                    "Progressive overload is king — aim to add 2.5 kg every 1–2 weeks on key lifts.",
                    "Sleep is anabolic: GH peaks during deep sleep, which is when muscle is actually built.",
                    "Eat 1.6–2.2 g of protein per kg of bodyweight daily for optimal muscle protein synthesis.",
                ]
            case .athletic:
                return [
                    "Carbohydrates are your performance fuel — don't restrict them on training days.",
                    "Speed and power work should come BEFORE endurance in the same session.",
                    "Recovery is part of training — 8 hours of sleep improves sprint times by ~5%.",
                ]
            case .maintain:
                return [
                    "Consistency beats intensity — 3 moderate workouts per week beats occasional hero sessions.",
                    "Mobility work 10 min per day prevents injury and extends your training lifespan.",
                    "Track weekly average weight, not daily — fluctuations of 1–2 kg are completely normal.",
                ]
            }
        }()
        let day = bodyGoal.currentDay
        return tips[day % tips.count]
    }

    private func reload() {
        Task { await viewModel.load() }
    }
}
