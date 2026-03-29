import SwiftUI

@main
struct HealthExportApp: App {
    @StateObject private var healthKitService = HealthKitService()
    @StateObject private var settingsManager = SettingsManager()

    init() {
        // Set up background delivery callback
        healthKitService.backgroundDeliveryDelegate = nil // Will be set after init
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitService)
                .environmentObject(settingsManager)
                .preferredColorScheme(.dark)
                .task {
                    await setupBackgroundDeliveryIfEnabled()
                }
        }
    }

    private func setupBackgroundDeliveryIfEnabled() async {
        // Only enable background delivery if autoSync is on and HealthKit is authorized
        guard settingsManager.settings.autoSync else { return }
        guard healthKitService.isAuthorized else { return }

        // Set up the callback for background delivery
        healthKitService.onBackgroundDelivery = { [weak healthKitService] _ in
            Task {
                guard let service = healthKitService else { return }
                do {
                    let healthData = try await service.fetchAllData(for: Date())
                    _ = try await ExportService.shared.syncToiCloud(healthData)
                    print("Background sync completed successfully")
                } catch {
                    print("Background sync failed: \(error.localizedDescription)")
                }
            }
        }

        do {
            try await healthKitService.enableBackgroundDelivery()
            print("Background delivery enabled on app launch")
        } catch {
            print("Failed to enable background delivery on launch: \(error.localizedDescription)")
        }
    }
}
