#if canImport(Core)
import Core
#endif
import Foundation

// MARK: - Pose Feature Vector
// Stable input contract for the rule engine and future Core ML model.
// Matches schema from Lesson 10: leftKneeAngle, rightKneeAngle, hipAngle,
// torsoLean, minJointConfidence, phase.

public struct PoseFeatures: Sendable {
    /// Angle at left knee (hip → knee → ankle), degrees.
    public let leftKneeAngle: Double
    /// Angle at right knee (hip → knee → ankle), degrees.
    public let rightKneeAngle: Double
    /// Average hip angle (shoulder → hip → knee), degrees.
    public let hipAngle: Double
    /// Trunk lean from vertical, degrees (0 = perfectly upright).
    public let torsoLean: Double
    /// Minimum Vision confidence across required joints (0–1).
    public let minJointConfidence: Double
    /// Current phase in the rep cycle.
    public let phase: MovementPhase
    /// Left-right knee angle symmetry (0 = perfectly symmetric).
    public let kneeAsymmetry: Double
}

// MARK: - Extractor

/// Extracts a `PoseFeatures` vector from a `BodyPoseSample`.
/// This is the boundary between Vision pose data and either the rule engine
/// or a future Core ML model — keeping the schema stable here means only
/// the analyzer changes when the model is added.
public struct PoseFeatureExtractor: Sendable {

    private enum Joint {
        static let leftHip       = "left_hip"
        static let rightHip      = "right_hip"
        static let leftKnee      = "left_knee"
        static let rightKnee     = "right_knee"
        static let leftAnkle     = "left_ankle"
        static let rightAnkle    = "right_ankle"
        static let leftShoulder  = "left_shoulder"
        static let rightShoulder = "right_shoulder"
    }

    public init() {}

    /// Returns `nil` when required joints for the given exercise are missing.
    public func extract(
        from sample: BodyPoseSample,
        phase: MovementPhase = .standing
    ) -> PoseFeatures? {
        let pos = sample.jointPositions
        let conf = sample.jointConfidences

        guard
            let lHip  = pos[Joint.leftHip],
            let rHip  = pos[Joint.rightHip],
            let lKnee = pos[Joint.leftKnee],
            let rKnee = pos[Joint.rightKnee],
            let lAnkle = pos[Joint.leftAnkle],
            let rAnkle = pos[Joint.rightAnkle]
        else { return nil }

        let leftKneeAngle  = angle(at: lKnee,  from: lHip,  to: lAnkle)
        let rightKneeAngle = angle(at: rKnee,  from: rHip,  to: rAnkle)

        // Hip angle: average of shoulder→hip→knee on both sides
        let leftHipAngle  = hipAngle(shoulder: pos[Joint.leftShoulder],  hip: lHip, knee: lKnee) ?? 180
        let rightHipAngle = hipAngle(shoulder: pos[Joint.rightShoulder], hip: rHip, knee: rKnee) ?? 180
        let avgHipAngle   = (leftHipAngle + rightHipAngle) / 2

        // Torso lean: angle of the mid-hip → mid-shoulder line from vertical
        let lean = torsoLean(
            leftShoulder: pos[Joint.leftShoulder],
            rightShoulder: pos[Joint.rightShoulder],
            leftHip: lHip,
            rightHip: rHip
        )

        // Min confidence across required lower-body joints
        let requiredJoints = [Joint.leftHip, Joint.rightHip,
                               Joint.leftKnee, Joint.rightKnee,
                               Joint.leftAnkle, Joint.rightAnkle]
        let minConf = requiredJoints.compactMap { conf[$0] }.min() ?? 0

        let asymmetry = abs(leftKneeAngle - rightKneeAngle)

        return PoseFeatures(
            leftKneeAngle: leftKneeAngle,
            rightKneeAngle: rightKneeAngle,
            hipAngle: avgHipAngle,
            torsoLean: lean,
            minJointConfidence: minConf,
            phase: phase,
            kneeAsymmetry: asymmetry
        )
    }

    // MARK: - Geometry

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

    private func hipAngle(shoulder: PosePoint?, hip: PosePoint, knee: PosePoint) -> Double? {
        guard let s = shoulder else { return nil }
        return angle(at: hip, from: s, to: knee)
    }

    /// Degrees from vertical (0 = fully upright, 90 = horizontal).
    private func torsoLean(
        leftShoulder: PosePoint?,
        rightShoulder: PosePoint?,
        leftHip: PosePoint,
        rightHip: PosePoint
    ) -> Double {
        guard let ls = leftShoulder, let rs = rightShoulder else { return 0 }
        let midShoulderX = (ls.x + rs.x) / 2
        let midShoulderY = (ls.y + rs.y) / 2
        let midHipX      = (leftHip.x + rightHip.x) / 2
        let midHipY      = (leftHip.y + rightHip.y) / 2

        let dx = midShoulderX - midHipX
        let dy = midShoulderY - midHipY  // positive = shoulder above hip in Vision coords

        // Angle from vertical: atan2(horizontal offset / vertical distance)
        guard abs(dy) > 0.01 else { return 90 }
        return abs(atan2(abs(dx), abs(dy))) * (180 / .pi)
    }
}

// MARK: - Angle Smoother

/// Simple N-frame moving average for a joint angle.
/// Use one instance per joint to reduce Vision frame noise.
public struct AngleSmoother: Sendable {
    private let windowSize: Int
    private var buffer: [Double] = []

    public init(windowSize: Int = 4) {
        self.windowSize = max(1, windowSize)
    }

    public mutating func add(_ value: Double) -> Double {
        buffer.append(value)
        if buffer.count > windowSize { buffer.removeFirst() }
        return buffer.reduce(0, +) / Double(buffer.count)
    }

    public mutating func reset() { buffer.removeAll() }
}
