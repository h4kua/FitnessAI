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
    private var authorizationTask: Task<HealthAuthorizationStatus, Error>?
    #endif

    public init(logger: AppLogger) {
        self.logger = logger
        #if canImport(HealthKit)
        healthStore = HKHealthStore()
        #endif
    }

    public func authorizationStatus() async -> HealthAuthorizationStatus {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }

        guard let activeEnergyType = activeEnergyType else {
            return .unavailable
        }

        let status = healthStore.authorizationStatus(for: activeEnergyType)
        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .authorized
        @unknown default:
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    public func requestAuthorization() async throws -> HealthAuthorizationStatus {
        #if canImport(HealthKit)
        if let authorizationTask {
            return try await authorizationTask.value
        }

        guard let activeEnergyType = activeEnergyType else {
            throw AppError.invalidConfiguration("Active energy type is not available in HealthKit.")
        }

        let task = Task<HealthAuthorizationStatus, Error> { [healthStore, logger = self.logger] in
            guard HKHealthStore.isHealthDataAvailable() else {
                throw AppError.unavailable("Health data is not available on this device.")
            }

            return try await withCheckedThrowingContinuation { continuation in
                healthStore.requestAuthorization(toShare: [], read: [activeEnergyType]) { success, error in
                    if let error {
                        logger.error("HealthKit authorization failed: \(error.localizedDescription)")
                        continuation.resume(
                            throwing: AppError.authorizationDenied(
                                "Apple Health access was declined or is unavailable on this build."
                            )
                        )
                        return
                    }

                    continuation.resume(returning: success ? .authorized : .denied)
                }
            }
        }

        authorizationTask = task
        defer { authorizationTask = nil }
        do {
            return try await task.value
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.authorizationDenied("Apple Health access was declined or is unavailable on this build.")
        }
        #else
        throw AppError.authorizationDenied("Apple Health access was declined or is unavailable on this build.")
        #endif
    }

    public func calorieSummary(for date: Date, goal: CalorieGoal) async throws -> CalorieSummary {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            throw AppError.authorizationDenied("Apple Health access was declined or is unavailable on this build.")
        }

        try await ensureReadAuthorization()

        let activeEnergy = try await activeEnergyBurned(for: date)
        return CalorieSummary(
            date: date,
            activeEnergyBurned: activeEnergy,
            goal: goal
        )
        #else
        throw AppError.authorizationDenied("Apple Health access was declined or is unavailable on this build.")
        #endif
    }
}

#if canImport(HealthKit)
private extension LiveHealthKitService {
    var activeEnergyType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
    }

    func ensureReadAuthorization() async throws {
        let status = await authorizationStatus()
        switch status {
        case .authorized:
            return
        case .notDetermined:
            let updatedStatus = try await requestAuthorization()
            guard updatedStatus == .authorized else {
                throw AppError.authorizationDenied("Apple Health access was declined. Enable permissions in Settings to read active energy.")
            }
        case .denied:
            throw AppError.authorizationDenied("Apple Health access was declined. Enable permissions in Settings to read active energy.")
        case .unavailable:
            throw AppError.authorizationDenied("Apple Health access was declined or is unavailable on this build.")
        }
    }

    func activeEnergyBurned(for date: Date) async throws -> Double {
        guard let activeEnergyType else {
            throw AppError.invalidConfiguration("Active energy type is not available in HealthKit.")
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

                let kilocalories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: kilocalories)
            }

            healthStore.execute(query)
        }
    }
}
#endif
