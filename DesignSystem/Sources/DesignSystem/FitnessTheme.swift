import SwiftUI

// MARK: - FitnessTheme (Dark Premium)

public enum FitnessTheme {
    // MARK: Backgrounds
    public static let background  = Color(red: 0.05, green: 0.05, blue: 0.09)   // #0D0D17
    public static let surface     = Color(red: 0.10, green: 0.10, blue: 0.16)   // #1A1A28
    public static let surface2    = Color(red: 0.15, green: 0.15, blue: 0.22)   // #262638
    public static let surface3    = Color(red: 0.20, green: 0.20, blue: 0.28)   // #333347

    // MARK: Brand (Electric Mint)
    public static let accent      = Color(red: 0.00, green: 0.898, blue: 0.627) // #00E5A0
    public static let accentSoft  = accent.opacity(0.15)

    // MARK: Energy (Orange – Calories)
    public static let energy      = Color(red: 1.00, green: 0.42, blue: 0.24)   // #FF6B3D
    public static let energySoft  = energy.opacity(0.15)

    // MARK: Strength (Blue – Workouts)
    public static let strength    = Color(red: 0.29, green: 0.62, blue: 1.00)   // #4A9EFF
    public static let strengthSoft = strength.opacity(0.15)

    // MARK: Premium (Purple – Goals)
    public static let purple      = Color(red: 0.61, green: 0.43, blue: 1.00)   // #9B6DFF
    public static let purpleSoft  = purple.opacity(0.15)

    // MARK: Semantic (kept for API compatibility)
    public static let caution     = Color(red: 1.00, green: 0.77, blue: 0.20)   // #FFC433
    public static let cautionSoft = caution.opacity(0.15)
    public static let success     = Color(red: 0.00, green: 0.78, blue: 0.46)   // #00C875
    public static let successSoft = success.opacity(0.15)

    // MARK: Text
    public static let primaryText   = Color.white
    public static let secondaryText = Color(red: 0.54, green: 0.54, blue: 0.66) // #8A8AA8
    public static let tertiaryText  = Color(red: 0.33, green: 0.33, blue: 0.43) // #55556E

    // MARK: Structural
    public static let progressTrack  = Color.white.opacity(0.08)
    public static let surfaceStroke  = Color.white.opacity(0.07)
    public static let shadow         = Color.black.opacity(0.50)

    // MARK: Gradients
    public static let accentGradient = LinearGradient(
        colors: [Color(red: 0.00, green: 0.898, blue: 0.627),
                 Color(red: 0.00, green: 0.71,  blue: 0.85)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    public static let energyGradient = LinearGradient(
        colors: [Color(red: 1.00, green: 0.42, blue: 0.24),
                 Color(red: 0.90, green: 0.20, blue: 0.40)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    public static let strengthGradient = LinearGradient(
        colors: [Color(red: 0.29, green: 0.62, blue: 1.00),
                 Color(red: 0.45, green: 0.30, blue: 0.95)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    public static let goalGradient = LinearGradient(
        colors: [Color(red: 0.61, green: 0.43, blue: 1.00),
                 Color(red: 0.85, green: 0.25, blue: 0.70)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    public static let heroGradient = LinearGradient(
        colors: [Color(red: 0.00, green: 0.898, blue: 0.627).opacity(0.25),
                 Color(red: 0.05, green: 0.05,  blue: 0.09)],
        startPoint: .top, endPoint: .center
    )
    public static let darkGradient = LinearGradient(
        colors: [Color(red: 0.10, green: 0.10, blue: 0.16),
                 Color(red: 0.05, green: 0.05, blue: 0.09)],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - FitnessSpacing

public enum FitnessSpacing {
    public static let xSmall:  CGFloat = 4
    public static let small:   CGFloat = 8
    public static let medium:  CGFloat = 16
    public static let large:   CGFloat = 24
    public static let xLarge:  CGFloat = 32
    public static let xxLarge: CGFloat = 48
}

// MARK: - FitnessTypography

public enum FitnessTypography {
    public static let display     = Font.system(size: 52, weight: .black,    design: .rounded)
    public static let hero        = Font.system(.largeTitle, design: .rounded).weight(.bold)
    public static let metric      = Font.system(size: 40,  weight: .black,   design: .rounded)
    public static let sectionTitle = Font.system(.title2,  design: .rounded).weight(.bold)
    public static let cardTitle   = Font.system(.title3,   design: .rounded).weight(.semibold)
    public static let subtitle    = Font.system(.subheadline, design: .rounded).weight(.semibold)
    public static let body        = Font.system(.body,     design: .rounded)
    public static let caption     = Font.system(.caption,  design: .rounded)
    public static let tiny        = Font.system(.caption2, design: .rounded).weight(.medium)
}
