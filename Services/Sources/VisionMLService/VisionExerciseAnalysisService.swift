#if canImport(Core)
import Core
#endif
#if canImport(Infrastructure)
import Infrastructure
#endif
#if canImport(CoreVideo)
import CoreVideo
#endif
#if canImport(Vision)
import Vision
#endif
import Foundation

public actor VisionExerciseAnalysisService: ExerciseAnalysisProviding {
    private let minimumPoseInterval: TimeInterval
    private let logger: AppLogger
    private let classifier: ExercisePoseClassifier
    private let featureExtractor: PoseFeatureExtractor
    private let groqCoaching: GroqCoachingService?
    private var lastPoseDetectionAt: Date?

    // ── ML Action Classifier state ────────────────────────────────────────────
    // Stored as raw primitives so analyze(sample:) can read them without #if guards
    // around the ActionClassifierService type (which lives inside #if Vision+CoreML).
    private var lastMLLabel: String? = nil
    private var lastMLLabelConfidence: Double = 0.0
#if canImport(Vision) && canImport(CoreML)
    private let actionClassifier = ActionClassifierService()
#endif

    // Angle smoothers (one per key joint) — reduce Vision frame noise
    private var leftKneeSmoother  = AngleSmoother(windowSize: 4)
    private var rightKneeSmoother = AngleSmoother(windowSize: 4)
    private var hipSmoother       = AngleSmoother(windowSize: 4)
    private var torsoSmoother     = AngleSmoother(windowSize: 4)

    // Phase state machine (mirrors RepTracker but exposed for feature schema)
    private var currentPhase: MovementPhase = .standing

    public init(
        logger: AppLogger,
        groqCoaching: GroqCoachingService? = nil,
        minimumPoseInterval: TimeInterval = 0.10   // 10 fps — fast enough to catch rep peaks
    ) {
        self.logger = logger
        self.groqCoaching = groqCoaching
        self.classifier = ExercisePoseClassifier()
        self.featureExtractor = PoseFeatureExtractor()
        self.minimumPoseInterval = minimumPoseInterval
    }

    // MARK: - analyze(sample:)

    public func analyze(sample: BodyPoseSample) async throws -> ExerciseAnalysis {
        let meanConf = sample.meanConfidence
        let rawAngles = classifier.extractAngles(from: sample.jointPositions)
        let rawPositions = sample.jointPositions      // forwarded to ExerciseAnalysis for skeleton overlay

        // ── Step 1: Classify exercise ─────────────────────────────────────────
        // MyActionClassifier labels for squat:
        //   "squat_correct"     – good form, full depth
        //   "squat_too_shallow" – insufficient depth
        //   "squat_torse_lean"  – excessive forward lean  (class name typo in training data)
        //
        // Use the ML model when it is confident (≥ 0.55) on any squat class.
        // Fall back to the rule-based ExercisePoseClassifier for all other exercises
        // (push-up, jumping jack, etc.) which the model was not trained on.
        let isMLSquatClass =
            lastMLLabelConfidence >= 0.55 &&
            (lastMLLabel == "squat_correct" ||
             lastMLLabel == "squat_too_shallow" ||
             lastMLLabel == "squat_torse_lean")

        var (exercise, exerciseConfidence) = classifier.classify(sample: sample)
        if isMLSquatClass {
            exercise = .squat
            exerciseConfidence = lastMLLabelConfidence
        }

        // Extract structured features and update smoothers
        var features = featureExtractor.extract(from: sample, phase: currentPhase)
        if let f = features {
            let smoothedLeftKnee  = leftKneeSmoother.add(f.leftKneeAngle)
            let smoothedRightKnee = rightKneeSmoother.add(f.rightKneeAngle)
            let smoothedHip       = hipSmoother.add(f.hipAngle)
            let smoothedTorso     = torsoSmoother.add(f.torsoLean)
            features = PoseFeatures(
                leftKneeAngle: smoothedLeftKnee,
                rightKneeAngle: smoothedRightKnee,
                hipAngle: smoothedHip,
                torsoLean: smoothedTorso,
                minJointConfidence: f.minJointConfidence,
                phase: f.phase,
                kneeAsymmetry: abs(smoothedLeftKnee - smoothedRightKnee)
            )
        }

        // Update movement phase
        if let f = features {
            currentPhase = updatedPhase(
                currentPhase: currentPhase,
                avgKneeAngle: (f.leftKneeAngle + f.rightKneeAngle) / 2,
                exercise: exercise
            )
        }

        // ── Step 2: Form feedback ─────────────────────────────────────────────
        // When the ML model is confident on a squat class, its label IS the form
        // assessment — use it directly.  For all other cases (other exercises,
        // low ML confidence, or model not available) use the rule-based engine.
        let (formFeedback, cueOverride): (ExerciseFormFeedback?, String?)
        if isMLSquatClass, let mlFb = mlSquatFormFeedback(lastMLLabel) {
            formFeedback = mlFb
            cueOverride = mlSquatCue(mlFb)
        } else {
            (formFeedback, cueOverride) = ruleBasedFeedback(
                exercise: exercise,
                features: features,
                sampleConfidence: meanConf
            )
        }

        // Coaching cue — rule-based ONLY in the camera hot-path.
        // Groq requires a network round-trip (8 s timeout) which would freeze
        // every frame when offline. The rule engine gives immediate, descriptive
        // cues that work on-device without any internet connection.
        // Groq is still used in the AI Coach Chat tab for deeper conversations.
        let finalCue = cueOverride ?? defaultCue(for: exercise)

        // Fire-and-forget Groq refresh (non-blocking) — only when online & no critical feedback.
        // The cue won't appear in THIS frame but may appear in a future frame if the
        // cooldown (3 s) and network allow it. This never delays the return value.
        // Snapshot vars → lets so they can be safely captured in Task.detached.
        let snapshotExercise = exercise
        let snapshotConfidence = exerciseConfidence
        if snapshotConfidence >= 0.55,
           formFeedback == .goodForm || formFeedback == nil,
           let coaching = groqCoaching {
            Task.detached(priority: .background) {
                _ = await coaching.coachingCue(
                    for: snapshotExercise,
                    angles: rawAngles,
                    confidence: snapshotConfidence
                )
                // Result intentionally discarded here — future frames use defaultCue;
                // the AI Coach Chat tab is the proper surface for Groq responses.
            }
        }

        // ── Confidence bands ──────────────────────────────────────────────────
        // rawPositions is ALWAYS forwarded so the skeleton overlay shows whatever
        // joints Vision detected, even in dim light.  The user can use the live
        // skeleton to reposition themselves — hiding it when confidence is low is
        // counter-productive.
        //
        // Bands lowered further (0.65/0.40 → 0.50/0.25) to handle indoor / dim
        // lighting common on iPhone X-era devices.
        if meanConf >= 0.50 {
            return ExerciseAnalysis(
                classification: exercise != .unknown ? exercise.rawValue : "Bodyweight Movement",
                coachingCue: finalCue,
                postureConfidence: meanConf,
                status: statusFromFeedback(formFeedback, confidence: exerciseConfidence),
                detectedExercise: exercise,
                jointAngles: rawAngles,
                poseJointPositions: rawPositions,
                formFeedback: formFeedback,
                movementPhase: currentPhase
            )
        }

        if meanConf >= 0.25 {
            return ExerciseAnalysis(
                classification: exercise != .unknown ? exercise.rawValue : "Bodyweight Movement",
                coachingCue: cueOverride ?? finalCue,
                postureConfidence: meanConf,
                status: .acceptable,
                detectedExercise: exercise,
                jointAngles: rawAngles,
                poseJointPositions: rawPositions,   // show partial skeleton
                formFeedback: formFeedback ?? .lowConfidence,
                movementPhase: currentPhase
            )
        }

        // Very low confidence — still pass rawPositions so the skeleton appears
        // and the user knows to step back / improve lighting.
        return ExerciseAnalysis(
            classification: nil,
            coachingCue: "Step back so your full body fills the frame.",
            postureConfidence: meanConf,
            status: .needsAttention,
            detectedExercise: .unknown,
            jointAngles: [:],
            poseJointPositions: rawPositions,   // ← was [:]; now always forwarded
            formFeedback: .bodyNotVisible,
            movementPhase: .standing
        )
    }

#if canImport(Vision) && canImport(CoreVideo)
    /// `isFrontCamera` corrects the Vision orientation so joint coordinates are
    /// right/left consistent regardless of which camera produced the frame.
    public func analyze(
        pixelBuffer: CVPixelBuffer,
        capturedAt: Date = Date(),
        isFrontCamera: Bool = true
    ) async throws -> ExerciseAnalysis {
        do {
            let sample = try await detectPose(in: pixelBuffer, capturedAt: capturedAt, isFrontCamera: isFrontCamera)
            return try await analyze(sample: sample)
        } catch let error as AppError {
            switch error {
            case .dataUnavailable(let message):
                return ExerciseAnalysis(
                    classification: nil,
                    coachingCue: message,
                    postureConfidence: 0,
                    status: .unavailable,
                    formFeedback: .bodyNotVisible
                )
            default:
                throw error
            }
        }
    }
#endif

    // MARK: - Rule Engine (Lesson 10 exact logic)
    // Returns (typed label, user-facing cue string or nil to fall back to Groq/default)

    private func ruleBasedFeedback(
        exercise: DetectedExercise,
        features: PoseFeatures?,
        sampleConfidence: Double
    ) -> (ExerciseFormFeedback?, String?) {

        guard let f = features else {
            return (.bodyNotVisible, "Step back so your full body is visible in the frame.")
        }

        guard f.minJointConfidence >= 0.25 else {
            return (.lowConfidence, "Improve lighting or move closer to the camera.")
        }

        switch exercise {
        case .squat:
            return squatFeedback(f)
        case .pushUp:
            return pushUpFeedback(f)
        case .pullUp, .jumpingJack, .sitUp, .plank:
            // These exercises: if we got here, form is detectable — pass through to default cue
            return (.goodForm, nil)
        case .standing, .unknown:
            return (nil, nil)
        }
    }

    /// Lesson 10 squat rule tree (verbatim):
    /// 1. missing joints → bodyNotVisible
    /// 2. low confidence → lowConfidence
    /// 3. knee angle not low enough → tooShallow
    /// 4. torso lean high → torsoLean
    /// 5. else → goodForm
    private func squatFeedback(_ f: PoseFeatures) -> (ExerciseFormFeedback, String?) {
        let avgKnee = (f.leftKneeAngle + f.rightKneeAngle) / 2

        // Knee symmetry check (> 20° difference = alignment issue)
        if f.kneeAsymmetry > 20 {
            return (.kneeIssue, "Check knee alignment — one side is tracking differently than the other.")
        }

        // Depth check: a proper squat needs knee angle ≤ 110° at the bottom
        // (180° = fully extended, 90° = parallel, < 90° = deep squat)
        if currentPhase == .bottom || currentPhase == .descending {
            if avgKnee > 120 {
                return (.tooShallow, "Go deeper — try to get your thighs parallel to the floor.")
            }
        }

        // Torso lean: > 35° forward lean = chest-fall
        if f.torsoLean > 35 {
            return (.torsoLean, "Keep your chest more upright — engage your core and open your hips.")
        }

        return (.goodForm, nil) // fall through to Groq/default
    }

    private func pushUpFeedback(_ f: PoseFeatures) -> (ExerciseFormFeedback, String?) {
        // For push-up, torso lean > 15° means hips are sagging or piking
        if f.torsoLean > 15 {
            return (.torsoLean, "Keep your body in a straight line — squeeze your glutes and core.")
        }
        return (.goodForm, nil)
    }

    // MARK: - Phase State Machine

    private func updatedPhase(
        currentPhase: MovementPhase,
        avgKneeAngle: Double,
        exercise: DetectedExercise
    ) -> MovementPhase {
        guard exercise == .squat else { return .standing }

        switch currentPhase {
        case .standing:
            return avgKneeAngle < 150 ? .descending : .standing
        case .descending:
            return avgKneeAngle < 105 ? .bottom : (avgKneeAngle > 155 ? .standing : .descending)
        case .bottom:
            return avgKneeAngle > 115 ? .rising : .bottom
        case .rising:
            return avgKneeAngle > 160 ? .standing : .rising
        }
    }

    // MARK: - Helpers

    private func statusFromFeedback(_ feedback: ExerciseFormFeedback?, confidence: Double) -> ExerciseFormStatus {
        switch feedback {
        case .goodForm:                             return .excellent
        case .tooShallow, .torsoLean, .kneeIssue:  return .acceptable
        case .lowConfidence, .bodyNotVisible, nil:  return .needsAttention
        }
    }

    private func defaultCue(for exercise: DetectedExercise) -> String {
        switch exercise {
        case .squat:        return "Good squat position. Keep your chest up and drive through your heels."
        case .pushUp:       return "Push-up detected. Maintain a straight body line from head to heels."
        case .pullUp:       return "Pull-up detected. Drive your elbows down and squeeze your back at the top."
        case .jumpingJack:  return "Jumping jack form looks good. Keep your core engaged."
        case .sitUp:        return "Sit-up detected. Avoid pulling on your neck — let your core do the work."
        case .plank:        return "Plank detected. Keep your hips level and brace your core."
        case .standing:     return "Standing posture is stable. Maintain tempo and bracing."
        case .unknown:      return "Posture is stable. Maintain tempo and bracing."
        }
    }

    // MARK: - ML Action Classifier helpers

    /// Map the raw class label produced by MyActionClassifier to ``ExerciseFormFeedback``.
    ///
    /// | Model label            | Feedback        |
    /// |------------------------|-----------------|
    /// | `squat_correct`        | `.goodForm`     |
    /// | `squat_too_shallow`    | `.tooShallow`   |
    /// | `squat_torse_lean`     | `.torsoLean`    |
    /// | `none` / `others` / — | `nil` (fallback)|
    ///
    /// Note: the class name in the trained model is "squat_torse_lean" (not "torso").
    private func mlSquatFormFeedback(_ label: String?) -> ExerciseFormFeedback? {
        switch label {
        case "squat_correct":     return .goodForm
        case "squat_too_shallow": return .tooShallow
        case "squat_torse_lean":  return .torsoLean
        default:                  return nil
        }
    }

    /// Short, actionable coaching cue for each ML-classified squat form state.
    /// Returns `nil` for `.goodForm` so the caller falls through to `defaultCue`.
    private func mlSquatCue(_ feedback: ExerciseFormFeedback) -> String? {
        switch feedback {
        case .goodForm:
            return nil   // use defaultCue → "Good squat position. Keep your chest up…"
        case .tooShallow:
            return "Lower your hips more — try to get your thighs parallel to the floor."
        case .torsoLean:
            return "Lift your chest and reduce forward lean — keep your core tight."
        case .kneeIssue:
            return "Guide your knees toward your toes — avoid inward collapse."
        case .lowConfidence, .bodyNotVisible:
            return nil
        }
    }
}

// MARK: - Vision Pose Detection

#if canImport(Vision) && canImport(CoreVideo)
public extension VisionExerciseAnalysisService {
    func detectPose(
        in pixelBuffer: CVPixelBuffer,
        capturedAt: Date = Date(),
        isFrontCamera: Bool = true
    ) async throws -> BodyPoseSample {
        guard shouldProcessPoseFrame(capturedAt: capturedAt) else {
            throw AppError.rateLimited("Frame skipped to preserve interactive camera performance.")
        }

        // ── Orientation detection ──────────────────────────────────────────────
        // AVCaptureVideoDataOutput behaviour is inconsistent across iOS versions:
        // • Older iOS / some devices: raw buffer arrives in native LANDSCAPE
        //   (1920×1080 for .high preset) → we must rotate via Vision orientation hint.
        // • Newer iOS / some devices: the output connection's videoOrientation=.portrait
        //   setting causes the buffer to arrive already in PORTRAIT orientation
        //   (1080×1920) → no rotation needed, just handle mirroring.
        //
        // We detect which case we're in by comparing width vs height.
        let bufferWidth  = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        let isLandscapeBuffer = bufferWidth > bufferHeight

        let orientation: CGImagePropertyOrientation
        if isLandscapeBuffer {
            // Native landscape buffer — tell Vision to rotate to portrait
            // Front camera: .leftMirrored (90° CW + horizontal flip)
            // Back camera:  .right        (90° CW)
            orientation = isFrontCamera ? .leftMirrored : .right
        } else {
            // Buffer is already in portrait orientation
            // Front camera preview mirrors horizontally → .upMirrored
            // Back camera is unmirrored           → .up
            orientation = isFrontCamera ? .upMirrored : .up
        }

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        do {
            try handler.perform([request])

            // ── Feed ML sliding window (PDF p. 52-55) ────────────────────────
            // Append this frame's observation (or nil = no body → zero padding).
            // Once the window reaches 60 frames the action classifier produces
            // its first prediction; until then it returns the last known result.
#if canImport(CoreML)
            await actionClassifier.append(request.results?.first)
            if let ml = await actionClassifier.predict() {
                lastMLLabel = ml.label
                lastMLLabelConfidence = ml.confidence
            }
#endif

            guard let observation = request.results?.first else {
                throw AppError.dataUnavailable("No body pose was detected in the current frame.")
            }

            let points = try observation.recognizedPoints(.all)

            var confidences: [String: Double] = [:]
            var positions: [String: PosePoint] = [:]

            for (key, point) in points {
                // Apple Vision uses verbose internal names (e.g. "left_upLeg_joint").
                // Map to the short names expected by ExercisePoseClassifier / PoseFeatureExtractor.
                let rawName = key.rawValue.rawValue
                let name = Self.visionJointMap[rawName] ?? rawName
                confidences[name] = Double(point.confidence)
                // 0.10 threshold picks up more joints in dim/indoor lighting.
                // The feature extractor still checks minJointConfidence separately.
                if point.confidence > 0.10 {
                    positions[name] = PosePoint(x: Double(point.location.x), y: Double(point.location.y))
                }
            }

            logger.info("Body pose detected: \(positions.count) joints mapped (of \(confidences.count) raw keypoints)")
            return BodyPoseSample(capturedAt: capturedAt, jointConfidences: confidences, jointPositions: positions)
        } catch {
            logger.error("Vision request failed: \(error.localizedDescription)")
            throw error
        }
    }
}

private extension VisionExerciseAnalysisService {
    func shouldProcessPoseFrame(capturedAt: Date) -> Bool {
        guard let last = lastPoseDetectionAt else {
            lastPoseDetectionAt = capturedAt
            return true
        }

        guard capturedAt.timeIntervalSince(last) >= minimumPoseInterval else {
            return false
        }

        lastPoseDetectionAt = capturedAt
        return true
    }

    // MARK: - Vision → short-name joint map
    // Apple's VNHumanBodyPoseObservation.JointName.rawValue.rawValue produces
    // verbose strings like "left_upLeg_joint". The classifier and feature extractor
    // use short names. This table bridges the gap.
    static let visionJointMap: [String: String] = [
        // Head
        "nose_2_joint":           "nose",
        "left_eye_2_joint":       "left_eye",
        "right_eye_2_joint":      "right_eye",
        "left_ear_2_joint":       "left_ear",
        "right_ear_2_joint":      "right_ear",
        "neck_1_joint":           "neck",
        "root":                   "root",
        // Shoulders
        "left_shoulder_1_joint":  "left_shoulder",
        "right_shoulder_1_joint": "right_shoulder",
        // Elbows
        "left_forearm_joint":     "left_elbow",
        "right_forearm_joint":    "right_elbow",
        // Wrists
        "left_hand_1_joint":      "left_wrist",
        "right_hand_1_joint":     "right_wrist",
        // Hips
        "left_upLeg_joint":       "left_hip",
        "right_upLeg_joint":      "right_hip",
        // Knees
        "left_leg_joint":         "left_knee",
        "right_leg_joint":        "right_knee",
        // Ankles
        "left_foot_joint":        "left_ankle",
        "right_foot_joint":       "right_ankle"
    ]
}
#endif
