import SwiftUI
import BackgroundTasks

@main
struct HealthExportApp: App {
    @StateObject private var healthKitService = HealthKitService()
    @StateObject private var settingsManager = SettingsManager()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitService)
                .environmentObject(settingsManager)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Retry pending webhook payloads when returning to foreground
                Task {
                    await WebhookService.shared.retryPendingPayloads()
                }
            }
        }
        .backgroundTask(.appRefresh("com.healthexport.webhook.refresh")) {
            await handleBackgroundRefresh()
        }
    }

    private func handleBackgroundRefresh() async {
        guard settingsManager.settings.webhookEnabled else { return }

        // First retry any queued payloads
        await WebhookService.shared.retryPendingPayloads()

        // Then fetch fresh data and send
        if healthKitService.isAuthorized {
            do {
                _ = try await healthKitService.fetchAndAutoExport()
            } catch {
                print("Background refresh export failed: \(error)")
            }
        }

        // Schedule next background refresh
        scheduleBackgroundRefresh()
    }

    func scheduleBackgroundRefresh() {
        let interval = Double(settingsManager.settings.webhookSyncInterval)
        let request = BGAppRefreshTaskRequest(identifier: "com.healthexport.webhook.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
    }
}
