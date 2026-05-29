import SwiftUI

public struct ScreenStateCard: View {
    private let actionTitle: String?
    private let imageSystemName: String
    private let message: String
    private let title: String
    private let tint: Color
    private let onAction: (() -> Void)?

    public init(
        title: String,
        message: String,
        imageSystemName: String,
        tint: Color = FitnessTheme.accent,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.imageSystemName = imageSystemName
        self.tint = tint
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    public var body: some View {
        FitnessCard {
            VStack(alignment: .leading, spacing: FitnessSpacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: imageSystemName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tint)
                }

                Text(title)
                    .font(FitnessTypography.cardTitle)
                    .foregroundStyle(FitnessTheme.primaryText)

                Text(message)
                    .font(FitnessTypography.body)
                    .foregroundStyle(FitnessTheme.secondaryText)

                if let actionTitle, let onAction {
                    Button(actionTitle, action: onAction)
                        .buttonStyle(PrimaryActionButtonStyle())
                        .padding(.top, FitnessSpacing.xSmall)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
