#if canImport(Vision) && canImport(CoreML)
import CoreML
import Foundation
import Vision
#if canImport(Core)
import Core
#endif

/// Sliding-window action classifier backed by ``MyActionClassifier.mlmodel``.
///
/// Architecture described in the lesson PDF (pages 51-55):
/// ```
/// AVCaptureSession → CMSampleBuffer
///   → VNDetectHumanBodyPoseRequest → VNHumanBodyPoseObservation
///   → 60-frame sliding window  (30 fps × 2 s)
///   → MyActionClassifier (ST-GCN)
///   → label + labelProbabilities
/// ```
///
/// Model I/O (confirmed from .mlmodel header):
/// - Input  `poses`              : MLMultiArray  shape [60, 3, 18]
///     dim 0 → 60 frames
///     dim 1 → x, y, confidence
///     dim 2 → 18 keypoints:
///             nose, neck, right shoulder, right elbow, right wrist,
///             left shoulder, left elbow, left wrist,
///             right hip, right knee, right ankle,
///             left hip, left knee, left ankle,
///             right eye, left eye, right ear, left ear
/// - Output `label`              : String
/// - Output `labelProbabilities` : [String: Double]
/// - Classes: none | others | squat_correct | squat_too_shallow | squat_torse_lean
///
/// Usage (one call per camera frame, from within VisionExerciseAnalysisService):
/// ```swift
/// await actionClassifier.append(observation)   // nil = no body this frame
/// if let ml = await actionClassifier.predict() { ... }
/// ```
public actor ActionClassifierService {

    // MARK: - Constants

    /// 30 fps × 2 s = 60 frames, matching the model's prediction window.
    public static let windowSize = 60

    // MARK: - Prediction result

    public struct ActionPrediction: Sendable {
        /// Raw class label exactly as trained: e.g. "squat_correct"
        public let label: String
        /// Confidence 0.0 – 1.0 for `label`
        public let confidence: Double
        /// Full probability distribution across all classes
        public let probabilities: [String: Double]
    }

    // MARK: - Private state

    /// Sliding window of the most recent observations.
    /// Elements may be nil when no body was detected for that frame.
    private var window: [VNHumanBodyPoseObservation?] = []

    /// Compiled Core ML model, loaded once from the main bundle.
    private var model: MLModel?

    /// Most recent successful prediction (returned during warm-up).
    private var lastPrediction: ActionPrediction?

    // MARK: - Init

    public init() {
        // Xcode compiles MyActionClassifier.mlmodel → MyActionClassifier.mlmodelc
        // at build time and places it in the app bundle.
        if let url = Bundle.main.url(
            forResource: "MyActionClassifier",
            withExtension: "mlmodelc"
        ) {
            let config = MLModelConfiguration()
            config.computeUnits = .all   // Neural Engine + GPU + CPU
            model = try? MLModel(contentsOf: url, configuration: config)
        }
    }

    // MARK: - Public API

    /// Append the latest frame's body-pose observation.
    /// - Parameter observation: Pass `nil` if no body was detected (→ zero-padded frame).
    public func append(_ observation: VNHumanBodyPoseObservation?) {
        window.append(observation)
        if window.count > Self.windowSize {
            window.removeFirst()
        }
    }

    /// Run the action classifier over the current 60-frame window.
    ///
    /// - Returns: A prediction once the window reaches 60 frames.
    ///   Returns the last cached prediction while warming up (first 2 s).
    ///   Returns `nil` when the model is unavailable (graceful fallback).
    public func predict() -> ActionPrediction? {
        guard let model else { return nil }

        // During warm-up (< 60 frames accumulated) return the last known result
        // so callers do not need special-case logic for the first two seconds.
        guard window.count == Self.windowSize else { return lastPrediction }

        do {
            // ── Build [60, 3, 18] multiarray ─────────────────────────────────
            // Each VNHumanBodyPoseObservation.keypointsMultiArray() returns [1, 3, 18].
            // Concatenating 60 of them along axis 0 yields [60, 3, 18].
            // Zero arrays stand for frames where no body was detected (PDF p. 54).
            let frames: [MLMultiArray] = try window.map { obs in
                if let obs {
                    return try obs.keypointsMultiArray()
                }
                // No body detected this frame — pad with zeros
                return try MLMultiArray(shape: [1, 3, 18], dataType: .float)
            }
            let poses = MLMultiArray(concatenating: frames, axis: 0, dataType: .float)

            // ── Run prediction ────────────────────────────────────────────────
            let provider = try MLDictionaryFeatureProvider(
                dictionary: ["poses": MLFeatureValue(multiArray: poses)]
            )
            let output = try model.prediction(from: provider)

            guard
                let label = output.featureValue(for: "label")?.stringValue,
                let rawProbs = output.featureValue(for: "labelProbabilities")?.dictionaryValue,
                let probs = rawProbs as? [String: Double]
            else {
                return lastPrediction
            }

            let prediction = ActionPrediction(
                label: label,
                confidence: probs[label] ?? 0.0,
                probabilities: probs
            )
            lastPrediction = prediction
            return prediction

        } catch {
            // Prediction failed (e.g. malformed input) — return last known result
            return lastPrediction
        }
    }

    /// Clear the window and cached prediction.
    /// Call this when a workout session ends so the next session gets a clean warm-up.
    public func reset() {
        window.removeAll()
        lastPrediction = nil
    }
}
#endif
