public enum SafetyResult: Sendable, Equatable {
    case approved
    case approvedWithWarnings([String])
    case needsLowerIntensity
    case needsShorterDuration
}
