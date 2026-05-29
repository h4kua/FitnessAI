public enum DetectedExercise: String, Sendable, Equatable, Codable, CaseIterable {
    case squat = "Squat"
    case pushUp = "Push-Up"
    case pullUp = "Pull-Up"
    case jumpingJack = "Jumping Jack"
    case sitUp = "Sit-Up"
    case standing = "Standing"
    case unknown = "Unknown"

    public var coachingPromptHint: String {
        switch self {
        case .squat:
            return "squat form — hip depth, knee tracking, spine alignment"
        case .pushUp:
            return "push-up form — elbow angle, body alignment, shoulder position"
        case .pullUp:
            return "pull-up form — elbow angle, shoulder engagement, chin over bar"
        case .jumpingJack:
            return "jumping jack form — arm height, foot spread, timing"
        case .sitUp:
            return "sit-up form — spinal flexion, neck position, core engagement"
        case .standing, .unknown:
            return "general standing posture and alignment"
        }
    }

    public static var trackableExercises: [DetectedExercise] {
        [.squat, .pushUp, .pullUp, .jumpingJack, .sitUp]
    }

    /// Approximate MET (Metabolic Equivalent of Task) used for calorie estimation.
    public var metFactor: Double {
        switch self {
        case .squat:       return 5.0
        case .pushUp:      return 4.5
        case .pullUp:      return 6.0
        case .jumpingJack: return 7.0
        case .sitUp:       return 3.5
        case .standing:    return 1.5
        case .unknown:     return 3.0
        }
    }
}
