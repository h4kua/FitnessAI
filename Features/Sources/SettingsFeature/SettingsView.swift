#if canImport(Core)
import Core
#endif
#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

public struct SettingsView: View {
    @ObservedObject private var viewModel: SettingsViewModel
    @State private var showingEditProfile = false
    @State private var showingEditGoal = false

    public init(viewModel: SettingsViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FitnessSpacing.medium) {
                    profileHeader
                    bodyStatsRow
                    goalSection
                    appSettingsCard
                    aboutCard
                    signOutButton
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
            .sheet(isPresented: $showingEditProfile) {
                EditProfileSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditGoal) {
                EditGoalSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        GradientCard(gradient: goalGradient) {
            HStack(spacing: FitnessSpacing.medium) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.20))
                        .frame(width: 64, height: 64)
                    Text(avatarInitials)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                    Text(viewModel.bodyGoal.goalType.rawValue)
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(.black.opacity(0.60))
                        .tracking(1)
                    Text(displayName)
                        .font(FitnessTypography.sectionTitle)
                        .foregroundStyle(.black.opacity(0.90))
                    Label("Day \(viewModel.bodyGoal.currentDay) of \(viewModel.bodyGoal.totalDays)",
                          systemImage: "calendar")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(.black.opacity(0.65))
                }
                Spacer()
                Button {
                    showingEditProfile = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.black.opacity(0.50))
                }
            }
        }
        .padding(.top, FitnessSpacing.medium)
    }

    // MARK: - Body Stats Row

    private var bodyStatsRow: some View {
        HStack(spacing: FitnessSpacing.small) {
            statCell(
                label: "Height",
                value: String(format: "%.0f", viewModel.heightCm),
                unit: "cm",
                icon: "ruler",
                tint: FitnessTheme.accent
            )
            statCell(
                label: "Weight",
                value: String(format: "%.1f", viewModel.weightKg),
                unit: "kg",
                icon: "scalemass",
                tint: FitnessTheme.energy
            )
            statCell(
                label: "BMI",
                value: String(format: "%.1f", viewModel.bodyProfile.bmi),
                unit: viewModel.bodyProfile.bmiCategory,
                icon: "chart.bar.fill",
                tint: bmiTint
            )
        }
    }

    private func statCell(label: String, value: String, unit: String, icon: String, tint: Color) -> some View {
        VStack(spacing: FitnessSpacing.xSmall) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(FitnessTheme.primaryText)
            Text(unit)
                .font(FitnessTypography.tiny)
                .foregroundStyle(FitnessTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(FitnessTypography.tiny)
                .foregroundStyle(FitnessTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FitnessSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FitnessTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.15), lineWidth: 1)
                )
        )
    }

    // MARK: - Goal Section

    private var goalSection: some View {
        FitnessCard(title: "My Goal") {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                HStack(spacing: FitnessSpacing.medium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(goalTint.opacity(0.20))
                            .frame(width: 48, height: 48)
                        Image(systemName: viewModel.bodyGoal.goalType.systemImage)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(goalTint)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.bodyGoal.goalType.rawValue)
                            .font(FitnessTypography.subtitle)
                            .foregroundStyle(FitnessTheme.primaryText)
                        Text("\(viewModel.bodyGoal.durationMonths)-month program · \(viewModel.bodyGoal.totalDays) days")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }
                    Spacer()
                    Button("Edit") { showingEditGoal = true }
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.accent)
                }

                // Progress
                VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                    HStack {
                        Text("Progress")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                        Spacer()
                        Text("Day \(viewModel.bodyGoal.currentDay) / \(viewModel.bodyGoal.totalDays)")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(FitnessTheme.progressTrack)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(goalTint)
                                .frame(width: max(8, geo.size.width * viewModel.bodyGoal.progressRatio))
                                .shadow(color: goalTint.opacity(0.40), radius: 4)
                        }
                    }
                    .frame(height: 8)

                    Text("\(viewModel.bodyGoal.daysRemaining) days remaining · \(Int(viewModel.bodyGoal.progressRatio * 100))% complete")
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(FitnessTheme.tertiaryText)
                }

                // Activity level row
                HStack {
                    Image(systemName: viewModel.activityLevel.systemImage)
                        .foregroundStyle(FitnessTheme.secondaryText)
                    Text(viewModel.activityLevel.rawValue)
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.secondaryText)
                    Text("·")
                        .foregroundStyle(FitnessTheme.tertiaryText)
                    Text(viewModel.activityLevel.shortLabel)
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.tertiaryText)
                    Spacer()
                    Text("TDEE: \(Int(viewModel.bodyProfile.tdee)) kcal")
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(FitnessTheme.tertiaryText)
                }
            }
        }
    }

    // MARK: - App Settings Card

    private var appSettingsCard: some View {
        FitnessCard(title: "App Settings") {
            VStack(alignment: .leading, spacing: 0) {
                settingsRow {
                    HStack {
                        Label("Daily Calorie Goal", systemImage: "flame.fill")
                            .font(FitnessTypography.body)
                            .foregroundStyle(FitnessTheme.primaryText)
                        Spacer()
                        Stepper(value: calorieBinding, in: 200.0...2000.0, step: 50.0) {
                            EmptyView()
                        }
                        .labelsHidden()
                        Text("\(Int(viewModel.calorieGoal)) kcal")
                            .font(FitnessTypography.subtitle)
                            .foregroundStyle(FitnessTheme.energy)
                            .frame(minWidth: 70, alignment: .trailing)
                    }
                }
                Divider().background(FitnessTheme.surfaceStroke)
                settingsRow {
                    Toggle(isOn: coachingBinding) {
                        Label("Coaching Hints", systemImage: "lightbulb.fill")
                            .font(FitnessTypography.body)
                            .foregroundStyle(FitnessTheme.primaryText)
                    }
                    .tint(FitnessTheme.accent)
                }
                Divider().background(FitnessTheme.surfaceStroke)
                settingsRow {
                    Toggle(isOn: analyticsBinding) {
                        Label("Share Analytics", systemImage: "chart.bar.fill")
                            .font(FitnessTypography.body)
                            .foregroundStyle(FitnessTheme.primaryText)
                    }
                    .tint(FitnessTheme.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.vertical, FitnessSpacing.medium)
    }

    // MARK: - About Card

    private var aboutCard: some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                HStack(spacing: FitnessSpacing.medium) {
                    ZStack {
                        Circle()
                            .fill(FitnessTheme.accentGradient)
                            .frame(width: 44, height: 44)
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black.opacity(0.80))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FitCoach")
                            .font(FitnessTypography.subtitle)
                            .foregroundStyle(FitnessTheme.primaryText)
                        Text("AI-Powered Body Transformation")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }
                }

                HStack(spacing: FitnessSpacing.small) {
                    MetricBadge(systemImage: "brain", text: "Groq AI")
                    MetricBadge(systemImage: "camera.viewfinder", text: "Vision ML", tint: FitnessTheme.strength)
                    MetricBadge(systemImage: "heart.text.square", text: "HealthKit", tint: FitnessTheme.energy)
                }
            }
        }
    }

    // MARK: - Sign Out Button

    @State private var showSignOutConfirm = false

    private var signOutButton: some View {
        Button {
            showSignOutConfirm = true
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                Text("Sign Out")
                    .font(FitnessTypography.subtitle)
            }
            .foregroundStyle(Color(red: 1.0, green: 0.30, blue: 0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, FitnessSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.30, blue: 0.35).opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(red: 1.0, green: 0.30, blue: 0.35).opacity(0.30), lineWidth: 1)
                    )
            )
        }
        .confirmationDialog(
            "Sign out of your account?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                viewModel.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your body profile and goals are saved locally. You can sign back in anytime.")
        }
    }

    // MARK: - Computed

    @AppStorage("profile.displayName") private var displayName: String = ""

    private var avatarInitials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private var goalTint: Color {
        switch viewModel.bodyGoal.goalType {
        case .loseFat:     return FitnessTheme.energy
        case .buildMuscle: return FitnessTheme.strength
        case .athletic:    return FitnessTheme.purple
        case .maintain:    return FitnessTheme.accent
        }
    }

    private var goalGradient: LinearGradient {
        switch viewModel.bodyGoal.goalType {
        case .loseFat:     return FitnessTheme.energyGradient
        case .buildMuscle: return FitnessTheme.strengthGradient
        case .athletic:    return FitnessTheme.goalGradient
        case .maintain:    return FitnessTheme.accentGradient
        }
    }

    private var bmiTint: Color {
        switch viewModel.bodyProfile.bmiCategory {
        case "Normal":      return FitnessTheme.success
        case "Underweight": return FitnessTheme.strength
        case "Overweight":  return FitnessTheme.caution
        default:            return FitnessTheme.energy
        }
    }

    private var analyticsBinding: Binding<Bool> {
        Binding(get: { viewModel.analyticsEnabled },
                set: { v in Task { await viewModel.updateAnalytics(enabled: v) } })
    }
    private var coachingBinding: Binding<Bool> {
        Binding(get: { viewModel.coachingHintsEnabled },
                set: { v in Task { await viewModel.updateCoachingHints(enabled: v) } })
    }
    private var calorieBinding: Binding<Double> {
        Binding(get: { viewModel.calorieGoal },
                set: { v in Task { await viewModel.updateCalorieGoal(v) } })
    }
}

// MARK: - ActivityLevel extension (view helper)

private extension SettingsViewModel {
    var activityLevel: ActivityLevel {
        ActivityLevel(rawValue: activityLevelRaw) ?? .moderate
    }
}

// MARK: - Edit Profile Sheet

struct EditProfileSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 70
    @State private var age: Int = 25
    @State private var isMale: Bool = true
    @State private var activityLevelRaw: String = ActivityLevel.moderate.rawValue

    private var selectedActivity: ActivityLevel { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FitnessSpacing.medium) {
                    sectionHeader("Body Measurements")

                    measurementStepper(label: "Height", value: Binding(get: { heightCm }, set: { heightCm = $0 }),
                                        range: 140...220, step: 1, unit: "cm", tint: FitnessTheme.accent)
                    measurementStepper(label: "Weight", value: Binding(get: { weightKg }, set: { weightKg = $0 }),
                                        range: 30...200, step: 0.5, unit: "kg", tint: FitnessTheme.energy)
                    measurementStepper(label: "Age", value: Binding(get: { Double(age) }, set: { age = Int($0) }),
                                        range: 12...90, step: 1, unit: "yrs", tint: FitnessTheme.strength)

                    // Gender
                    FitnessCard {
                        VStack(alignment: .leading, spacing: FitnessSpacing.small) {
                            Label("Gender", systemImage: "person.fill")
                                .font(FitnessTypography.caption)
                                .foregroundStyle(FitnessTheme.secondaryText)
                            HStack(spacing: FitnessSpacing.small) {
                                genderChip("Male", selected: isMale) { isMale = true }
                                genderChip("Female", selected: !isMale) { isMale = false }
                            }
                        }
                    }

                    sectionHeader("Activity Level")

                    ForEach(ActivityLevel.allCases, id: \.rawValue) { level in
                        activityRow(level)
                    }
                }
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.bottom, FitnessSpacing.xLarge)
            }
            .background(FitnessTheme.background.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FitnessTheme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(FitnessTypography.subtitle)
                        .foregroundStyle(FitnessTheme.accent)
                }
            }
            .onAppear {
                heightCm = viewModel.heightCm
                weightKg = viewModel.weightKg
                age = viewModel.age
                isMale = viewModel.isMale
                activityLevelRaw = viewModel.activityLevelRaw
            }
        }
        .preferredColorScheme(.dark)
    }

    private func measurementStepper(label: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String, tint: Color) -> some View {
        FitnessCard {
            HStack {
                Label(label, systemImage: "ruler")
                    .font(FitnessTypography.subtitle)
                    .foregroundStyle(tint)
                Spacer()
                Stepper(value: value, in: range, step: step) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(step < 1 ? String(format: "%.1f", value.wrappedValue) : String(format: "%.0f", value.wrappedValue))
                            .font(FitnessTypography.sectionTitle)
                            .foregroundStyle(FitnessTheme.primaryText)
                        Text(unit)
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }
                }
            }
        }
    }

    private func genderChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(FitnessTypography.subtitle)
                .foregroundStyle(selected ? .black : FitnessTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FitnessSpacing.small + 2)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? FitnessTheme.accent : FitnessTheme.surface2))
        }
    }

    private func activityRow(_ level: ActivityLevel) -> some View {
        Button { withAnimation { activityLevelRaw = level.rawValue } } label: {
            HStack(spacing: FitnessSpacing.medium) {
                Image(systemName: level.systemImage)
                    .foregroundStyle(selectedActivity == level ? FitnessTheme.accent : FitnessTheme.secondaryText)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue).font(FitnessTypography.subtitle).foregroundStyle(FitnessTheme.primaryText)
                    Text(level.shortLabel).font(FitnessTypography.caption).foregroundStyle(FitnessTheme.secondaryText)
                }
                Spacer()
                if selectedActivity == level {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(FitnessTheme.accent)
                }
            }
            .padding(FitnessSpacing.medium)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(FitnessTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selectedActivity == level ? FitnessTheme.accent.opacity(0.5) : FitnessTheme.surfaceStroke, lineWidth: 1.5)))
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(FitnessTypography.tiny)
            .foregroundStyle(FitnessTheme.secondaryText)
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        viewModel.updateBodyProfile(
            heightCm: heightCm, weightKg: weightKg, age: age, isMale: isMale,
            activityLevel: ActivityLevel(rawValue: activityLevelRaw) ?? .moderate
        )
        dismiss()
    }
}

// MARK: - Edit Goal Sheet

struct EditGoalSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var goalTypeRaw: String = BodyGoalType.buildMuscle.rawValue
    @State private var durationMonths: Int = 3

    private var selectedGoal: BodyGoalType { BodyGoalType(rawValue: goalTypeRaw) ?? .buildMuscle }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FitnessSpacing.medium) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FitnessSpacing.medium) {
                        ForEach(BodyGoalType.allCases, id: \.rawValue) { goal in
                            goalCard(goal)
                        }
                    }

                    FitnessCard(title: "Duration") {
                        VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                            Text("How long do you commit to this goal?")
                                .font(FitnessTypography.body)
                                .foregroundStyle(FitnessTheme.secondaryText)
                            HStack(spacing: FitnessSpacing.small) {
                                ForEach([1, 2, 3, 6, 12], id: \.self) { months in
                                    Button {
                                        withAnimation { durationMonths = months }
                                    } label: {
                                        Text(months == 1 ? "1 mo" : "\(months) mo")
                                            .font(FitnessTypography.caption)
                                            .foregroundStyle(durationMonths == months ? .black : FitnessTheme.secondaryText)
                                            .padding(.horizontal, FitnessSpacing.small + 2)
                                            .padding(.vertical, FitnessSpacing.small)
                                            .background(Capsule()
                                                .fill(durationMonths == months ? FitnessTheme.accent : FitnessTheme.surface2))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.bottom, FitnessSpacing.xLarge)
            }
            .background(FitnessTheme.background.ignoresSafeArea())
            .navigationTitle("Change Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FitnessTheme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") { save() }
                        .font(FitnessTypography.subtitle)
                        .foregroundStyle(FitnessTheme.accent)
                }
            }
            .onAppear {
                goalTypeRaw = viewModel.goalTypeRaw
                durationMonths = viewModel.goalDurationMonths
            }
        }
        .preferredColorScheme(.dark)
    }

    private func goalCard(_ goal: BodyGoalType) -> some View {
        Button { withAnimation { goalTypeRaw = goal.rawValue } } label: {
            VStack(alignment: .leading, spacing: FitnessSpacing.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(goalTint(goal).opacity(0.20))
                        .frame(width: 40, height: 40)
                    Image(systemName: goal.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(goalTint(goal))
                }
                Text(goal.rawValue).font(FitnessTypography.subtitle).foregroundStyle(FitnessTheme.primaryText)
                Text(goal.tagline).font(FitnessTypography.tiny).foregroundStyle(FitnessTheme.secondaryText).lineLimit(2)
            }
            .padding(FitnessSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FitnessTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selectedGoal == goal ? goalTint(goal).opacity(0.60) : FitnessTheme.surfaceStroke, lineWidth: 1.5)))
        }
    }

    private func goalTint(_ goal: BodyGoalType) -> Color {
        switch goal {
        case .loseFat:     return FitnessTheme.energy
        case .buildMuscle: return FitnessTheme.strength
        case .athletic:    return FitnessTheme.purple
        case .maintain:    return FitnessTheme.accent
        }
    }

    private func save() {
        viewModel.updateGoal(type: selectedGoal, durationMonths: durationMonths)
        dismiss()
    }
}
