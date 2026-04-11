import Foundation
import SwiftUI

// MARK: - Main Health Data Model

struct HealthData: Codable {
    let date: String
    let sleep: SleepData?
    let heartRate: HeartRateData?
    let oxygenSaturation: OxygenSaturationData?
    let wristTemperature: WristTemperatureData?
    let respiratoryRate: RespiratoryRateData?
    let steps: StepsData?
    let activeEnergy: ActiveEnergyData?
    let distance: DistanceData?
    let exerciseMinutes: ExerciseMinutesData?
    let standMinutes: StandMinutesData?
    let restingHeartRate: Double?
    let walkingHeartRateAverage: WalkingHeartRateAverageData?
    let heartRateVariability: HeartRateVariabilityData?
}

// MARK: - Sleep Data

struct SleepData: Codable, Identifiable {
    let id = UUID()
    let totalDuration: TimeInterval
    let stages: [SleepStage]
    let startDate: Date
    let endDate: Date
    let efficiency: Double

    var formattedDuration: String {
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }

    var hoursAndMinutes: (hours: Int, minutes: Int) {
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        return (hours, minutes)
    }
}

// MARK: - Sleep Stage

struct SleepStage: Codable, Identifiable {
    let id = UUID()
    let type: SleepStageType
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

// MARK: - Sleep Stage Type

enum SleepStageType: String, Codable, CaseIterable {
    case awake
    case rem
    case core
    case deep

    var displayName: String {
        switch self {
        case .awake: return "Awake"
        case .rem: return "REM"
        case .core: return "Core"
        case .deep: return "Deep"
        }
    }

    var color: Color {
        switch self {
        case .awake: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .rem: return Color(red: 0.4, green: 0.4, blue: 0.9)
        case .core: return Color(red: 0.6, green: 0.4, blue: 0.8)
        case .deep: return Color(red: 0.3, green: 0.2, blue: 0.5)
        }
    }
}

// MARK: - Heart Rate Data

struct HeartRateData: Codable, Identifiable {
    let id = UUID()
    let currentBPM: Double
    let minBPM: Double
    let maxBPM: Double
    let restingBPM: Double?
    let samples: [HeartRateSample]
    let date: Date

    var range: String {
        "\(Int(minBPM)) - \(Int(maxBPM))"
    }
}

// MARK: - Heart Rate Sample

struct HeartRateSample: Codable, Identifiable {
    let id = UUID()
    let bpm: Double
    let date: Date
}

// MARK: - Heart Rate Variability

struct HeartRateVariabilityData: Codable {
    let samples: [HRVSample]
    let date: Date

    var average: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.value).reduce(0, +) / Double(samples.count)
    }

    var formattedAverage: String {
        String(format: "%.1f ms", average)
    }
}

struct HRVSample: Codable, Identifiable {
    let id = UUID()
    let value: Double // ms
    let date: Date
}

// MARK: - Oxygen Saturation

struct OxygenSaturationData: Codable, Identifiable {
    let id = UUID()
    let percentage: Double
    let minPercentage: Double
    let maxPercentage: Double
    let samples: [OxygenSaturationSample]
    let date: Date

    var formattedPercentage: String {
        String(format: "%.0f%%", percentage * 100)
    }
}

struct OxygenSaturationSample: Codable, Identifiable {
    let id = UUID()
    let percentage: Double
    let date: Date
}

// MARK: - Wrist Temperature

struct WristTemperatureData: Codable, Identifiable {
    let id = UUID()
    let temperature: Double // Celsius
    let samples: [WristTemperatureSample]
    let date: Date

    var formattedTemperature: String {
        String(format: "%.1f°C", temperature)
    }
}

struct WristTemperatureSample: Codable, Identifiable {
    let id = UUID()
    let temperature: Double
    let date: Date
}

// MARK: - Respiratory Rate

struct RespiratoryRateData: Codable, Identifiable {
    let id = UUID()
    let rate: Double
    let minRate: Double
    let maxRate: Double
    let samples: [RespiratoryRateSample]
    let date: Date

    var formattedRate: String {
        String(format: "%.0f breaths/min", rate)
    }
}

struct RespiratoryRateSample: Codable, Identifiable {
    let id = UUID()
    let rate: Double
    let date: Date
}

// MARK: - Walking Heart Rate Average

struct WalkingHeartRateAverageData: Codable, Identifiable {
    let id = UUID()
    let averageBPM: Double
    let date: Date

    var formattedBPM: String {
        String(format: "%.0f BPM", averageBPM)
    }
}

// MARK: - Steps Data

struct StepsData: Codable, Identifiable {
    let id = UUID()
    let count: Int
    let goal: Int
    let distance: Double?
    let date: Date

    var progress: Double {
        Double(count) / Double(goal)
    }

    var formattedCount: String {
        count.formattedWithCommas
    }

    var progressPercentage: Int {
        Int(min(progress * 100, 100))
    }
}

// MARK: - Distance Data

struct DistanceData: Codable, Identifiable {
    let id = UUID()
    let meters: Double
    let date: Date

    var formattedDistance: String {
        let km = meters / 1000
        return String(format: "%.2f km", km)
    }
}

// MARK: - Active Energy Data

struct ActiveEnergyData: Codable, Identifiable {
    let id = UUID()
    let calories: Double
    let goal: Double
    let date: Date

    var progress: Double {
        calories / goal
    }

    var formattedCalories: String {
        String(Int(calories))
    }

    var progressPercentage: Int {
        Int(min(progress * 100, 100))
    }
}

// MARK: - Exercise Minutes

struct ExerciseMinutesData: Codable, Identifiable {
    let id = UUID()
    let minutes: Double
    let goal: Double
    let date: Date

    var progress: Double {
        minutes / goal
    }

    var progressPercentage: Int {
        Int(min(progress * 100, 100))
    }
}

// MARK: - Stand Minutes

struct StandMinutesData: Codable, Identifiable {
    let id = UUID()
    let hours: Double
    let goal: Double
    let date: Date

    var formattedHours: String {
        String(format: "%.0f", hours)
    }

    var progressPercentage: Int {
        let goal = self.goal > 0 ? self.goal : 12
        return Int(min(hours / goal * 100, 100))
    }
}

// MARK: - Export Payload

struct ExportPayload: Codable {
    let deviceId: String
    let timestamp: Date
    let data: HealthData

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case timestamp
        case data
    }

    static var deviceId: String {
        var systemInfo = utsname()
        return withUnsafeMutablePointer(to: &systemInfo) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}

// MARK: - Helper Extensions

extension Int {
    var formattedWithCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
