#if canImport(Core)
import Core
#endif
#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

/// Shown as a fullScreenCover from MainTabView when the user has not yet
/// completed body profile setup (onboarding.didComplete == false).
public struct OnboardingView: View {
    @AppStorage("onboarding.didComplete")  private var onboardingDidComplete = false
    @AppStorage("profile.displayName")     private var savedName: String = ""
    @AppStorage("profile.heightCm")        private var heightCm: Double = 170
    @AppStorage("profile.weightKg")        private var weightKg: Double = 70
    @AppStorage("profile.age")             private var age: Int = 25
    @AppStorage("profile.isMale")          private var isMale: Bool = true
    @AppStorage("profile.activityLevel")   private var activityLevelRaw: String = ActivityLevel.moderate.rawValue
    @AppStorage("goal.type")               private var goalTypeRaw: String = BodyGoalType.buildMuscle.rawValue
    @AppStorage("goal.durationMonths")     private var goalDurationMonths: Int = 3
    @AppStorage("goal.startTimestamp")     private var goalStartTimestamp: Double = 0

    @State private var step: Int = 0

    private var selectedActivity: ActivityLevel { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
    private var selectedGoal: BodyGoalType      { BodyGoalType(rawValue: goalTypeRaw) ?? .buildMuscle }
    private let totalSteps = 4

    public init() {}

    public var body: some View {
        ZStack {
            FitnessTheme.background.ignoresSafeArea()

            TabView(selection: $step) {
                bodyPage.tag(0)
                activityPage.tag(1)
                goalPage.tag(2)
                timelinePage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: step)

            // Progress dots
            VStack {
                progressDots.padding(.top, 56)
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Progress

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i == step ? FitnessTheme.accent : FitnessTheme.secondaryText.opacity(0.3))
                    .frame(width: i == step ? 24 : 8, height: 8)
                    .animation(.spring(), value: step)
            }
        }
    }

    // MARK: - Page shell

    private func pageShell<Content: View>(
        emoji: String,
        title: String,
        subtitle: String,
        nextLabel: String = "Continue",
        isLastStep: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FitnessSpacing.large) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(emoji).font(.system(size: 40))
                        Text(title).font(FitnessTypography.hero).foregroundStyle(FitnessTheme.primaryText)
                        Text(subtitle).font(FitnessTypography.body).foregroundStyle(FitnessTheme.secondaryText)
                    }
                    content()
                }
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.top, 100)
                .padding(.bottom, 120)
            }

            // Pinned CTA
            VStack(spacing: 0) {
                Divider().background(FitnessTheme.surface2)
                Button {
                    if isLastStep { completeOnboarding() } else { withAnimation { step += 1 } }
                } label: {
                    Text(isLastStep ? "Start My Journey 🔥" : nextLabel)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity).frame(height: 52)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.horizontal, FitnessSpacing.large)
                .padding(.vertical, FitnessSpacing.medium)
            }
            .background(FitnessTheme.background)
        }
    }

    // MARK: - Body Page

    private var bodyPage: some View {
        pageShell(emoji: "📏", title: "Your Body", subtitle: "We personalise your plan to your measurements.") {
            VStack(spacing: FitnessSpacing.medium) {
                measurementControl(label: "Height", icon: "ruler", tint: FitnessTheme.strength,
                                   value: "\(Int(heightCm)) cm",
                                   decrement: { heightCm = max(140, heightCm - 1) },
                                   increment: { heightCm = min(220, heightCm + 1) })

                measurementControl(label: "Weight", icon: "scalemass", tint: FitnessTheme.energy,
                                   value: "\(Int(weightKg)) kg",
                                   decrement: { weightKg = max(30, weightKg - 0.5) },
                                   increment: { weightKg = min(200, weightKg + 0.5) })

                measurementControl(label: "Age", icon: "calendar", tint: FitnessTheme.purple,
                                   value: "\(age) yrs",
                                   decrement: { age = max(10, age - 1) },
                                   increment: { age = min(100, age + 1) })

                // Gender
                FitnessCard {
                    VStack(alignment: .leading, spacing: FitnessSpacing.small) {
                        Label("Gender", systemImage: "person.2.fill")
                            .font(FitnessTypography.caption).foregroundStyle(FitnessTheme.secondaryText)
                        HStack(spacing: FitnessSpacing.medium) {
                            genderChip(label: "Male",   icon: "figure.stand",    isSelected:  isMale) { isMale = true  }
                            genderChip(label: "Female", icon: "figure.stand.dress", isSelected: !isMale) { isMale = false }
                        }
                    }
                }
            }
        }
    }

    private func measurementControl(
        label: String, icon: String, tint: Color, value: String,
        decrement: @escaping () -> Void, increment: @escaping () -> Void
    ) -> some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.small) {
                Label(label, systemImage: icon)
                    .font(FitnessTypography.caption).foregroundStyle(FitnessTheme.secondaryText)
                HStack {
                    Button(action: decrement) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28)).foregroundStyle(tint)
                    }
                    .frame(maxWidth: .infinity)
                    Text(value)
                        .font(FitnessTypography.cardTitle.bold()).foregroundStyle(FitnessTheme.primaryText)
                        .frame(maxWidth: .infinity)
                    Button(action: increment) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28)).foregroundStyle(tint)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func genderChip(label: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.body)
                Text(label).font(FitnessTypography.sectionTitle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? FitnessTheme.accent.opacity(0.2) : FitnessTheme.surface2)
            .foregroundStyle(isSelected ? FitnessTheme.accent : FitnessTheme.secondaryText)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? FitnessTheme.accent : Color.clear, lineWidth: 1.5))
        }
    }

    // MARK: - Activity Page

    private var activityPage: some View {
        pageShell(emoji: "⚡️", title: "Activity Level", subtitle: "How active are you in daily life?") {
            VStack(spacing: FitnessSpacing.medium) {
                ForEach(ActivityLevel.allCases, id: \.rawValue) { level in
                    activityCard(level)
                }
            }
        }
    }

    private func activityCard(_ level: ActivityLevel) -> some View {
        let isSelected = activityLevelRaw == level.rawValue
        return Button { activityLevelRaw = level.rawValue } label: {
            HStack(spacing: FitnessSpacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? FitnessTheme.accent.opacity(0.2) : FitnessTheme.surface2)
                        .frame(width: 44, height: 44)
                    Image(systemName: level.systemImage)
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? FitnessTheme.accent : FitnessTheme.secondaryText)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.rawValue.capitalized)
                        .font(FitnessTypography.sectionTitle).foregroundStyle(FitnessTheme.primaryText)
                    Text(level.shortLabel)
                        .font(FitnessTypography.tiny).foregroundStyle(FitnessTheme.secondaryText)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? FitnessTheme.accent : FitnessTheme.secondaryText)
            }
            .padding(FitnessSpacing.medium)
            .background(isSelected ? FitnessTheme.accent.opacity(0.08) : FitnessTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? FitnessTheme.accent.opacity(0.4) : Color.clear, lineWidth: 1.5))
        }
    }

    // MARK: - Goal Page

    private var goalPage: some View {
        pageShell(emoji: "🎯", title: "Your Goal", subtitle: "What are you training for?") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: FitnessSpacing.medium) {
                ForEach(BodyGoalType.allCases, id: \.rawValue) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    private func goalCard(_ goal: BodyGoalType) -> some View {
        let isSelected = goalTypeRaw == goal.rawValue
        let tint = goalTint(goal)
        return Button { goalTypeRaw = goal.rawValue } label: {
            VStack(alignment: .leading, spacing: FitnessSpacing.small) {
                Image(systemName: goal.systemImage)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? tint : FitnessTheme.secondaryText)
                Spacer(minLength: 0)
                Text(goal.rawValue.capitalized)
                    .font(FitnessTypography.sectionTitle).foregroundStyle(FitnessTheme.primaryText)
                Text(goal.tagline)
                    .font(FitnessTypography.tiny).foregroundStyle(FitnessTheme.secondaryText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 155, alignment: .topLeading)
            .padding(FitnessSpacing.medium)
            .background(isSelected ? tint.opacity(0.12) : FitnessTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? tint : Color.clear, lineWidth: 1.5))
        }
    }

    private func goalTint(_ goal: BodyGoalType) -> Color {
        switch goal {
        case .loseFat:      return FitnessTheme.energy
        case .buildMuscle:  return FitnessTheme.strength
        case .athletic:     return FitnessTheme.accent
        case .maintain:     return FitnessTheme.purple
        }
    }

    // MARK: - Timeline Page

    private var timelinePage: some View {
        pageShell(emoji: "📅", title: "Your Timeline", subtitle: "How long to reach your goal?", isLastStep: true) {
            VStack(spacing: FitnessSpacing.large) {
                GradientCard(gradient: goalGradient) {
                    VStack(spacing: FitnessSpacing.small) {
                        Text(selectedGoal.rawValue.capitalized)
                            .font(FitnessTypography.cardTitle).foregroundStyle(.white)
                        Text(selectedGoal.tagline)
                            .font(FitnessTypography.caption).foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }

                VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                    Text("Duration").font(FitnessTypography.sectionTitle).foregroundStyle(FitnessTheme.primaryText)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                              spacing: FitnessSpacing.small) {
                        ForEach([1, 2, 3, 4, 6, 12], id: \.self) { months in
                            durationChip(months: months)
                        }
                    }
                }

                // Summary
                FitnessCard {
                    HStack {
                        summaryCell(icon: "calendar", label: "Duration",  value: "\(goalDurationMonths) months")
                        Divider().frame(height: 40)
                        summaryCell(icon: selectedGoal.systemImage, label: "Goal", value: selectedGoal.rawValue.capitalized)
                        Divider().frame(height: 40)
                        summaryCell(icon: "figure.walk", label: "Level", value: selectedActivity.shortLabel)
                    }
                }
            }
        }
    }

    private var goalGradient: LinearGradient {
        switch selectedGoal {
        case .loseFat:      return FitnessTheme.energyGradient
        case .buildMuscle:  return FitnessTheme.strengthGradient
        case .athletic:     return FitnessTheme.accentGradient
        case .maintain:     return FitnessTheme.goalGradient
        }
    }

    private func durationChip(months: Int) -> some View {
        let isSelected = goalDurationMonths == months
        return Button { goalDurationMonths = months } label: {
            Text(months == 1 ? "1 mo" : "\(months) mo")
                .font(FitnessTypography.sectionTitle)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? FitnessTheme.accent.opacity(0.2) : FitnessTheme.surface2)
                .foregroundStyle(isSelected ? FitnessTheme.accent : FitnessTheme.secondaryText)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? FitnessTheme.accent : Color.clear, lineWidth: 1.5))
        }
    }

    private func summaryCell(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.body).foregroundStyle(FitnessTheme.accent)
            Text(value).font(FitnessTypography.sectionTitle).foregroundStyle(FitnessTheme.primaryText)
            Text(label).font(FitnessTypography.tiny).foregroundStyle(FitnessTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Complete

    private func completeOnboarding() {
        goalStartTimestamp = Date().timeIntervalSinceReferenceDate
        onboardingDidComplete = true
    }
}
