import SwiftUI

public struct CircularProgressView: View {
    private let lineWidth: CGFloat
    private let progress: Double
    private let tint: Color
    private let showGlow: Bool

    public init(
        progress: Double,
        tint: Color = FitnessTheme.accent,
        lineWidth: CGFloat = 10,
        showGlow: Bool = true
    ) {
        self.progress = min(max(progress, 0), 1)
        self.tint = tint
        self.lineWidth = lineWidth
        self.showGlow = showGlow
    }

    public var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(tint.opacity(0.12), lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: showGlow ? tint.opacity(0.50) : .clear, radius: 6)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Mini ring for tab/stat row

public struct MiniRingView: View {
    private let progress: Double
    private let tint: Color
    private let icon: String
    private let label: String
    private let value: String

    public init(
        progress: Double,
        tint: Color,
        icon: String,
        label: String,
        value: String
    ) {
        self.progress = progress
        self.tint = tint
        self.icon = icon
        self.label = label
        self.value = value
    }

    public var body: some View {
        VStack(spacing: FitnessSpacing.small) {
            ZStack {
                CircularProgressView(progress: progress, tint: tint, lineWidth: 7)
                    .frame(width: 60, height: 60)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(FitnessTypography.subtitle)
                .foregroundStyle(FitnessTheme.primaryText)

            Text(label)
                .font(FitnessTypography.tiny)
                .foregroundStyle(FitnessTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FitnessSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FitnessTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.15), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}
