import Foundation
import HealthKit

class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var lastAutoExportDate: Date?

    private var observerQueries: [HKObserverQuery] = []
    private let autoExportQueue = DispatchQueue(label: "com.healthexport.autoexport")

    // MARK: - Types to Read

    private let typesToRead: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let quantityIDs: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .restingHeartRate,
            .walkingHeartRateAverage,
            .heartRateVariabilitySDNN,
            .oxygenSaturation,
            .respiratoryRate,
            .stepCount,
            .activeEnergyBurned,
            .basalEnergyBurned,
            .distanceWalkingRunning,
            .distanceCycling,
            .flightsClimbed,
            .appleExerciseTime,
            .appleStandTime,
            .bodyMass,
            .height,
            .bodyMassIndex,
            .bodyFatPercentage,
            .environmentalAudioExposure,
            .headphoneAudioExposure,
            .timeInDaylight,
            .walkingSpeed,
            .walkingStepLength,
            .walkingAsymmetryPercentage,
            .walkingDoubleSupportPercentage,
            .vo2Max
        ]
        for id in quantityIDs {
            if let t = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        if let t = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(t)
        }
        return types
    }()

    // MARK: - Authorization

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func checkAuthorizationStatus() {
        guard isHealthDataAvailable else {
            authorizationStatus = .notDetermined
            isAuthorized = false
            return
        }
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
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

    // MARK: - Observer Setup

    func setupObservers() {
        guard isAuthorized else { return }

        // Enable background delivery for key types
        let backgroundTypes: [HKQuantityTypeIdentifier] = [
            .heartRate, .stepCount, .activeEnergyBurned, .oxygenSaturation,
            .respiratoryRate, .heartRateVariabilitySDNN, .restingHeartRate
        ]

        for id in backgroundTypes {
            guard let type = HKObjectType.quantityType(forIdentifier: id) else { continue }

            // Enable background delivery
            healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
                if let error = error {
                    print("Background delivery failed for \(id): \(error)")
                }
            }

            // Set up observer query
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
                if let error = error {
                    print("Observer error for \(id): \(error)")
                    completionHandler()
                    return
                }
                self?.handleDataUpdate(typeIdentifier: id)
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }

        // Also observe sleep
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { _, _ in }
            let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completionHandler, _ in
                self?.handleDataUpdate(typeIdentifier: nil)
                completionHandler()
            }
            healthStore.execute(query)
            observerQueries.append(query)
        }
    }

    private func handleDataUpdate(typeIdentifier: HKQuantityTypeIdentifier?) {
        autoExportQueue.async {
            Task {
                do {
                    let url = try await self.fetchAndAutoExport()
                    DispatchQueue.main.async {
                        self.lastAutoExportDate = Date()
                        if let url = url {
                            print("Auto-exported: \(url.lastPathComponent)")
                        }
                    }
                } catch {
                    print("Auto-export failed: \(error)")
                }
            }
        }
    }

    // MARK: - Date Range Helper

    private func dateRange(for date: Date) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }

    // MARK: - Generic Fetchers

    private func fetchSum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, for date: Date) async throws -> Double {
        guard let range = dateRange(for: date),
              let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                cont.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            healthStore.execute(q)
        }
    }

    private func fetchAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit, for date: Date) async throws -> Double? {
        guard let range = dateRange(for: date),
              let type = HKObjectType.quantityType(forIdentifier: id) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                cont.resume(returning: result?.averageQuantity()?.doubleValue(for: unit))
            }
            healthStore.execute(q)
        }
    }

    private func fetchSamples(_ id: HKQuantityTypeIdentifier, unit: HKUnit, for date: Date) async throws -> [HKQuantitySample] {
        guard let range = dateRange(for: date),
              let type = HKObjectType.quantityType(forIdentifier: id) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                cont.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(q)
        }
    }

    // MARK: - Sleep

    func fetchSleepData(for date: Date = Date()) async throws -> SleepData? {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let range = dateRange(for: date) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: Self.processSleepSamples(samples))
            }
            self.healthStore.execute(q)
        }
    }

    private static func processSleepSamples(_ samples: [HKCategorySample]) -> SleepData? {
        var stages: [SleepStage] = []
        var totalDuration: TimeInterval = 0
        var earliest = Date.distantFuture
        var latest = Date.distantPast
        for s in samples {
            let type: SleepStageType
            switch HKCategoryValueSleepAnalysis(rawValue: s.value) {
            case .inBed, .awake: type = .awake
            case .asleepUnspecified, .asleep, .asleepCore: type = .core
            case .asleepDeep: type = .deep
            case .asleepREM: type = .rem
            default: type = .core
            }
            stages.append(SleepStage(type: type, startDate: s.startDate, endDate: s.endDate))
            earliest = min(earliest, s.startDate)
            latest = max(latest, s.endDate)
            totalDuration += s.endDate.timeIntervalSince(s.startDate)
        }
        let inBed = latest.timeIntervalSince(earliest)
        return SleepData(totalDuration: totalDuration, stages: stages, startDate: earliest, endDate: latest, efficiency: inBed > 0 ? totalDuration / inBed : 0)
    }

    // MARK: - Heart Rate

    func fetchHeartRateData(for date: Date = Date()) async throws -> HeartRateData? {
        let unit = HKUnit.count().unitDivided(by: .minute())
        let samples = try await fetchSamples(.heartRate, unit: unit, for: date)
        guard !samples.isEmpty else { return nil }
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        let hrSamples = samples.map { HeartRateSample(bpm: $0.quantity.doubleValue(for: unit), date: $0.startDate) }
        guard let cur = values.last, let min = values.min(), let max = values.max() else { return nil }
        return HeartRateData(currentBPM: cur, minBPM: min, maxBPM: max, restingBPM: nil, samples: hrSamples, date: date)
    }

    // MARK: - Steps

    func fetchStepsData(for date: Date = Date()) async throws -> StepsData? {
        let count = try await fetchSum(.stepCount, unit: .count(), for: date)
        guard count > 0 else { return nil }
        let dist = try? await fetchSum(.distanceWalkingRunning, unit: .meter(), for: date)
        return StepsData(count: Int(count), goal: 10000, distance: dist, date: date)
    }

    // MARK: - Active Energy

    func fetchActiveEnergyData(for date: Date = Date()) async throws -> ActiveEnergyData? {
        let cal = try await fetchSum(.activeEnergyBurned, unit: .kilocalorie(), for: date)
        guard cal > 0 else { return nil }
        return ActiveEnergyData(calories: cal, goal: 500, date: date)
    }

    // MARK: - Oxygen Saturation

    func fetchOxygenSaturationData(for date: Date = Date()) async throws -> OxygenSaturationData? {
        let unit = HKUnit.percent()
        let samples = try await fetchSamples(.oxygenSaturation, unit: unit, for: date)
        guard !samples.isEmpty else { return nil }
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        let o2Samples = samples.map { OxygenSaturationSample(percentage: $0.quantity.doubleValue(for: unit), date: $0.startDate) }
        guard let avg = Optional(values.reduce(0, +) / Double(values.count)),
              let min = values.min(), let max = values.max() else { return nil }
        return OxygenSaturationData(percentage: avg, minPercentage: min, maxPercentage: max, samples: o2Samples, date: date)
    }

    // MARK: - Respiratory Rate

    func fetchRespiratoryRateData(for date: Date = Date()) async throws -> RespiratoryRateData? {
        let unit = HKUnit.count().unitDivided(by: .minute())
        let samples = try await fetchSamples(.respiratoryRate, unit: unit, for: date)
        guard !samples.isEmpty else { return nil }
        let values = samples.map { $0.quantity.doubleValue(for: unit) }
        let rrSamples = samples.map { RespiratoryRateSample(rate: $0.quantity.doubleValue(for: unit), date: $0.startDate) }
        guard let avg = Optional(values.reduce(0, +) / Double(values.count)),
              let min = values.min(), let max = values.max() else { return nil }
        return RespiratoryRateData(rate: avg, minRate: min, maxRate: max, samples: rrSamples, date: date)
    }

    // MARK: - Resting Heart Rate

    func fetchRestingHeartRate(for date: Date = Date()) async throws -> Double? {
        return try await fetchAverage(.restingHeartRate, unit: .count().unitDivided(by: .minute()), for: date)
    }

    // MARK: - Walking Heart Rate Average

    func fetchWalkingHeartRateAverage(for date: Date = Date()) async throws -> WalkingHeartRateAverageData? {
        guard let avg = try await fetchAverage(.walkingHeartRateAverage, unit: .count().unitDivided(by: .minute()), for: date) else { return nil }
        return WalkingHeartRateAverageData(averageBPM: avg, date: date)
    }

    // MARK: - Heart Rate Variability

    func fetchHeartRateVariability(for date: Date = Date()) async throws -> HeartRateVariabilityData? {
        let unit = HKUnit.secondUnit(with: .milli)
        let samples = try await fetchSamples(.heartRateVariabilitySDNN, unit: unit, for: date)
        guard !samples.isEmpty else { return nil }
        let hrvSamples = samples.map { HRVSample(value: $0.quantity.doubleValue(for: unit), date: $0.startDate) }
        return HeartRateVariabilityData(samples: hrvSamples, date: date)
    }

    // MARK: - Distance

    func fetchDistanceData(for date: Date = Date()) async throws -> DistanceData? {
        let m = try await fetchSum(.distanceWalkingRunning, unit: .meter(), for: date)
        guard m > 0 else { return nil }
        return DistanceData(meters: m, date: date)
    }

    // MARK: - Exercise Minutes

    func fetchExerciseMinutesData(for date: Date = Date()) async throws -> ExerciseMinutesData? {
        let mins = try await fetchSum(.appleExerciseTime, unit: .minute(), for: date)
        guard mins > 0 else { return nil }
        return ExerciseMinutesData(minutes: mins, goal: 30, date: date)
    }

    // MARK: - Stand Hours

    func fetchStandMinutesData(for date: Date = Date()) async throws -> StandMinutesData? {
        let hrs = try await fetchSum(.appleStandTime, unit: .hour(), for: date)
        guard hrs > 0 else { return nil }
        return StandMinutesData(hours: hrs, goal: 12, date: date)
    }

    // MARK: - Auto Export

    func fetchAndAutoExport(for date: Date = Date()) async throws -> URL? {
        let data = try await fetchAllData(for: date)
        let localURL = try ExportService.shared.exportIncremental(data)

        // Webhook: send if enabled
        if SettingsManager().settings.webhookEnabled {
            let payload = ExportPayload(
                deviceId: ExportPayload.deviceId,
                timestamp: Date(),
                data: data
            )
            await WebhookService.shared.retryPendingPayloads()
            await WebhookService.shared.send(payload)
        }

        return localURL
    }

    // MARK: - Fetch All Data

    func fetchAllData(for date: Date = Date()) async throws -> HealthData {
        async let sleep = fetchSleepData(for: date)
        async let heartRate = fetchHeartRateData(for: date)
        async let steps = fetchStepsData(for: date)
        async let activeEnergy = fetchActiveEnergyData(for: date)
        async let oxygenSaturation = fetchOxygenSaturationData(for: date)
        async let respiratoryRate = fetchRespiratoryRateData(for: date)
        async let restingHeartRate = fetchRestingHeartRate(for: date)
        async let walkingHR = fetchWalkingHeartRateAverage(for: date)
        async let hrv = fetchHeartRateVariability(for: date)
        async let distance = fetchDistanceData(for: date)
        async let exercise = fetchExerciseMinutesData(for: date)
        async let stand = fetchStandMinutesData(for: date)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        return try await HealthData(
            date: df.string(from: date),
            sleep: sleep,
            heartRate: heartRate,
            oxygenSaturation: oxygenSaturation,
            wristTemperature: nil,
            respiratoryRate: respiratoryRate,
            steps: steps,
            activeEnergy: activeEnergy,
            distance: distance,
            exerciseMinutes: exercise,
            standMinutes: stand,
            restingHeartRate: restingHeartRate,
            walkingHeartRateAverage: walkingHR,
            heartRateVariability: hrv
        )
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationFailed(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available on this device"
        case .authorizationFailed(let msg): return "Authorization failed: \(msg)"
        case .queryFailed(let msg): return "Query failed: \(msg)"
        }
    }
}
