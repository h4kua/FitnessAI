import Combine
#if canImport(Core)
import Core
#endif
import Foundation

@MainActor
public final class CalorieTrackingViewModel: ObservableObject {
    @Published public private(set) var healthStatusMessage: String?
    @Published public private(set) var loadState: LoadState = .idle
    @Published public private(set) var summary: CalorieSummary?

    private var goal: CalorieGoal
    private let healthDataProvider: any HealthDataProviding

    public init(
        goal: CalorieGoal,
        healthDataProvider: any HealthDataProviding
    ) {
        self.goal = goal
        self.healthDataProvider = healthDataProvider
    }

    public func updateGoal(_ goal: CalorieGoal) {
        self.goal = goal
        if loadState == .loaded {
            loadState = .idle
        }
    }

    public func refresh() async {
        guard loadState != .loading else {
            return
        }

        loadState = .loading
        healthStatusMessage = nil

        do {
            if let fallbackSummary = await fallbackSummaryIfNeeded(for: Date()) {
                summary = fallbackSummary
            } else {
                summary = try await healthDataProvider.calorieSummary(for: Date(), goal: goal)
            }
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    private func fallbackSummaryIfNeeded(for date: Date) async -> CalorieSummary? {
        let authorizationStatus = await healthDataProvider.authorizationStatus()
        guard authorizationStatus == .unavailable || authorizationStatus == .denied else {
            return nil
        }

        healthStatusMessage = "Apple Health access was declined or is unavailable on this build, so live calorie progress can't be shown."
        return nil
    }
}
