#if canImport(Core)
import Core
#endif
import Foundation
#if canImport(Infrastructure)
import Infrastructure
#endif
#if canImport(HealthKit)
import HealthKit
#endif

public actor LiveHealthKitService: HealthDataProviding {
    private let logger: AppLogger
    #if canImport(HealthKit)
    private let healthStore: HKHealthStore
    #endif

    // Apple intentionally prevents apps from checking READ-permission status
    // (only write status is readable via authorizationStatus(for:)).
    // We store a simple flag the first time the system sheet is shown.
    private static let authorizedKey = "healthkit.hasAuthorized"

    public init(logger: AppLogger) {
        self.logger = logger
        #if canImport(HealthKit)
        healthStore = HKHealthStore()
        #endif
    }

    // MARK: - Authorization Status

    public func authorizationStatus() async -> HealthAuthorizationStatus {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        // If the user has gone through the auth sheet at least once, treat as authorized.
        // If they denied, HealthKit silently returns 0 — we cannot distinguish from code.
        let hasAuthorized = UserDefaults.standard.bool(forKey: Self.authorizedKey)
        return hasAuthorized ? .authorized : .notDetermined
        #else
        return .unavailable
        #endif
    }

    // MARK: - Request Authorization

    public func requestAuthorization() async throws -> HealthAuthorizationStatus {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AppError.unavailable("Apple Health is not available on this device.")
        }
        guard let activeEnergyType = activeEnergyType else {
            throw AppError.invalidConfiguration("Active energy type is not available in HealthKit.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: [activeEnergyType]) { [logger] success, error in
                if let error {
                    logger.error("HealthKit authorization error: \(error.localizedDescription)")
                    continuation.resume(
                        throwing: AppError.authorizationDenied(
                            "Apple Health access was declined. Check Settings → Privacy & Security → Health."
                        )
                    )
                    return
                }
                // `success` means the system processed the request (not that the user said yes).
                // Mark as authorized so we don't show the prompt again; 0 data = user denied.
                UserDefaults.standard.set(true, forKey: Self.authorizedKey)
                logger.info("HealthKit authorization sheet completed (success=\(success))")
                continuation.resume(returning: .authorized)
            }
        }
        #else
        throw AppError.authorizationDenied("Apple Health is not available on this platform.")
        #endif
    }

    // MARK: - Calorie Summary

    public func calorieSummary(for date: Date, goal: CalorieGoal) async throws -> CalorieSummary {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AppError.unavailable("Apple Health is not available on this device.")
        }
        let activeEnergy = try await activeEnergyBurned(for: date)
        return CalorieSummary(date: date, activeEnergyBurned: activeEnergy, goal: goal)
        #else
        throw AppError.unavailable("Apple Health is not available on this platform.")
        #endif
    }
}

// MARK: - Private helpers

#if canImport(HealthKit)
private extension LiveHealthKitService {
    var activeEnergyType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
    }

    func activeEnergyBurned(for date: Date) async throws -> Double {
        guard let activeEnergyType else {
            throw AppError.invalidConfiguration("Active energy type is not available.")
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: activeEnergyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { [logger] _, result, error in
                if let error {
                    logger.error("HealthKit query failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                let kcal = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: kcal)
            }
            healthStore.execute(query)
        }
    }
}
#endif
