import Foundation

// MARK: - Main Health Data Model

struct HealthData: Codable {
    let date: String
    let sleep: SleepData?
    let heartRate: HeartRateData?
    let steps: StepsData?
    let activeEnergy: ActiveEnergyData?
}

// MARK: - Sleep Data

struct SleepData: Codable, Identifiable {
    let id = UUID()
    let totalDuration: TimeInterval
    let stages: [SleepStage]
    let startDate: Date
    let endDate: Date
    let efficiency: Double?

    var hoursAndMinutes: (hours: Int, minutes: Int) {
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        return (hours, minutes)
    }

    var formattedDuration: String {
        let (h, m) = hoursAndMinutes
        return "\(h)h \(m)m"
    }

    enum CodingKeys: String, CodingKey {
        case totalDuration, stages, startDate, endDate, efficiency
    }
}

struct SleepStage: Codable, Identifiable {
    let id = UUID()
    let type: SleepStageType
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var durationInMinutes: Int {
        Int(duration / 60)
    }
}

enum SleepStageType: String, Codable, CaseIterable {
    case awake = "awake"
    case rem = "rem"
    case core = "core"
    case deep = "deep"

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

    var formattedCurrent: String {
        String(Int(currentBPM))
    }

    var range: String {
        "\(Int(minBPM)) - \(Int(maxBPM))"
    }
}

struct HeartRateSample: Codable, Identifiable {
    let id = UUID()
    let bpm: Double
    let date: Date
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
}

// MARK: - Helper Extensions

extension Int {
    var formattedWithCommas: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

import SwiftUI
