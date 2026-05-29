import SwiftUI

public struct MetricBadge: View {
    private let systemImage: String
    private let text: String
    private let tint: Color

    public init(
        systemImage: String,
        text: String,
        tint: Color = FitnessTheme.accent
    ) {
        self.systemImage = systemImage
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        Label {
            Text(text)
                .font(FitnessTypography.caption)
        } icon: {
            Image(systemName: systemImage)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, FitnessSpacing.medium)
        .padding(.vertical, FitnessSpacing.small)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.18))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(0.30), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}
