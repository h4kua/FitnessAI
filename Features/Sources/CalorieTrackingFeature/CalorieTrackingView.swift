#if canImport(Core)
import Core
#endif
#if canImport(DesignSystem)
import DesignSystem
#endif
import SwiftUI

public struct CalorieTrackingView: View {
    @ObservedObject private var viewModel: CalorieTrackingViewModel

    // Body profile (shared via UserDefaults)
    @AppStorage("profile.heightCm")    private var heightCm: Double = 170
    @AppStorage("profile.weightKg")    private var weightKg: Double = 70
    @AppStorage("profile.age")         private var age: Int = 25
    @AppStorage("profile.isMale")      private var isMale: Bool = true
    @AppStorage("profile.activityLevel") private var activityLevelRaw: String = ActivityLevel.moderate.rawValue
    @AppStorage("goal.type")           private var goalTypeRaw: String = BodyGoalType.buildMuscle.rawValue

    // Water tracker
    @State private var waterGlasses: Int = 0

    private var bodyProfile: BodyProfile {
        BodyProfile(heightCm: heightCm, weightKg: weightKg, age: age, isMale: isMale,
                    activityLevel: ActivityLevel(rawValue: activityLevelRaw) ?? .moderate)
    }

    private var goalType: BodyGoalType { BodyGoalType(rawValue: goalTypeRaw) ?? .buildMuscle }
    private var meals: [MealSuggestion] { MealSuggestion.suggestions(for: goalType) }

    public init(viewModel: CalorieTrackingViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FitnessSpacing.medium) {
                    header

                    if let msg = viewModel.healthStatusMessage { previewBanner(msg) }

                    switch viewModel.loadState {
                    case .idle, .loading:
                        ScreenStateCard(
                            title: "Loading nutrition data",
                            message: "Syncing your calorie progress from Apple Health.",
                            imageSystemName: "fork.knife"
                        )
                    case .failed(let msg):
                        ScreenStateCard(
                            title: "Calorie data unavailable",
                            message: msg,
                            imageSystemName: "exclamationmark.triangle",
                            tint: FitnessTheme.caution
                        )
                    case .loaded:
                        if let summary = viewModel.summary {
                            calorieBalanceCard(summary)
                            macroCard
                            waterCard
                            mealsSection
                            nutritionTipCard
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                Label("NUTRITION", systemImage: "fork.knife")
                    .font(FitnessTypography.tiny)
                    .foregroundStyle(FitnessTheme.energy)
                    .tracking(1.2)
                Text("Today's Fuel")
                    .font(FitnessTypography.hero)
                    .foregroundStyle(FitnessTheme.primaryText)
            }
            Spacer()
            // TDEE chip
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(bodyProfile.tdee))")
                    .font(FitnessTypography.sectionTitle)
                    .foregroundStyle(FitnessTheme.primaryText)
                Text("kcal target")
                    .font(FitnessTypography.tiny)
                    .foregroundStyle(FitnessTheme.secondaryText)
            }
        }
        .padding(.top, FitnessSpacing.medium)
    }

    // MARK: - Calorie Balance Card

    private func calorieBalanceCard(_ summary: CalorieSummary) -> some View {
        GradientCard(gradient: FitnessTheme.energyGradient) {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                Label("CALORIE BALANCE", systemImage: "flame.fill")
                    .font(FitnessTypography.tiny)
                    .foregroundStyle(.black.opacity(0.60))
                    .tracking(1)

                HStack(alignment: .firstTextBaseline, spacing: FitnessSpacing.xSmall) {
                    Text("\(Int(summary.activeEnergyBurned))")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(.black.opacity(0.90))
                    Text("kcal")
                        .font(FitnessTypography.sectionTitle)
                        .foregroundStyle(.black.opacity(0.70))
                        .padding(.bottom, 4)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.15))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.80))
                            .frame(width: max(12, geo.size.width * summary.completionRatio))
                    }
                }
                .frame(height: 10)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Burned")
                            .font(FitnessTypography.tiny)
                            .foregroundStyle(.black.opacity(0.60))
                        Text("\(Int(summary.activeEnergyBurned)) kcal")
                            .font(FitnessTypography.subtitle)
                            .foregroundStyle(.black.opacity(0.90))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Goal")
                            .font(FitnessTypography.tiny)
                            .foregroundStyle(.black.opacity(0.60))
                        Text("\(Int(summary.goal.activeEnergyGoal)) kcal")
                            .font(FitnessTypography.subtitle)
                            .foregroundStyle(.black.opacity(0.90))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Remaining")
                            .font(FitnessTypography.tiny)
                            .foregroundStyle(.black.opacity(0.60))
                        Text("\(Int(max(0, summary.remainingEnergy))) kcal")
                            .font(FitnessTypography.subtitle)
                            .foregroundStyle(.black.opacity(0.90))
                    }
                }
            }
        }
    }

    // MARK: - Macro Card

    private var macroCard: some View {
        FitnessCard(title: "Daily Macro Targets") {
            VStack(spacing: FitnessSpacing.medium) {
                macroRow(
                    label: "Protein",
                    value: Int(bodyProfile.dailyProteinGrams),
                    unit: "g",
                    tint: FitnessTheme.energy,
                    icon: "bolt.heart.fill",
                    progress: 0.45,
                    note: "For \(goalType == .loseFat ? "muscle preservation" : "muscle building")"
                )
                Divider().background(FitnessTheme.surfaceStroke)
                macroRow(
                    label: "Carbs",
                    value: Int(bodyProfile.dailyCarbsGrams),
                    unit: "g",
                    tint: FitnessTheme.strength,
                    icon: "bolt.fill",
                    progress: 0.55,
                    note: "Primary energy source"
                )
                Divider().background(FitnessTheme.surfaceStroke)
                macroRow(
                    label: "Fats",
                    value: Int(bodyProfile.dailyFatsGrams),
                    unit: "g",
                    tint: FitnessTheme.purple,
                    icon: "drop.fill",
                    progress: 0.35,
                    note: "Hormones & cell health"
                )
            }
        }
    }

    private func macroRow(label: String, value: Int, unit: String, tint: Color, icon: String, progress: Double, note: String) -> some View {
        VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
            HStack {
                Label(label, systemImage: icon)
                    .font(FitnessTypography.subtitle)
                    .foregroundStyle(tint)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(value)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(FitnessTheme.primaryText)
                    Text(unit)
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(FitnessTheme.progressTrack)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint)
                        .frame(width: geo.size.width * progress)
                        .shadow(color: tint.opacity(0.4), radius: 4)
                }
            }
            .frame(height: 6)

            Text(note)
                .font(FitnessTypography.tiny)
                .foregroundStyle(FitnessTheme.tertiaryText)
        }
    }

    // MARK: - Water Card

    private var waterCard: some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                HStack {
                    Label("WATER INTAKE", systemImage: "drop.fill")
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(FitnessTheme.strength)
                        .tracking(1)
                    Spacer()
                    Text("\(waterGlasses) / 8 glasses")
                        .font(FitnessTypography.caption)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }

                HStack(spacing: FitnessSpacing.small) {
                    ForEach(0..<8, id: \.self) { i in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                waterGlasses = i < waterGlasses ? i : i + 1
                            }
                        } label: {
                            Image(systemName: i < waterGlasses ? "drop.fill" : "drop")
                                .font(.system(size: 22))
                                .foregroundStyle(i < waterGlasses ? FitnessTheme.strength : FitnessTheme.surface3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Text(waterGlasses == 0
                     ? "Tap drops to track your water intake 💧"
                     : waterGlasses < 4
                         ? "Good start! Keep drinking to stay hydrated."
                         : waterGlasses < 7
                             ? "Halfway there — keep it up! 💪"
                             : "Excellent! You're fully hydrated today! 🎉")
                    .font(FitnessTypography.caption)
                    .foregroundStyle(FitnessTheme.secondaryText)
            }
        }
    }

    // MARK: - Meals Section

    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HIGH-PROTEIN MEALS")
                        .font(FitnessTypography.tiny)
                        .foregroundStyle(FitnessTheme.secondaryText)
                        .tracking(1.2)
                    Text("For \(goalType.rawValue)")
                        .font(FitnessTypography.cardTitle)
                        .foregroundStyle(FitnessTheme.primaryText)
                }
                Spacer()
            }

            ForEach(meals) { meal in
                mealCard(meal)
            }
        }
    }

    private func mealCard(_ meal: MealSuggestion) -> some View {
        ElevatedCard {
            HStack(spacing: FitnessSpacing.medium) {
                Text(meal.emoji)
                    .font(.system(size: 36))
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(FitnessTheme.surface3)
                    )

                VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                    HStack {
                        Text(meal.name)
                            .font(FitnessTypography.subtitle)
                            .foregroundStyle(FitnessTheme.primaryText)
                        Spacer()
                        Text(meal.mealType.rawValue)
                            .font(FitnessTypography.tiny)
                            .foregroundStyle(FitnessTheme.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(FitnessTheme.surface3))
                    }

                    HStack(spacing: FitnessSpacing.medium) {
                        Label("\(meal.proteinGrams)g protein", systemImage: "bolt.fill")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.energy)
                        Label("\(meal.calories) kcal", systemImage: "flame")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                        Label("\(meal.prepMinutes) min", systemImage: "timer")
                            .font(FitnessTypography.caption)
                            .foregroundStyle(FitnessTheme.secondaryText)
                    }
                }
            }
        }
    }

    // MARK: - Nutrition Tip

    private var nutritionTipCard: some View {
        FitnessCard {
            HStack(alignment: .top, spacing: FitnessSpacing.medium) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(FitnessTheme.success)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(FitnessTheme.successSoft)
                    )

                VStack(alignment: .leading, spacing: FitnessSpacing.xSmall) {
                    Text("Nutrition Tip")
                        .font(FitnessTypography.subtitle)
                        .foregroundStyle(FitnessTheme.primaryText)
                    Text(nutritionTip)
                        .font(FitnessTypography.body)
                        .foregroundStyle(FitnessTheme.secondaryText)
                }
            }
        }
    }

    private var nutritionTip: String {
        switch goalType {
        case .loseFat:    return "Eat protein first at each meal — it increases satiety hormones and reduces overall intake by 15–20%."
        case .buildMuscle: return "Consume 40g of protein within 30 min post-workout to maximise muscle protein synthesis."
        case .athletic:   return "Carb-load the night before high-intensity sessions. Complex carbs + protein = optimal fuel + recovery."
        case .maintain:   return "Eating slowly and mindfully helps you recognise satiety signals earlier, reducing overeating by up to 20%."
        }
    }

    // MARK: - Preview Banner

    private func previewBanner(_ message: String) -> some View {
        HStack(spacing: FitnessSpacing.small) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(FitnessTheme.caution)
            Text(message)
                .font(FitnessTypography.caption)
                .foregroundStyle(FitnessTheme.secondaryText)
        }
        .padding(FitnessSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(FitnessTheme.caution.opacity(0.10))
        )
    }
}
