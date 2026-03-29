import Foundation
import HealthKit
import Combine

// MARK: - Background Delivery Delegate

protocol HealthKitBackgroundDeliveryDelegate: AnyObject {
    func healthKitService(_ service: HealthKitService, didReceiveBackgroundUpdateFor type: HKSampleType)
}

class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    // Background delivery state
    private var observerQueries: [HKObserverQuery] = []
    weak var backgroundDeliveryDelegate: HealthKitBackgroundDeliveryDelegate?

    // Callback for background delivery (alternative to delegate)
    var onBackgroundDelivery: ((HKSampleType) -> Void)?

    // MARK: - Types to Read

    private let typesToRead: Set = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .sleepAnalysis)!,
        HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
    ]

    // MARK: - Types for Background Delivery

    private var backgroundDeliveryTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()

        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepAnalysis)
        }

        return types
    }

    // MARK: - Authorization

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func checkAuthorizationStatus() {
        guard isHealthDataAvailable else {
            authorizationStatus = .notDetermined
            return
        }

        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        authorizationStatus = healthStore.authorizationStatus(for: heartRateType)
        isAuthorized = authorizationStatus == .sharingAuthorized
    }

    func requestAuthorization() async throws -> Bool {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.authorizationFailed(error.localizedDescription))
                } else {
                    DispatchQueue.main.async {
                        self.isAuthorized = success
                        self.checkAuthorizationStatus()
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }

    // MARK: - Background Delivery

    func enableBackgroundDelivery() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        // Enable background delivery for each type
        for type in backgroundDeliveryTypes {
            try await enableBackgroundDelivery(for: type)
        }

        // Set up observer queries
        for type in backgroundDeliveryTypes {
            setupObserverQuery(for: type)
        }
    }

    func disableBackgroundDelivery() async throws {
        // Stop all observer queries
        for query in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()

        // Disable background delivery for each type
        for type in backgroundDeliveryTypes {
            try await disableBackgroundDelivery(for: type)
        }
    }

    private func disableBackgroundDelivery(for type: HKSampleType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.disableBackgroundDelivery(for: type) { success, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.backgroundDeliveryFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func enableBackgroundDelivery(for type: HKSampleType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.backgroundDeliveryFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func setupObserverQuery(for type: HKSampleType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                print("Observer query error for \(type.identifier): \(error.localizedDescription)")
                completionHandler()
                return
            }

            // Trigger iCloud export when background delivery fires
            Task { [weak self] in
                await self?.handleBackgroundDelivery(for: type)
                completionHandler()
            }
        }

        healthStore.execute(query)
        observerQueries.append(query)
    }

    private func handleBackgroundDelivery(for type: HKSampleType) async {
        // Notify delegate/callback about background delivery
        await MainActor.run {
            // Call delegate method
            self.backgroundDeliveryDelegate?.healthKitService(self, didReceiveBackgroundUpdateFor: type)
            // Call closure callback
            self.onBackgroundDelivery?(type)
        }
        print("Background delivery notification for \(type.identifier)")
    }

    // MARK: - Fetch Data

    func fetchSleepData(for date: Date = Date()) async throws -> SleepData? {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                let sleepData = self.processSleepSamples(samples)
                continuation.resume(returning: sleepData)
            }
            self.healthStore.execute(query)
        }
    }

    private func processSleepSamples(_ samples: [HKCategorySample]) -> SleepData? {
        guard !samples.isEmpty else { return nil }

        var stages: [SleepStage] = []
        var totalDuration: TimeInterval = 0
        var earliestDate = Date.distantFuture
        var latestDate = Date.distantPast

        for sample in samples {
            let stageType = mapSleepStage(sample.value)
            let stage = SleepStage(
                type: stageType,
                startDate: sample.startDate,
                endDate: sample.endDate
            )
            stages.append(stage)

            if sample.startDate < earliestDate { earliestDate = sample.startDate }
            if sample.endDate > latestDate { latestDate = sample.endDate }
            totalDuration += sample.endDate.timeIntervalSince(sample.startDate)
        }

        // Calculate sleep efficiency (simplified - actual time in bed vs total sleep)
        let totalTimeInBed = latestDate.timeIntervalSince(earliestDate)
        let efficiency = totalTimeInBed > 0 ? totalDuration / totalTimeInBed : 0

        return SleepData(
            totalDuration: totalDuration,
            stages: stages,
            startDate: earliestDate,
            endDate: latestDate,
            efficiency: efficiency
        )
    }

    private func mapSleepStage(_ value: Int) -> SleepStageType {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .inBed:
            return .awake
        case .awake:
            return .awake
        case .asleepUnspecified, .asleep:
            return .core
        case .asleepCore:
            return .core
        case .asleepDeep:
            return .deep
        case .asleepREM:
            return .rem
        default:
            return .core
        }
    }

    func fetchHeartRateData(for date: Date = Date()) async throws -> HeartRateData? {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                let heartRateData = self.processHeartRateSamples(samples, date: date)
                continuation.resume(returning: heartRateData)
            }
            self.healthStore.execute(query)
        }
    }

    private func processHeartRateSamples(_ samples: [HKQuantitySample], date: Date) -> HeartRateData? {
        let unit = HKUnit.count().unitDivided(by: .minute())

        let bpmValues = samples.map { $0.quantity.doubleValue(for: unit) }
        let heartRateSamples = samples.map { sample in
            HeartRateSample(
                bpm: sample.quantity.doubleValue(for: unit),
                date: sample.startDate
            )
        }

        guard let currentBPM = bpmValues.last,
              let minBPM = bpmValues.min(),
              let maxBPM = bpmValues.max() else {
            return nil
        }

        return HeartRateData(
            currentBPM: currentBPM,
            minBPM: minBPM,
            maxBPM: maxBPM,
            restingBPM: nil,
            samples: heartRateSamples,
            date: date
        )
    }

    func fetchStepsData(for date: Date = Date()) async throws -> StepsData? {
        let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount)!

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: stepsType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                let totalSteps = samples.reduce(0) { $0 + $1.quantity.doubleValue(for: .count()) }
                let stepsData = StepsData(
                    count: Int(totalSteps),
                    goal: 10000,
                    distance: nil,
                    date: date
                )
                continuation.resume(returning: stepsData)
            }
            self.healthStore.execute(query)
        }
    }

    func fetchActiveEnergyData(for date: Date = Date()) async throws -> ActiveEnergyData? {
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [.strictStartDate])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: energyType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }

                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                let totalCalories = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: .kilocalorie()) }
                let energyData = ActiveEnergyData(
                    calories: totalCalories,
                    goal: 500,
                    date: date
                )
                continuation.resume(returning: energyData)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Fetch All Data

    func fetchAllData(for date: Date = Date()) async throws -> HealthData {
        async let sleep = try? fetchSleepData(for: date)
        async let heartRate = try? fetchHeartRateData(for: date)
        async let steps = try? fetchStepsData(for: date)
        async let activeEnergy = try? fetchActiveEnergyData(for: date)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return try await HealthData(
            date: dateFormatter.string(from: date),
            sleep: sleep,
            heartRate: heartRate,
            steps: steps,
            activeEnergy: activeEnergy
        )
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationFailed(String)
    case queryFailed(String)
    case backgroundDeliveryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationFailed(let message):
            return "Authorization failed: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        case .backgroundDeliveryFailed(let message):
            return "Background delivery failed: \(message)"
        }
    }
}
