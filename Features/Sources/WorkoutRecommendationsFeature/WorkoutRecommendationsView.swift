#if canImport(Core)
import Core
#endif
#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

public struct WorkoutRecommendationsView: View {
    @ObservedObject private var viewModel: WorkoutRecommendationsViewModel

    // Body goal from UserDefaults
    @AppStorage("goal.type")           private var goalTypeRaw: String = BodyGoalType.buildMuscle.rawValue
    @AppStorage("goal.durationMonths") private var goalDurationMonths: Int = 3
    @AppStorage("goal.startTimestamp") private var goalStartTimestamp: Double = 0

    private var goalType: BodyGoalType { BodyGoalType(rawValue: goalTypeRaw) ?? .buildMuscle }

    private var bodyGoal: BodyGoal {
        let ts = goalStartTimestamp > 0 ? goalStartTimestamp : Date().timeIntervalSinceReferenceDate
        return BodyGoal(goalType: goalType, durationMonths: max(1, goalDurationMonths),
                        startDate: Date(timeIntervalSinceReferenceDate: ts))
    }

    private var weekDays: [TrainingDay] {
        TrainingDay.weekPlan(for: goalType, startingFromDay: bodyGoal.currentDay)
    }

    private var todayPlan: TrainingDay {
        TrainingDay.day(for: goalType, day: bodyGoal.currentDay)
    }

    public init(viewModel: WorkoutRecommendationsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FitnessSpacing.medium) {
                    planHeroBanner
                    weekStrip
                    if let msg = viewModel.healthStatusMessage { previewBanner(msg) }
                    preferencesCard
                    todaySessionCard

                    switch viewModel.loadState {
                    case .idle, .loading:
                        ScreenStateCard(
                            title: "Building your session",
                            message: "Matching exercises to your goal, energy level, and time available.",
                            imageSystemName: "sparkles"
                        )
                    case .failed(let msg):
                        ScreenStateCard(
                            title: "Session unavailable",
                            message: msg,
                            imageSystemName: "figure.strengthtraining.traditional",
                            actionTitle: "Refresh",
                            onAction: refresh
                        )
                    case .loaded:
                        if let plan = viewModel.plan {
                            exercisePlanCard(plan)
                            if !plan.safetyNotes.isEmpty { safetyCard(plan.safetyNotes) }
                        }
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
                await viewModel.refresh()
            }
        }
    }

    // MARK: - Plan Hero Banner

    private var planHeroBanner: some View {
        GradientCard(gradient: planGradient) {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                HStack {
                    Label("TRAINING PLAN", systemImage: "calendar.badge.checkmark")
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(.black.opacity(0.60))
                        .tracking(1)
                    Spacer()
                    Image(systemName: goalType.systemImage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.black.opacity(0.70))
                }

                HStack(alignment: .firstTextBaseline, spacing: FitnessSpacing.small) {
                    Text("Day")
                        .font(FitnessTypography.sectionTitle)
                        .foregroundStyle(.black.opacity(0.60))
                    Text("\(bodyGoal.currentDay)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.black.opacity(0.90))
                    Text("/ \(bodyGoal.totalDays)")
                        .font(FitnessTypography.sectionTitle)
                        .foregroundStyle(.black.opacity(0.50))
                        .padding(.bottom, 6)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 5).fill(Color.black.opacity(0.15))
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white.opacity(0.80))
                            .frame(width: max(12, geo.size.width * bodyGoal.progressRatio))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(goalType.rawValue)
                        .font(FitnessTypography.subtitle)
                        .foregroundStyle(.black.opacity(0.80))
                    Spacer()
                    Text("\(bodyGoal.daysRemaining) days left")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(.black.opacity(0.60))
                }
            }
        }
        .padding(.top, FitnessSpacing.medium)
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FitnessSpacing.small) {
                ForEach(weekDays) { day in
                    dayChip(day, isToday: day.id == bodyGoal.currentDay)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func dayChip(_ day: TrainingDay, isToday: Bool) -> some View {
        VStack(spacing: FitnessSpacing.xSmall) {
            Text("D\(day.id)")
                .font(FitnessTypography.tiny)
                .foregroundStyle(isToday ? .black : FitnessTheme.secondaryText)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isToday ? planAccentColor : (day.isRest ? FitnessTheme.surface2 : FitnessTheme.surface))
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isToday ? .clear : FitnessTheme.surfaceStroke, lineWidth: 1)
                    )
                Image(systemName: dayIcon(day))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isToday ? .black : (day.isRest ? FitnessTheme.tertiaryText : planAccentColor))
            }
            .shadow(color: isToday ? planAccentColor.opacity(0.40) : .clear, radius: 8)

            Text(day.isRest ? "Rest" : dayLabel(day))
                .font(FitnessTypography.tiny)
                .foregroundStyle(isToday ? planAccentColor : FitnessTheme.secondaryText)
                .lineLimit(1)
                .frame(width: 52)
        }
    }

    private func dayIcon(_ day: TrainingDay) -> String {
        switch day.sessionType {
        case .rest:    return "moon.zzz.fill"
        case .active:  return "figure.walk"
        case .workout(let intensity):
            switch intensity {
            case "HIIT":    return "flame.fill"
            case "Heavy":   return "dumbbell.fill"
            case "High":    return "bolt.fill"
            default:        return "figure.run"
            }
        }
    }

    private func dayLabel(_ day: TrainingDay) -> String {
        switch day.sessionType {
        case .rest:    return "Rest"
        case .active:  return "Active"
        case .workout: return "Train"
        }
    }

    // MARK: - Today's Session Card

    private var todaySessionCard: some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                HStack {
                    Label("TODAY", systemImage: "bolt.fill")
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(planAccentColor)
                        .tracking(1)
                    Spacer()
                    if !todayPlan.isRest {
                        Text(todayPlan.sessionLabel)
                            .font(FitnessTypography.tiny)
                            .foregroundStyle(FitnessTheme.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(FitnessTheme.surface2))
                    }
                }

                Text(todayPlan.title)
                    .font(FitnessTypography.sectionTitle)
                    .foregroundStyle(FitnessTheme.primaryText)

                Label(todayPlan.focusArea, systemImage: "target")
                    .font(FitnessTypography.body)
                    .foregroundStyle(FitnessTheme.secondaryText)
            }
        }
    }

    // MARK: - Preferences Card

    private var preferencesCard: some View {
        FitnessCard(title: "Session Preferences") {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                Stepper(
                    value: $viewModel.availableMinutes,
                    in: 10...120,
                    step: 5,
                    onEditingChanged: { ended in
                        if ended { Task { await viewModel.refresh() } }
                    }
                ) {
                    HStack {
                        Label("Available Time", systemImage: "timer")
                            .font(FitnessTypography.subtitle)
                            .foregroundStyle(FitnessTheme.primaryText)
                        Spacer()
                        Text("\(viewModel.availableMinutes) min")
                            .font(FitnessTypography.sectionTitle)
                            .foregroundStyle(planAccentColor)
                    }
                }

                Picker("Intensity", selection: $viewModel.preferredIntensity) {
                    ForEach(WorkoutIntensity.allCases, id: \.self) { i in
                        Text(i.rawValue.capitalized).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.preferredIntensity) { _ in
                    Task { await viewModel.refresh() }
                }
            }
        }
    }

    // MARK: - Exercise Plan Card

    private func exercisePlanCard(_ plan: WorkoutPlan) -> some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("AI-MATCHED WORKOUT", systemImage: "sparkles")
                            .font(FitnessTypography.tiny)
                            .foregroundStyle(FitnessTheme.accent)
                            .tracking(1)
                        Text(plan.title)
                            .font(FitnessTypography.sectionTitle)
                            .foregroundStyle(FitnessTheme.primaryText)
                    }
                    Spacer()
                }

                HStack(spacing: FitnessSpacing.small) {
                    MetricBadge(systemImage: "timer", text: "\(plan.durationMinutes) min")
                    MetricBadge(systemImage: "flame.fill", text: "\(Int(plan.estimatedCalories)) kcal", tint: FitnessTheme.energy)
                    MetricBadge(systemImage: "bolt", text: plan.intensity.rawValue.capitalized, tint: planAccentColor)
                }

                Text(plan.rationale)
                    .font(FitnessTypography.body)
                    .foregroundStyle(FitnessTheme.secondaryText)

                Divider().background(FitnessTheme.surfaceStroke)

                ForEach(plan.exercises) { exercise in
                    exerciseRow(exercise)
                }

                if plan.sourceProvider != "Built-in" {
                    Text("Exercises by \(plan.sourceProvider)")
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(FitnessTheme.tertiaryText)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: ExerciseBlock) -> some View {
        VStack(alignment: .leading, spacing: FitnessSpacing.small) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(planAccentColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(planAccentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(FitnessTypography.subtitle)
                        .foregroundStyle(FitnessTheme.primaryText)
                    if let sets = exercise.sets, let reps = exercise.reps {
                        Text("\(sets) sets × \(reps) reps")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }
                }
                Spacer()
                MetricBadge(systemImage: "timer", text: "\(exercise.durationMinutes) min")
            }

            Text(exercise.instructions)
                .font(FitnessTypography.caption)
                .foregroundStyle(FitnessTheme.secondaryText)
                .lineLimit(3)

            if let note = exercise.safetyNote {
                Label(note, systemImage: "checkmark.shield")
                    .font(FitnessTypography.tiny)
                    .foregroundStyle(FitnessTheme.success)
            }

            Divider().background(FitnessTheme.surfaceStroke)
        }
        .accessibilityElement(children: .combine)
    }

    private func safetyCard(_ notes: [String]) -> some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.small) {
                Label("Safety Notes", systemImage: "exclamationmark.shield")
                    .font(FitnessTypography.cardTitle)
                    .foregroundStyle(FitnessTheme.caution)
                ForEach(notes, id: \.self) { note in
                    Label(note, systemImage: "triangle")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.caution)
                }
            }
        }
    }

    private func previewBanner(_ message: String) -> some View {
        HStack(spacing: FitnessSpacing.small) {
            Image(systemName: "info.circle.fill").foregroundStyle(FitnessTheme.caution)
            Text(message).font(FitnessTypography.caption).foregroundStyle(FitnessTheme.secondaryText)
        }
        .padding(FitnessSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(FitnessTheme.caution.opacity(0.10)))
    }

    // MARK: - Computed

    private var planAccentColor: Color {
        switch goalType {
        case .loseFat:     return FitnessTheme.energy
        case .buildMuscle: return FitnessTheme.strength
        case .athletic:    return FitnessTheme.purple
        case .maintain:    return FitnessTheme.accent
        }
    }

    private var planGradient: LinearGradient {
        switch goalType {
        case .loseFat:     return FitnessTheme.energyGradient
        case .buildMuscle: return FitnessTheme.strengthGradient
        case .athletic:    return FitnessTheme.goalGradient
        case .maintain:    return FitnessTheme.accentGradient
        }
    }

    private func refresh() { Task { await viewModel.refresh() } }
}
