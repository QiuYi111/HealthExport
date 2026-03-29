import SwiftUI

import Combine

import UIKit

import UniformTypeIdentifiers

import QuickLook

import WidgetKit

#if os can import BackgroundTasks
import UserNotifications
#endif

import SwiftUI

import UniformTypeIdentifiers

import UserNotifications
import Combine

import UIKit
import UniformTypeIdentifiers
import QuickLook
import WidgetKit
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications
import Combine
import UniformTypeIdentifiers

import SwiftUI
import UniformTypeIdentifiers

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var healthKitService: HealthKitService
    @Environment(\.dismiss) private var dismiss

    @Environment(\.scenePhase) private var scenePhase

    @State private var showingExportSheet = false
    @State private var showingSuccessAlert = false
    @State private var exportMessage = ""
    @State private var isExporting = false
    @State private var exportedFilesCount = 0

    var body: some View {
        NavigationStack {
                List {
                    Section {
                        Toggle(isOn: $settingsManager.settings.autoSync) {
                            Label("Auto Sync", systemImage: "arrow.triangle.2.icloud")
                        }

                        if settingsManager.settings.autoSync {
                            Text("Automatically sync health data to iCloud Drive when new data is available")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            Task {
                                await toggleAutoSync()
                            }
                        } label: {
                            Label("Sync Now", systemImage: "arrow.clockwise.icloud")
                        }
                        .disabled(isExporting)
                    } footer: {
                        Text("Auto Sync uses iCloud Drive to store your health data")
                    }

                    Section {
                        // iCloud status
                        HStack {
                            Text("iCloud Status")
                            Spacer()
                            if let url = ExportService.shared.iCloudContainerURL {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.orange)
                                Text("Not Available")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("iCloud Drive")
                    } footer: {
                        Text("Sign in to iCloud and enable iCloud Drive in Settings to use this feature")
                    }

                    Section {
                        // Data Types to Sync
                        Toggle("Sleep Data", isOn: $settingsManager.settings.syncSleep)
                            .tint(Color.sleep)

                        Toggle("Heart Rate", isOn: $settingsManager.settings.syncHeartRate)
                            .tint(Color.heartRate)

                        Toggle("Steps", isOn: $settingsManager.settings.syncSteps)
                            .tint(Color.steps)

                        Toggle("Active Energy", isOn: $settingsManager.settings.syncActiveEnergy)
                            .tint(Color.activeEnergy)
                    } header: {
                        Text("Data Types")
                    } footer: {
                        Text("Select which health metrics to include in exports")
                    }

                    Section {
                        // Export Actions
                        Button {
                            showingExportSheet = true
                        } label: {
                            Label("Preview Export", systemImage: "doc.text")
                        }

                        Button {
                            Task {
                                await exportToiCloud()
                            }
                        } label: {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(.circular)
                            } else {
                                Label("Export to iCloud", systemImage: "arrow.up.icloud")
                            }
                        }
                    } header: {
                        Text("Manual Actions")
                    }

                    Section {
                        // Exported files
                        let files = ExportService.shared.listExportedFiles()

                        if files.isEmpty {
                            Text("No exported files yet")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(files.prefix(3)) { file in
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundStyle(.blue)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.lastPathComponent)
                                            .font(.subheadline)

                                        Text(file.creationDate?.formatted(date: .medium, style: .short) ?? "")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if let date = file.creationDate {
                                        Text(date.formatted(date: .short))
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Exported Files")
                    } footer: {
                        Text("Files are stored in iCloud Drive > health/ folder")
                    }

                    Section {
                        // App Info
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(.secondary)
                        }

                        // Authorization Status
                        HStack {
                            Text("HealthKit Status")
                            Spacer()
                            Text(healthKitService.isAuthorized ? "Authorized" : "Not Authorized")
                                .foregroundStyle(healthKitService.isAuthorized ? .green : .orange)
                        }
                    } header: {
                        Text("About")
                    }

                    Section {
                        Button(role: .destructive) {
                            settingsManager.reset()
                        } label: {
                            Text("Reset All Settings")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingExportSheet) {
                ExportSheetView()
            }
            .alert("Export Successful", isPresented: $showingSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportMessage)
            }
        }
    }
    .task {
        await loadExportedFiles()
    }
    .onAppear {
        Task {
            await loadExportedFiles()
        }
    }
    .onChange(of: scenePhase) {
        if scenePhase == .active {
            Task {
                await loadExportedFiles()
            }
        }
    }
    private func loadExportedFiles() {
        exportedFilesCount = ExportService.shared.listExportedFiles().count
    }

    private func toggleAutoSync() async {
        if settingsManager.settings.autoSync {
            do {
                try await healthKitService.enableBackgroundDelivery()
                await MainActor.run {
                    exportMessage = "Auto Sync enabled. Health data will sync to iCloud Drive automatically."
                    showingSuccessAlert = true
                }
            } catch {
                settingsManager.settings.autoSync = false
                await MainActor.run {
                    exportMessage = "Failed to enable Auto Sync: \(error.localizedDescription)"
                    showingSuccessAlert = true
                }
            }
        } else {
            do {
                try await healthKitService.disableBackgroundDelivery()
                await MainActor.run {
                    exportMessage = "Auto Sync disabled."
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    exportMessage = "Failed to disable Auto Sync: \(error.localizedDescription)"
                    showingSuccessAlert = true
                }
            }
        }
    }

    private func exportToiCloud() async {
        isExporting = true

        do {
            let healthData = try await healthKitService.fetchAllData()
            let fileURL = try await ExportService.shared.exportToiCloud(healthData)

            await MainActor.run {
                exportMessage = "Health data exported to iCloud Drive:\ \(fileURL.lastPathComponent)"
                showingSuccessAlert = true
                exportedFilesCount = ExportService.shared.listExportedFiles().count
            }
        } catch {
            await MainActor.run {
                exportMessage = "Export failed: \(error.localizedDescription)"
                showingSuccessAlert = true
            }
        }

        isExporting = false
    }
}

// MARK: - Export Sheet View

struct ExportSheetView: View {
    @EnvironmentObject private var healthKitService: HealthKitService
    @Environment(\.dismiss) private var dismiss
    @State private var jsonOutput: String = ""
    @State private var isSharing = false

    @State private var isExportingToiCloud = false

    var body: some View {
        NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        if jsonOutput.isEmpty {
                            ProgressView("Generating export...")
                                .padding()
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Export Preview")
                                    .font(.headline)

                                ScrollView {
                                    Text(jsonOutput)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .padding()
                                }
                                .frame(maxHeight: 300)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )

                                HStack(spacing: 12) {
                                    Button {
                                        copyToClipboard()
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)

                                    Button {
                                        shareJSON()
                                    } label: {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)

                                    Button {
                                        Task {
                                            await exportToiCloudFromSheet()
                                        }
                                    } label: {
                                        if isExportingToiCloud {
                                            ProgressView()
                                                .scaleEffect(.circular)
                                        } else {
                                            Label("Save to iCloud", systemImage: "arrow.up.icloud")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await generateExport()
            }
            .sheet(isPresented: $isSharing) {
                if let data = try? await healthKitService.fetchAllData(),
                   let url = ExportService.shared.createShareFile(from: data) {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }

    private func generateExport() async {
        do {
            let data = try await healthKitService.fetchAllData()
            jsonOutput = ExportService.shared.exportToJSONString(data) ?? "Failed to generate export"
        } catch {
            jsonOutput = "Error: \(error.localizedDescription)"
        }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = jsonOutput

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func shareJSON() {
        isSharing = true
    }

    private func exportToiCloudFromSheet() async {
        isExportingToiCloud = true

        do {
            let healthData = try await healthKitService.fetchAllData()
            _ = try await ExportService.shared.exportToiCloud(healthData)
        } catch {
            // Show error
        }

        isExportingToiCloud = false
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
        .environmentObject(HealthKitService())
        .preferredColorScheme(.dark)
}
