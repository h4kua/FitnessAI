import SwiftUI

public struct PrimaryActionButtonStyle: ButtonStyle {
    private let gradient: LinearGradient

    public init(gradient: LinearGradient = FitnessTheme.accentGradient) {
        self.gradient = gradient
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.vertical, FitnessSpacing.medium)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(gradient)
                    .opacity(configuration.isPressed ? 0.80 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .shadow(
                color: FitnessTheme.accent.opacity(configuration.isPressed ? 0 : 0.35),
                radius: 12, x: 0, y: 4
            )
    }
}

// Destructive / secondary variant
public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .foregroundStyle(FitnessTheme.secondaryText)
            .padding(.vertical, FitnessSpacing.medium)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(FitnessTheme.surface2)
                    .opacity(configuration.isPressed ? 0.80 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FitnessTheme.surfaceStroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
