import Foundation
import SwiftUI

// MARK: - Settings Model

struct AppSettings: Codable {
    var syncSleep: Bool = true
    var syncHeartRate: Bool = true
    var syncSteps: Bool = true
    var syncActiveEnergy: Bool = true
    var syncBloodOxygen: Bool = true
    var syncRespiratoryRate: Bool = true
    var syncWristTemperature: Bool = true
    var syncExerciseTime: Bool = true
    var syncDistance: Bool = true
    var syncRestingHeartRate: Bool = true
    var syncWalkingHeartRateAverage: Bool = true
    var syncHeartRateVariability: Bool = true
    var syncStandMinutes: Bool = true

    var autoSyncEnabled: Bool = false
    var autoSyncInterval: Int = 30 // minutes
    var lastSyncDate: Date?

    /// Security-scoped bookmark data for user-chosen export directory
    var exportDirectoryBookmark: Data?

    // MARK: - Webhook Settings
    var webhookEnabled: Bool = false
    var webhookURL: String?
    var webhookSyncInterval: Int = 30 // minutes
    var lastWebhookSuccessDate: Date?
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            saveSettings()
        }
    }

    private let defaults = UserDefaults.standard
    private let settingsKey = "app_settings"

    init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    func reset() {
        settings = AppSettings()
    }

    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            defaults.set(encoded, forKey: settingsKey)
        }
    }
}
