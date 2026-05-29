import SwiftUI

// MARK: - Standard dark card

public struct FitnessCard<Content: View>: View {
    private let content: Content
    private let title: String?

    public init(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
            if let title {
                Text(title)
                    .font(FitnessTypography.cardTitle)
                    .foregroundStyle(FitnessTheme.primaryText)
            }
            content
        }
        .padding(FitnessSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(FitnessTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FitnessTheme.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: FitnessTheme.shadow, radius: 12, x: 0, y: 6)
    }
}

// MARK: - Gradient accent card

public struct GradientCard<Content: View>: View {
    private let content: Content
    private let gradient: LinearGradient
    private let cornerRadius: CGFloat

    public init(
        gradient: LinearGradient = FitnessTheme.accentGradient,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.gradient = gradient
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        content
            .padding(FitnessSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(gradient)
            )
            .shadow(color: FitnessTheme.shadow, radius: 16, x: 0, y: 8)
    }
}

// MARK: - Surface2 (slightly elevated) card

public struct ElevatedCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(FitnessSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(FitnessTheme.surface2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(FitnessTheme.surfaceStroke, lineWidth: 1)
            )
    }
}
