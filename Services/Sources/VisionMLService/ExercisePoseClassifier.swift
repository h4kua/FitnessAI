#if canImport(Core)
import Core
#endif
import Foundation

/// On-device, rule-based exercise classifier using Vision body pose joint positions.
/// All classification uses joint angle thresholds — no ML model required.
///
/// Vision coordinate system: x 0.0=left 1.0=right, y 0.0=bottom 1.0=top.
public struct ExercisePoseClassifier: Sendable {
    // MARK: - Joint name constants (VNHumanBodyPoseObservation.JointName rawValue strings)
    // These match the underlying VNRecognizedPointKey string values from Vision framework.
    private enum Joint {
        static let leftHip       = "left_hip"
        static let rightHip      = "right_hip"
        static let leftKnee      = "left_knee"
        static let rightKnee     = "right_knee"
        static let leftAnkle     = "left_ankle"
        static let rightAnkle    = "right_ankle"
        static let leftShoulder  = "left_shoulder"
        static let rightShoulder = "right_shoulder"
        static let leftElbow     = "left_elbow"
        static let rightElbow    = "right_elbow"
        static let leftWrist     = "left_wrist"
        static let rightWrist    = "right_wrist"
        static let neck          = "neck"
        static let root          = "root"
        static let nose          = "nose"
    }

    public init() {}

    /// Classify the pose and return the exercise with a confidence score 0.0–1.0.
    public func classify(sample: BodyPoseSample) -> (exercise: DetectedExercise, confidence: Double) {
        let pos = sample.jointPositions
        guard pos.isEmpty == false else { return (.unknown, 0) }

        if let result = trySquat(pos), result.confidence >= 0.55 { return result }
        if let result = tryPushUp(pos), result.confidence >= 0.55 { return result }
        if let result = tryPullUp(pos), result.confidence >= 0.55 { return result }
        if let result = tryJumpingJack(pos), result.confidence >= 0.55 { return result }
        if let result = trySitUp(pos), result.confidence >= 0.55 { return result }

        let meanConf = sample.meanConfidence
        if meanConf >= 0.4 { return (.standing, meanConf * 0.7) }
        return (.unknown, 0)
    }

    /// Compute key joint angles useful for Groq coaching prompts.
    public func extractAngles(from positions: [String: PosePoint]) -> [String: Double] {
        var angles: [String: Double] = [:]

        // Knee angles
        if let a = knee(side: "left", positions: positions) { angles["left_knee"] = a }
        if let a = knee(side: "right", positions: positions) { angles["right_knee"] = a }

        // Elbow angles
        if let a = elbow(side: "left", positions: positions) { angles["left_elbow"] = a }
        if let a = elbow(side: "right", positions: positions) { angles["right_elbow"] = a }

        // Hip angles (trunk-hip-knee)
        if let a = hip(side: "left", positions: positions) { angles["left_hip"] = a }
        if let a = hip(side: "right", positions: positions) { angles["right_hip"] = a }

        return angles
    }

    // MARK: - Exercise-specific classifiers

    private func trySquat(_ pos: [String: PosePoint]) -> (exercise: DetectedExercise, confidence: Double)? {
        guard let leftKnee  = pos[Joint.leftKnee],
              let rightKnee = pos[Joint.rightKnee],
              let leftHip   = pos[Joint.leftHip],
              let rightHip  = pos[Joint.rightHip],
              let leftAnkle  = pos[Joint.leftAnkle],
              let rightAnkle = pos[Joint.rightAnkle]
        else { return nil }

        let leftKneeAngle  = angle(at: leftKnee,  from: leftHip,  to: leftAnkle)
        let rightKneeAngle = angle(at: rightKnee, from: rightHip, to: rightAnkle)
        let avgKneeAngle   = (leftKneeAngle + rightKneeAngle) / 2

        // Squat: both knees significantly bent (<130°), hips below shoulder level
        guard avgKneeAngle < 130 else { return nil }

        let hipY = (leftHip.y + rightHip.y) / 2
        let ankleY = (leftAnkle.y + rightAnkle.y) / 2
        // In Vision coords, y=1 is top. If hip.y is close to ankle.y, they're near the ground.
        let hipToAnkleRatio = max(0, hipY - ankleY) // how high hips are above ankles

        // Deep squat: ratio small (hips low), knee very bent
        let depthScore = 1.0 - min(hipToAnkleRatio / 0.4, 1.0) // 0.4 = typical standing ratio
        let bendScore  = 1.0 - min(avgKneeAngle / 130.0, 1.0)
        let confidence = (depthScore * 0.6 + bendScore * 0.4)

        return (.squat, confidence)
    }

    private func tryPushUp(_ pos: [String: PosePoint]) -> (exercise: DetectedExercise, confidence: Double)? {
        guard let leftShoulder  = pos[Joint.leftShoulder],
              let rightShoulder = pos[Joint.rightShoulder],
              let leftHip       = pos[Joint.leftHip],
              let rightHip      = pos[Joint.rightHip],
              pos[Joint.leftElbow] != nil,
              pos[Joint.rightElbow] != nil
        else { return nil }

        let shoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let hipY      = (leftHip.y + rightHip.y) / 2

        // Push-up: body nearly horizontal (shoulders ≈ hip height, both close to ground)
        let bodyHorizontal = abs(shoulderY - hipY) < 0.12

        // At least one elbow must be present and bent
        let leftElbowAngle  = elbow(side: "left", positions: pos) ?? 180
        let rightElbowAngle = elbow(side: "right", positions: pos) ?? 180
        let avgElbowAngle   = (leftElbowAngle + rightElbowAngle) / 2

        guard bodyHorizontal, avgElbowAngle < 170 else { return nil }

        let horizontalScore = 1.0 - min(abs(shoulderY - hipY) / 0.12, 1.0)
        let bendScore = 1.0 - min(avgElbowAngle / 170.0, 1.0)
        let confidence = horizontalScore * 0.5 + bendScore * 0.5

        // Also check body is relatively low (not standing horizontal like a plank far from camera)
        let bodyLow = (shoulderY + hipY) / 2 < 0.55
        guard bodyLow else { return nil }

        return (.pushUp, confidence)
    }

    private func tryPullUp(_ pos: [String: PosePoint]) -> (exercise: DetectedExercise, confidence: Double)? {
        guard let leftWrist     = pos[Joint.leftWrist],
              let rightWrist    = pos[Joint.rightWrist],
              let leftShoulder  = pos[Joint.leftShoulder],
              let rightShoulder = pos[Joint.rightShoulder],
              pos[Joint.leftElbow] != nil,
              pos[Joint.rightElbow] != nil
        else { return nil }

        let shoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let wristY    = (leftWrist.y + rightWrist.y) / 2

        // Pull-up: wrists significantly above shoulders (hands gripping bar overhead)
        guard wristY > shoulderY + 0.15 else { return nil }

        // Elbows must be bent (not simply hanging with arms extended)
        let leftElbowAngle  = elbow(side: "left",  positions: pos) ?? 180
        let rightElbowAngle = elbow(side: "right", positions: pos) ?? 180
        let avgElbowAngle   = (leftElbowAngle + rightElbowAngle) / 2

        guard avgElbowAngle < 160 else { return nil }

        let overheadScore = min((wristY - shoulderY - 0.15) / 0.20, 1.0)
        let bendScore     = 1.0 - min(avgElbowAngle / 160.0, 1.0)
        let confidence    = overheadScore * 0.5 + bendScore * 0.5

        return (.pullUp, confidence)
    }

    private func tryJumpingJack(_ pos: [String: PosePoint]) -> (exercise: DetectedExercise, confidence: Double)? {
        guard let leftWrist    = pos[Joint.leftWrist],
              let rightWrist   = pos[Joint.rightWrist],
              let leftShoulder = pos[Joint.leftShoulder],
              let rightShoulder = pos[Joint.rightShoulder],
              let leftAnkle    = pos[Joint.leftAnkle],
              let rightAnkle   = pos[Joint.rightAnkle]
        else { return nil }

        let shoulderY = (leftShoulder.y + rightShoulder.y) / 2

        // Arms raised: wrists above shoulders (higher y in Vision = higher in image)
        let leftArmRaised  = leftWrist.y  > shoulderY + 0.05
        let rightArmRaised = rightWrist.y > shoulderY + 0.05
        let armsRaised = leftArmRaised && rightArmRaised

        // Legs spread: horizontal ankle distance > 0.25 (normalized)
        let legSpread = abs(leftAnkle.x - rightAnkle.x) > 0.22

        guard armsRaised || legSpread else { return nil }

        var score = 0.0
        if armsRaised { score += 0.5 }
        if legSpread  { score += 0.5 }
        guard score >= 0.5 else { return nil }

        return (.jumpingJack, score)
    }

    private func trySitUp(_ pos: [String: PosePoint]) -> (exercise: DetectedExercise, confidence: Double)? {
        guard let leftShoulder  = pos[Joint.leftShoulder],
              let rightShoulder = pos[Joint.rightShoulder],
              let leftKnee      = pos[Joint.leftKnee],
              let rightKnee     = pos[Joint.rightKnee],
              let leftHip       = pos[Joint.leftHip],
              let rightHip      = pos[Joint.rightHip]
        else { return nil }

        let shoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let kneeY     = (leftKnee.y + rightKnee.y) / 2
        let hipY      = (leftHip.y + rightHip.y) / 2

        // Sit-up: knees bent, body near supine (shoulders low), torso flexing toward knees
        // In supine: shoulder.y ≈ hip.y ≈ knee.y (all low), knees slightly higher
        let bodyLow = shoulderY < 0.45 && hipY < 0.45
        let kneesBent = (leftKnee.y + rightKnee.y) / 2 > hipY
        // Torso angled: shoulders approaching knees
        let crunchAngle = abs(shoulderY - kneeY) < 0.15

        guard bodyLow && kneesBent else { return nil }

        let confidence: Double = crunchAngle ? 0.75 : 0.6
        return (.sitUp, confidence)
    }

    // MARK: - Angle calculation helpers

    /// Angle in degrees at point B, formed by line A→B→C.
    private func angle(at b: PosePoint, from a: PosePoint, to c: PosePoint) -> Double {
        let ax = a.x - b.x, ay = a.y - b.y
        let cx = c.x - b.x, cy = c.y - b.y
        let dot = ax * cx + ay * cy
        let magA = sqrt(ax * ax + ay * ay)
        let magC = sqrt(cx * cx + cy * cy)
        guard magA > 0, magC > 0 else { return 180 }
        let cosAngle = max(-1, min(1, dot / (magA * magC)))
        return acos(cosAngle) * (180 / .pi)
    }

    private func knee(side: String, positions: [String: PosePoint]) -> Double? {
        let hipKey    = side == "left" ? Joint.leftHip    : Joint.rightHip
        let kneeKey   = side == "left" ? Joint.leftKnee   : Joint.rightKnee
        let ankleKey  = side == "left" ? Joint.leftAnkle  : Joint.rightAnkle
        guard let h = positions[hipKey], let k = positions[kneeKey], let a = positions[ankleKey] else { return nil }
        return angle(at: k, from: h, to: a)
    }

    private func elbow(side: String, positions: [String: PosePoint]) -> Double? {
        let shoulderKey = side == "left" ? Joint.leftShoulder : Joint.rightShoulder
        let elbowKey    = side == "left" ? Joint.leftElbow    : Joint.rightElbow
        let wristKey    = side == "left" ? Joint.leftWrist    : Joint.rightWrist
        guard let s = positions[shoulderKey], let e = positions[elbowKey], let w = positions[wristKey] else { return nil }
        return angle(at: e, from: s, to: w)
    }

    private func hip(side: String, positions: [String: PosePoint]) -> Double? {
        let shoulderKey = side == "left" ? Joint.leftShoulder : Joint.rightShoulder
        let hipKey      = side == "left" ? Joint.leftHip      : Joint.rightHip
        let kneeKey     = side == "left" ? Joint.leftKnee     : Joint.rightKnee
        guard let s = positions[shoulderKey], let h = positions[hipKey], let k = positions[kneeKey] else { return nil }
        return angle(at: h, from: s, to: k)
    }
}
