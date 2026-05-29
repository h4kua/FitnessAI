#if canImport(Core)
import Core
#endif
import Foundation

// MARK: - Core ML Form Classifier
//
// This adapter sits between PoseFeatures (Vision output) and ExerciseFormFeedback (UI).
// It is designed to be swapped between two backends without touching any other file:
//
//   Backend A (current): Rule-based logic identical to the PDF Lesson 10 tree.
//   Backend B (future):  SquatFormClassifier.mlmodel trained with Create ML.
//
// INPUT CONTRACT (must match model input layer):
//   - leftKneeAngle:       Double  (degrees, 0–180)
//   - rightKneeAngle:      Double  (degrees, 0–180)
//   - hipAngle:            Double  (degrees, 0–180)
//   - torsoLean:           Double  (degrees from vertical, 0–90)
//   - minJointConfidence:  Double  (0.0–1.0)
//   - phase:               String  ("standing" | "descending" | "bottom" | "rising")
//   - kneeAsymmetry:       Double  (degrees, 0–180)
//
// OUTPUT CONTRACT (must match model output class labels):
//   "goodForm" | "tooShallow" | "torsoLean" | "kneeIssue" | "lowConfidence" | "bodyNotVisible"
//
// HOW TO UPGRADE TO CORE ML:
//   1. Collect labeled pose samples using PoseFeatureExtractor.extract(from:)
//   2. Train a classifier in Create ML using the feature schema above
//   3. Export as SquatFormClassifier.mlmodel and add it to the Xcode project
//   4. Change `useRuleFallback` to `false` below — no other file changes needed.

public struct CoreMLFormClassifier: Sendable {

    // Flip to false once SquatFormClassifier.mlmodel is bundled in the app.
    private let useRuleFallback: Bool

    public init(useRuleFallback: Bool = true) {
        self.useRuleFallback = useRuleFallback
    }

    /// Classifies form from a feature vector.
    /// Returns nil when input features are insufficient to classify.
    public func classify(features: PoseFeatures, exercise: DetectedExercise) -> ExerciseFormFeedback? {
        guard exercise == .squat || exercise == .pushUp else {
            // Only squat and push-up have trained/rule logic — other exercises pass through
            return .goodForm
        }

        if useRuleFallback {
            return ruleBased(features: features, exercise: exercise)
        } else {
            return coreMLPredict(features: features, exercise: exercise)
                ?? ruleBased(features: features, exercise: exercise)
        }
    }

    // MARK: - Backend A: Rule-based (Lesson 10 exact tree)

    private func ruleBased(features: PoseFeatures, exercise: DetectedExercise) -> ExerciseFormFeedback {
        guard features.minJointConfidence >= 0.4 else { return .lowConfidence }

        switch exercise {
        case .squat:
            if features.kneeAsymmetry > 20              { return .kneeIssue }
            let avgKnee = (features.leftKneeAngle + features.rightKneeAngle) / 2
            if features.phase == .bottom || features.phase == .descending {
                if avgKnee > 120                         { return .tooShallow }
            }
            if features.torsoLean > 35                   { return .torsoLean }
            return .goodForm

        case .pushUp:
            if features.torsoLean > 15                   { return .torsoLean }
            return .goodForm

        default:
            return .goodForm
        }
    }

    // MARK: - Backend B: Core ML (plug in when model is ready)
    // swiftlint:disable:next unused_private_declaration
    private func coreMLPredict(features: PoseFeatures, exercise: DetectedExercise) -> ExerciseFormFeedback? {
        // 1. Build the MLFeatureProvider from `features`
        // 2. Run model.prediction(from: provider)
        // 3. Map classLabel string → ExerciseFormFeedback
        //
        // Example (uncomment once SquatFormClassifier.mlmodel is added):
        //
        // guard
        //     let modelURL = Bundle.main.url(forResource: "SquatFormClassifier", withExtension: "mlmodelc"),
        //     let model = try? MLModel(contentsOf: modelURL)
        // else { return nil }
        //
        // let input = SquatFormClassifierInput(
        //     leftKneeAngle: features.leftKneeAngle,
        //     rightKneeAngle: features.rightKneeAngle,
        //     hipAngle: features.hipAngle,
        //     torsoLean: features.torsoLean,
        //     minJointConfidence: features.minJointConfidence,
        //     phase: features.phase.rawValue,
        //     kneeAsymmetry: features.kneeAsymmetry
        // )
        // let output = try? model.prediction(from: input)
        // return ExerciseFormFeedback(rawValue: output?.classLabel ?? "") ?? nil

        return nil  // falls back to rule-based
    }
}
