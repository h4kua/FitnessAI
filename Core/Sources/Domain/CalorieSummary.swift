import Foundation

public struct CalorieSummary: Sendable, Equatable, Codable {
    public let date: Date
    public let activeEnergyBurned: Double
    public let goal: CalorieGoal

    public init(
        date: Date,
        activeEnergyBurned: Double,
        goal: CalorieGoal
    ) {
        self.date = date
        self.activeEnergyBurned = activeEnergyBurned
        self.goal = goal
    }

    public var completionRatio: Double {
        guard goal.activeEnergyGoal > 0 else {
            return 0
        }

        return min(activeEnergyBurned / goal.activeEnergyGoal, 1)
    }

    public var remainingEnergy: Double {
        max(goal.activeEnergyGoal - activeEnergyBurned, 0)
    }
}
