public enum ExerciseFormStatus: String, Sendable, Equatable, Codable {
    case acceptable
    case excellent
    case needsAttention
    case unavailable
}

/// Typed form feedback label — mirrors the Core ML output contract described in Lesson 10.
/// Rule-based now; a future SquatFormClassifier.mlmodel returns the same labels.
public enum ExerciseFormFeedback: String, Sendable, Equatable, Codable {
    case goodForm        // All checks pass
    case tooShallow      // Knee angle not low enough
    case torsoLean       // Chest leaning too far forward
    case kneeIssue       // Knee alignment / symmetry problem
    case lowConfidence   // Vision confidence too low to give feedback
    case bodyNotVisible  // Required joints not detected
}

/// Movement phase within a rep cycle.
public enum MovementPhase: String, Sendable, Equatable, Codable {
    case standing
    case descending
    case bottom
    case rising
}

public struct ExerciseAnalysis: Sendable, Equatable, Codable {
    public let classification: String?
    public let coachingCue: String
    public let postureConfidence: Double
    public let status: ExerciseFormStatus
    public let detectedExercise: DetectedExercise
    public let repCount: Int
    /// Key joint angles in degrees, used to generate the coaching cue.
    public let jointAngles: [String: Double]
    /// Typed form feedback — compatible with future Core ML output labels.
    public let formFeedback: ExerciseFormFeedback?
    /// Current movement phase in the rep cycle.
    public let movementPhase: MovementPhase?

    public init(
        classification: String?,
        coachingCue: String,
        postureConfidence: Double,
        status: ExerciseFormStatus,
        detectedExercise: DetectedExercise = .unknown,
        repCount: Int = 0,
        jointAngles: [String: Double] = [:],
        formFeedback: ExerciseFormFeedback? = nil,
        movementPhase: MovementPhase? = nil
    ) {
        self.classification = classification
        self.coachingCue = coachingCue
        self.postureConfidence = postureConfidence
        self.status = status
        self.detectedExercise = detectedExercise
        self.repCount = repCount
        self.jointAngles = jointAngles
        self.formFeedback = formFeedback
        self.movementPhase = movementPhase
    }
}
