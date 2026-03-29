import Foundation

struct Settings {
    var serverEndpoint: String
    var syncEnabled: Bool
    var syncSleep: Bool
    var syncHeartRate: Bool
    var syncSteps: Bool
    var syncActiveEnergy: Bool
    var autoSync: Bool

    static let `default` = Settings(
        serverEndpoint: "",
        syncEnabled: false,
        syncSleep: true,
        syncHeartRate: true,
        syncSteps: true,
        syncActiveEnergy: true,
        autoSync: false
    )
}

class SettingsManager: ObservableObject {
    @Published var settings: Settings {
        didSet {
            save()
        }
    }

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "healthExportSettings"

    init() {
        self.settings = load() ?? .default
    }

    private func load() -> Settings? {
        guard let data = userDefaults.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(Settings.self, from: data) else {
            return nil
        }
        return decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(encoded, forKey: settingsKey)
    }

    func reset() {
        settings = .default
    }
}

// MARK: - Codable Conformance

extension Settings: Codable {}
