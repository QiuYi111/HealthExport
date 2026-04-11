import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var healthKitService: HealthKitService

    var body: some View {
        Group {
            if healthKitService.isHealthDataAvailable {
                DashboardView()
            } else {
                UnavailableView()
            }
        }
        .onAppear {
            healthKitService.checkAuthorizationStatus()
        }
        .onChange(of: healthKitService.isAuthorized) {
            if healthKitService.isAuthorized {
                healthKitService.setupObservers()
                Task { try? await healthKitService.fetchAndAutoExport() }
            }
        }
        .task {
            guard healthKitService.isAuthorized else { return }
            healthKitService.setupObservers()
            try? await healthKitService.fetchAndAutoExport()
        }
    }
}

// MARK: - Unavailable View

struct UnavailableView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("HealthKit Unavailable")
                    .font(.title2.bold())

                Text("This device does not support HealthKit. Please use an iPhone to access health data.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitService())
        .environmentObject(SettingsManager())
        .preferredColorScheme(.dark)
}
