import Foundation

// MARK: - Body Goal Type

public enum BodyGoalType: String, Codable, CaseIterable, Sendable {
    case loseFat = "Lose Fat"
    case buildMuscle = "Build Muscle"
    case athletic = "Athletic"
    case maintain = "Stay Fit"

    public var systemImage: String {
        switch self {
        case .loseFat: return "flame.fill"
        case .buildMuscle: return "figure.strengthtraining.traditional"
        case .athletic: return "bolt.fill"
        case .maintain: return "heart.fill"
        }
    }

    public var tagline: String {
        switch self {
        case .loseFat: return "Burn fat & reveal your physique"
        case .buildMuscle: return "Pack on lean muscle mass"
        case .athletic: return "Maximize speed, power & endurance"
        case .maintain: return "Stay consistent & healthy"
        }
    }

    // Training split descriptors used by training plan generator
    public var splitLabel: String {
        switch self {
        case .loseFat: return "Cardio + HIIT"
        case .buildMuscle: return "Strength Split"
        case .athletic: return "Performance"
        case .maintain: return "Full Body"
        }
    }
}

// MARK: - Activity Level

public enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case sedentary = "Sedentary"
    case light = "Lightly Active"
    case moderate = "Moderately Active"
    case active = "Very Active"
    case extreme = "Athlete"

    public var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .extreme: return 1.9
        }
    }

    public var shortLabel: String {
        switch self {
        case .sedentary: return "Mostly sitting"
        case .light: return "1–2× per week"
        case .moderate: return "3–5× per week"
        case .active: return "6–7× per week"
        case .extreme: return "Twice daily"
        }
    }

    public var systemImage: String {
        switch self {
        case .sedentary: return "moon.zzz.fill"
        case .light: return "figure.walk"
        case .moderate: return "figure.run"
        case .active: return "bolt.fill"
        case .extreme: return "flame.fill"
        }
    }
}

// MARK: - Body Profile

public struct BodyProfile: Codable, Sendable, Equatable {
    public var heightCm: Double
    public var weightKg: Double
    public var age: Int
    public var isMale: Bool
    public var activityLevel: ActivityLevel
    public var shoulderWidthCm: Double?

    public init(
        heightCm: Double = 170,
        weightKg: Double = 70,
        age: Int = 25,
        isMale: Bool = true,
        activityLevel: ActivityLevel = .moderate,
        shoulderWidthCm: Double? = nil
    ) {
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.age = age
        self.isMale = isMale
        self.activityLevel = activityLevel
        self.shoulderWidthCm = shoulderWidthCm
    }

    // Mifflin-St Jeor BMR
    public var bmr: Double {
        isMale
            ? (10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5)
            : (10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161)
    }

    public var tdee: Double { bmr * activityLevel.multiplier }

    public var bmi: Double {
        let h = heightCm / 100
        return weightKg / (h * h)
    }

    public var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    // Macros (goal-adjusted below in BodyGoal)
    public var dailyProteinGrams: Double { weightKg * 1.8 }
    public var dailyCarbsGrams: Double { (tdee * 0.45) / 4 }
    public var dailyFatsGrams: Double { (tdee * 0.25) / 9 }
}

// MARK: - Body Goal

public struct BodyGoal: Codable, Sendable, Equatable {
    public var goalType: BodyGoalType
    public var durationMonths: Int
    public var targetWeightKg: Double?
    public var startDate: Date

    public init(
        goalType: BodyGoalType = .buildMuscle,
        durationMonths: Int = 3,
        targetWeightKg: Double? = nil,
        startDate: Date = Date()
    ) {
        self.goalType = goalType
        self.durationMonths = durationMonths
        self.targetWeightKg = targetWeightKg
        self.startDate = startDate
    }

    public var totalDays: Int { durationMonths * 30 }

    public var currentDay: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
        return max(1, min(totalDays, days + 1))
    }

    public var progressRatio: Double {
        guard totalDays > 0 else { return 0 }
        return Double(currentDay) / Double(totalDays)
    }

    public var endDate: Date {
        Calendar.current.date(byAdding: .month, value: durationMonths, to: startDate) ?? startDate
    }

    public var isActive: Bool { Date() <= endDate }

    public var daysRemaining: Int { max(0, totalDays - currentDay) }
}

// MARK: - Nutrition Meals

public struct MealSuggestion: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let proteinGrams: Int
    public let calories: Int
    public let prepMinutes: Int
    public let mealType: MealType
    public let emoji: String

    public enum MealType: String, Sendable {
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snack = "Snack"
    }

    public init(id: String, name: String, proteinGrams: Int, calories: Int, prepMinutes: Int, mealType: MealType, emoji: String) {
        self.id = id
        self.name = name
        self.proteinGrams = proteinGrams
        self.calories = calories
        self.prepMinutes = prepMinutes
        self.mealType = mealType
        self.emoji = emoji
    }
}

public extension MealSuggestion {
    static func suggestions(for goalType: BodyGoalType) -> [MealSuggestion] {
        switch goalType {
        case .loseFat:
            return [
                MealSuggestion(id: "lf1", name: "Grilled Chicken Breast", proteinGrams: 32, calories: 165, prepMinutes: 20, mealType: .lunch, emoji: "🍗"),
                MealSuggestion(id: "lf2", name: "Egg White Omelette", proteinGrams: 25, calories: 120, prepMinutes: 10, mealType: .breakfast, emoji: "🥚"),
                MealSuggestion(id: "lf3", name: "Greek Yogurt Bowl", proteinGrams: 20, calories: 180, prepMinutes: 3, mealType: .snack, emoji: "🥣"),
                MealSuggestion(id: "lf4", name: "Tuna & Spinach Salad", proteinGrams: 28, calories: 200, prepMinutes: 8, mealType: .lunch, emoji: "🥗"),
                MealSuggestion(id: "lf5", name: "Baked Salmon & Veggies", proteinGrams: 36, calories: 280, prepMinutes: 25, mealType: .dinner, emoji: "🐟"),
            ]
        case .buildMuscle:
            return [
                MealSuggestion(id: "bm1", name: "Chicken Rice Power Bowl", proteinGrams: 48, calories: 580, prepMinutes: 20, mealType: .lunch, emoji: "🍱"),
                MealSuggestion(id: "bm2", name: "Steak & Sweet Potato", proteinGrams: 50, calories: 640, prepMinutes: 25, mealType: .dinner, emoji: "🥩"),
                MealSuggestion(id: "bm3", name: "Protein Oats & Banana", proteinGrams: 28, calories: 420, prepMinutes: 5, mealType: .breakfast, emoji: "🥞"),
                MealSuggestion(id: "bm4", name: "Ground Turkey Pasta", proteinGrams: 42, calories: 600, prepMinutes: 20, mealType: .dinner, emoji: "🍝"),
                MealSuggestion(id: "bm5", name: "Cottage Cheese & Berries", proteinGrams: 22, calories: 200, prepMinutes: 2, mealType: .snack, emoji: "🫐"),
            ]
        case .athletic:
            return [
                MealSuggestion(id: "ath1", name: "Pre-Workout Oatmeal", proteinGrams: 18, calories: 380, prepMinutes: 5, mealType: .breakfast, emoji: "🥣"),
                MealSuggestion(id: "ath2", name: "Chicken Avocado Toast", proteinGrams: 35, calories: 450, prepMinutes: 10, mealType: .lunch, emoji: "🥑"),
                MealSuggestion(id: "ath3", name: "Energy Smoothie", proteinGrams: 24, calories: 320, prepMinutes: 5, mealType: .snack, emoji: "🥤"),
                MealSuggestion(id: "ath4", name: "Pasta with Meat Sauce", proteinGrams: 38, calories: 580, prepMinutes: 25, mealType: .dinner, emoji: "🍝"),
                MealSuggestion(id: "ath5", name: "Rice Cakes & Peanut Butter", proteinGrams: 12, calories: 240, prepMinutes: 3, mealType: .snack, emoji: "🥜"),
            ]
        case .maintain:
            return [
                MealSuggestion(id: "mnt1", name: "Smoothie Bowl", proteinGrams: 18, calories: 300, prepMinutes: 8, mealType: .breakfast, emoji: "🍓"),
                MealSuggestion(id: "mnt2", name: "Lentil & Veggie Soup", proteinGrams: 16, calories: 230, prepMinutes: 20, mealType: .lunch, emoji: "🥣"),
                MealSuggestion(id: "mnt3", name: "Quinoa Salad", proteinGrams: 14, calories: 280, prepMinutes: 10, mealType: .lunch, emoji: "🥗"),
                MealSuggestion(id: "mnt4", name: "Baked Salmon", proteinGrams: 35, calories: 350, prepMinutes: 20, mealType: .dinner, emoji: "🐟"),
                MealSuggestion(id: "mnt5", name: "Hard Boiled Eggs", proteinGrams: 12, calories: 140, prepMinutes: 12, mealType: .snack, emoji: "🥚"),
            ]
        }
    }
}

// MARK: - Training Plan

public struct TrainingDay: Identifiable, Sendable {
    public let id: Int  // day number (1-based)
    public let sessionType: SessionType
    public let title: String
    public let focusArea: String

    public enum SessionType: Sendable {
        case workout(intensity: String)
        case rest
        case active  // active recovery / light movement
    }

    public var isRest: Bool {
        if case .rest = sessionType { return true }
        return false
    }

    public var sessionLabel: String {
        switch sessionType {
        case .workout(let intensity): return intensity
        case .rest: return "Rest"
        case .active: return "Active Recovery"
        }
    }
}

public extension TrainingDay {
    static func weekPlan(for goalType: BodyGoalType, startingFromDay day: Int) -> [TrainingDay] {
        // Generate 7-day window centered on today (3 past + today + 3 future)
        let startDay = max(1, day - 3)
        var days: [TrainingDay] = []

        for d in startDay...(startDay + 6) {
            days.append(TrainingDay.day(for: goalType, day: d))
        }
        return days
    }

    static func day(for goalType: BodyGoalType, day: Int) -> TrainingDay {
        let cycle = (day - 1) % 7  // 0-6

        switch goalType {
        case .loseFat:
            switch cycle {
            case 0: return TrainingDay(id: day, sessionType: .workout(intensity: "HIIT"), title: "Fat Burn HIIT", focusArea: "Full Body")
            case 1: return TrainingDay(id: day, sessionType: .workout(intensity: "Moderate"), title: "Steady Cardio", focusArea: "Endurance")
            case 2: return TrainingDay(id: day, sessionType: .workout(intensity: "High"), title: "Circuit Training", focusArea: "Full Body")
            case 3: return TrainingDay(id: day, sessionType: .active, title: "Active Recovery", focusArea: "Flexibility")
            case 4: return TrainingDay(id: day, sessionType: .workout(intensity: "HIIT"), title: "Tabata Intervals", focusArea: "Cardio")
            case 5: return TrainingDay(id: day, sessionType: .workout(intensity: "Moderate"), title: "Strength + Cardio", focusArea: "Full Body")
            default: return TrainingDay(id: day, sessionType: .rest, title: "Rest Day", focusArea: "Recovery")
            }
        case .buildMuscle:
            switch cycle {
            case 0: return TrainingDay(id: day, sessionType: .workout(intensity: "Heavy"), title: "Push Day", focusArea: "Chest · Shoulders · Triceps")
            case 1: return TrainingDay(id: day, sessionType: .workout(intensity: "Heavy"), title: "Pull Day", focusArea: "Back · Biceps")
            case 2: return TrainingDay(id: day, sessionType: .workout(intensity: "Heavy"), title: "Leg Day", focusArea: "Quads · Hamstrings · Glutes")
            case 3: return TrainingDay(id: day, sessionType: .rest, title: "Rest Day", focusArea: "Recovery")
            case 4: return TrainingDay(id: day, sessionType: .workout(intensity: "Moderate"), title: "Upper Body", focusArea: "Chest · Back · Arms")
            case 5: return TrainingDay(id: day, sessionType: .workout(intensity: "Moderate"), title: "Lower Body", focusArea: "Legs · Core")
            default: return TrainingDay(id: day, sessionType: .active, title: "Active Recovery", focusArea: "Mobility")
            }
        case .athletic:
            switch cycle {
            case 0: return TrainingDay(id: day, sessionType: .workout(intensity: "High"), title: "Speed Work", focusArea: "Sprints & Agility")
            case 1: return TrainingDay(id: day, sessionType: .workout(intensity: "Heavy"), title: "Power Lifting", focusArea: "Compound Lifts")
            case 2: return TrainingDay(id: day, sessionType: .workout(intensity: "Moderate"), title: "Endurance Run", focusArea: "Cardio Base")
            case 3: return TrainingDay(id: day, sessionType: .active, title: "Mobility Work", focusArea: "Flexibility")
            case 4: return TrainingDay(id: day, sessionType: .workout(intensity: "High"), title: "Plyometrics", focusArea: "Explosive Power")
            case 5: return TrainingDay(id: day, sessionType: .workout(intensity: "Moderate"), title: "Sport Skills", focusArea: "Coordination")
            default: return TrainingDay(id: day, sessionType: .rest, title: "Rest Day", focusArea: "Recovery")
            }
        case .maintain:
            switch cycle {
            case 0: return TrainingDay(id: day, sessionType: .workout(intensity: "Moderate"), title: "Full Body Workout", focusArea: "All Muscles")
            case 1: return TrainingDay(id: day, sessionType: .active, title: "Yoga / Stretch", focusArea: "Flexibility")
            case 2: return TrainingDay(id: day, sessionType: .workout(intensity: "Moderate"), title: "Cardio Session", focusArea: "Heart Health")
            case 3: return TrainingDay(id: day, sessionType: .rest, title: "Rest Day", focusArea: "Recovery")
            case 4: return TrainingDay(id: day, sessionType: .workout(intensity: "Moderate"), title: "Strength Circuit", focusArea: "Full Body")
            case 5: return TrainingDay(id: day, sessionType: .active, title: "Light Walk / Swim", focusArea: "Active Recovery")
            default: return TrainingDay(id: day, sessionType: .rest, title: "Rest Day", focusArea: "Recovery")
            }
        }
    }
}
