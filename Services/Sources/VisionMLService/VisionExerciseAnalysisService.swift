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
        minimumPoseInterval: TimeInterval = 0.2
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
        let (exercise, exerciseConfidence) = classifier.classify(sample: sample)
        let rawAngles = classifier.extractAngles(from: sample.jointPositions)

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

        // Rule-based form feedback (Lesson 10 exact logic)
        let (formFeedback, cueOverride) = ruleBasedFeedback(
            exercise: exercise,
            features: features,
            sampleConfidence: meanConf
        )

        // Ask Groq for a coaching cue if confidence is sufficient and no critical issue
        let groqCue: String?
        if exerciseConfidence >= 0.55,
           formFeedback == .goodForm || formFeedback == nil,
           let coaching = groqCoaching {
            groqCue = await coaching.coachingCue(
                for: exercise,
                angles: rawAngles,
                confidence: exerciseConfidence
            )
        } else {
            groqCue = nil
        }

        let finalCue = cueOverride ?? groqCue ?? defaultCue(for: exercise)

        if meanConf >= 0.8 {
            return ExerciseAnalysis(
                classification: exercise != .unknown ? exercise.rawValue : "Bodyweight Movement",
                coachingCue: finalCue,
                postureConfidence: meanConf,
                status: statusFromFeedback(formFeedback, confidence: exerciseConfidence),
                detectedExercise: exercise,
                jointAngles: rawAngles,
                formFeedback: formFeedback,
                movementPhase: currentPhase
            )
        }

        if meanConf >= 0.55 {
            return ExerciseAnalysis(
                classification: exercise != .unknown ? exercise.rawValue : "Bodyweight Movement",
                coachingCue: cueOverride ?? "Movement is readable. Refine alignment before increasing intensity.",
                postureConfidence: meanConf,
                status: .acceptable,
                detectedExercise: exercise,
                jointAngles: rawAngles,
                formFeedback: formFeedback ?? .lowConfidence,
                movementPhase: currentPhase
            )
        }

        return ExerciseAnalysis(
            classification: nil,
            coachingCue: "Reposition the camera so your full body is visible.",
            postureConfidence: meanConf,
            status: .needsAttention,
            detectedExercise: .unknown,
            jointAngles: [:],
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

        guard f.minJointConfidence >= 0.4 else {
            return (.lowConfidence, "Improve lighting or move the camera for a clearer view.")
        }

        switch exercise {
        case .squat:
            return squatFeedback(f)
        case .pushUp:
            return pushUpFeedback(f)
        case .pullUp, .jumpingJack, .sitUp:
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
        case .standing:     return "Standing posture is stable. Maintain tempo and bracing."
        case .unknown:      return "Posture is stable. Maintain tempo and bracing."
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

        // iPhone captures video in landscape-right natively.
        // For portrait display we tell Vision the correct exif orientation so
        // joint coordinates come out right-way-up and left/right consistent.
        // Front camera: .leftMirrored  (mirrored landscape-left)
        // Back camera:  .right         (landscape-right, unmirrored)
        let orientation: CGImagePropertyOrientation = isFrontCamera ? .leftMirrored : .right

        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])

        do {
            try handler.perform([request])
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
                if point.confidence > 0.3 {
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
        defer { lastPoseDetectionAt = capturedAt }
        guard let last = lastPoseDetectionAt else { return true }
        return capturedAt.timeIntervalSince(last) >= minimumPoseInterval
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
