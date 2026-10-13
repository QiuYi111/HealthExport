import Foundation
import Combine

@MainActor
class SleepViewModel: ObservableObject {
    // Dependencies
    private let healthKitService: HealthKitService

    // Published State
    @Published var sleepData: SleepData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Animation states
    @Published var animateTimeline = false

    // MARK: - Computed Properties

    var hasData: Bool {
        sleepData != nil && !(sleepData?.stages.isEmpty ?? true)
    }

    var totalSleepHours: String {
        guard let data = sleepData else { return "0h" }
        let (h, m) = data.hoursAndMinutes
        return "\(h)h \(m)m"
    }

    var sleepEfficiency: String {
        guard let efficiency = sleepData?.efficiency else { return "--%" }
        return "\(Int(efficiency * 100))%"
    }

    var stageBreakdown: [(type: SleepStageType, duration: TimeInterval, percentage: Double)] {
        guard let data = sleepData else { return [] }

        let grouped = Dictionary(grouping: data.stages, by: { $0.type })
        var result: [(type: SleepStageType, duration: TimeInterval, percentage: Double)] = []

        for stageType in SleepStageType.allCases {
            let stages = grouped[stageType] ?? []
            let totalDuration = stages.reduce(0) { $0 + $1.duration }
            let percentage = data.totalDuration > 0 ? totalDuration / data.totalDuration : 0
            result.append((stageType, totalDuration, percentage))
        }

        return result.sorted { $0.duration > $1.duration }
    }

    // MARK: - Init

    init(healthKitService: HealthKitService) {
        self.healthKitService = healthKitService
    }

    // MARK: - Convenience Init with Data

    init(sleepData: SleepData?) {
        self.healthKitService = HealthKitService()
        self.sleepData = sleepData
    }

    // MARK: - Actions

    func loadData(for date: Date) async {
        isLoading = true
        errorMessage = nil

        do {
            sleepData = try await healthKitService.fetchSleepData(for: date)

            // Trigger animation after data loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.5)) {
                    self.animateTimeline = true
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func setSleepData(_ data: SleepData?) {
        sleepData = data

        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            animateTimeline = true
        }
    }

    // MARK: - Helpers

    func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }
}
