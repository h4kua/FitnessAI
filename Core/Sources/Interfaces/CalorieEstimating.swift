public protocol CalorieEstimating: Sendable {
    func estimate(activityName: String, durationMinutes: Int, weightPounds: Double?) async throws -> CalorieEstimate
}
