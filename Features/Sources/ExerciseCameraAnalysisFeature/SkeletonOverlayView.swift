#if canImport(Core)
import Core
#endif
import SwiftUI

/// Draws a body-pose ridge skeleton (bones + joint dots) on top of the live camera feed.
///
/// Coordinate convention — Vision space:
///   x: 0.0 = left edge, 1.0 = right edge
///   y: 0.0 = bottom edge, 1.0 = top edge   ← opposite of screen y
///
/// All positions are flipped vertically before drawing: `screenY = (1 - visionY) * height`
public struct SkeletonOverlayView: View {

    public let joints: [String: PosePoint]

    public init(joints: [String: PosePoint]) {
        self.joints = joints
    }

    // MARK: - Bone connections

    /// Each tuple is a pair of joint names that should be connected by a line.
    private static let bones: [(String, String, BoneGroup)] = [
        // Torso
        ("left_shoulder",  "right_shoulder", .torso),
        ("left_shoulder",  "left_hip",       .torso),
        ("right_shoulder", "right_hip",      .torso),
        ("left_hip",       "right_hip",      .torso),
        // Left arm
        ("left_shoulder",  "left_elbow",     .leftSide),
        ("left_elbow",     "left_wrist",     .leftSide),
        // Right arm
        ("right_shoulder", "right_elbow",    .rightSide),
        ("right_elbow",    "right_wrist",    .rightSide),
        // Left leg
        ("left_hip",       "left_knee",      .leftSide),
        ("left_knee",      "left_ankle",     .leftSide),
        // Right leg
        ("right_hip",      "right_knee",     .rightSide),
        ("right_knee",     "right_ankle",    .rightSide),
        // Head / neck
        ("neck",           "left_shoulder",  .torso),
        ("neck",           "right_shoulder", .torso),
        ("neck",           "nose",           .head),
        ("nose",           "left_eye",       .head),
        ("nose",           "right_eye",      .head),
        ("left_eye",       "left_ear",       .head),
        ("right_eye",      "right_ear",      .head),
    ]

    private enum BoneGroup {
        case torso, leftSide, rightSide, head

        var color: Color {
            switch self {
            case .torso:     return Color(red: 1, green: 1, blue: 1).opacity(0.75)
            case .leftSide:  return Color(red: 0.25, green: 0.95, blue: 0.45).opacity(0.90)
            case .rightSide: return Color(red: 0.25, green: 0.70, blue: 1.00).opacity(0.90)
            case .head:      return Color(red: 1, green: 0.85, blue: 0.25).opacity(0.85)
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .torso:             return 3.0
            case .leftSide, .rightSide: return 2.5
            case .head:              return 2.0
            }
        }
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard !joints.isEmpty else { return }

                // Draw bones first (under dots)
                for (a, b, group) in Self.bones {
                    guard let pa = joints[a], let pb = joints[b] else { continue }
                    let pt1 = screen(pa, in: size)
                    let pt2 = screen(pb, in: size)
                    var path = Path()
                    path.move(to: pt1)
                    path.addLine(to: pt2)
                    context.stroke(
                        path,
                        with: .color(group.color),
                        style: StrokeStyle(lineWidth: group.lineWidth, lineCap: .round)
                    )
                }

                // Draw joint dots on top
                for (name, point) in joints {
                    let pt = screen(point, in: size)
                    let radius: CGFloat = isKeyJoint(name) ? 5 : 3.5
                    let dotColor: Color = isKeyJoint(name)
                        ? Color(red: 1, green: 0.9, blue: 0.1)    // yellow for key joints
                        : Color.white.opacity(0.80)

                    let dotRect = CGRect(
                        x: pt.x - radius,
                        y: pt.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
                    // Outer ring for visibility
                    context.stroke(
                        Path(ellipseIn: dotRect),
                        with: .color(Color.black.opacity(0.4)),
                        lineWidth: 1
                    )
                }
            }
        }
        .allowsHitTesting(false)   // transparent to touches
    }

    // MARK: - Helpers

    /// Convert a Vision-space PosePoint to a screen CGPoint.
    /// Flips y because Vision y=0 is bottom but screen y=0 is top.
    private func screen(_ p: PosePoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat(p.x) * size.width,
            y: (1.0 - CGFloat(p.y)) * size.height
        )
    }

    /// Key joints get a larger, brighter dot.
    private func isKeyJoint(_ name: String) -> Bool {
        ["left_knee", "right_knee", "left_hip", "right_hip",
         "left_shoulder", "right_shoulder", "left_elbow", "right_elbow"].contains(name)
    }
}
