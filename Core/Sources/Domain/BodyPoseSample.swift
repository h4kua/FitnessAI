import Foundation

/// A normalized 2-D point in Vision coordinate space.
/// x: 0.0 = left edge, 1.0 = right edge
/// y: 0.0 = bottom edge, 1.0 = top edge
public struct PosePoint: Sendable, Equatable, Codable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = PosePoint(x: 0, y: 0)

    func distance(to other: PosePoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

public struct BodyPoseSample: Sendable, Equatable, Codable {
    public let capturedAt: Date
    /// Per-joint detection confidence (0.0–1.0).
    public let jointConfidences: [String: Double]
    /// Per-joint normalized position in Vision coordinate space.
    public let jointPositions: [String: PosePoint]

    public init(
        capturedAt: Date = Date(),
        jointConfidences: [String: Double],
        jointPositions: [String: PosePoint] = [:]
    ) {
        self.capturedAt = capturedAt
        self.jointConfidences = jointConfidences
        self.jointPositions = jointPositions
    }

    public var meanConfidence: Double {
        guard jointConfidences.isEmpty == false else { return 0 }
        return jointConfidences.values.reduce(0, +) / Double(jointConfidences.count)
    }
}
