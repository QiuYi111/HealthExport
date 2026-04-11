import SwiftUI
import UIKit
import BackgroundTasks

struct SettingsView: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var healthKitService: HealthKitService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var showingExportSheet = false
    @State private var showingSuccessAlert = false
    @State private var showingExportPathPicker = false
    @State private var exportMessage = ""
    @State private var isExporting = false
    @State private var isTestingWebhook = false
    @State private var isSendingWebhook = false
    @State private var isRetryingQueue = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Sleep Data", isOn: $settingsManager.settings.syncSleep)
                        .tint(Color.sleep)
                    Toggle("Heart Rate", isOn: $settingsManager.settings.syncHeartRate)
                        .tint(Color.heartRate)
                    Toggle("Steps", isOn: $settingsManager.settings.syncSteps)
                        .tint(Color.steps)
                    Toggle("Active Energy", isOn: $settingsManager.settings.syncActiveEnergy)
                        .tint(Color.activeEnergy)
                    Toggle("Blood Oxygen", isOn: $settingsManager.settings.syncBloodOxygen)
                        .tint(Color.pink)
                    Toggle("Respiratory Rate", isOn: $settingsManager.settings.syncRespiratoryRate)
                        .tint(Color.teal)
                    Toggle("Exercise Time", isOn: $settingsManager.settings.syncExerciseTime)
                        .tint(Color.green)
                    Toggle("Distance", isOn: $settingsManager.settings.syncDistance)
                        .tint(Color.blue)
                } header: {
                    Text("Data Types")
                } footer: {
                    Text("Select which health metrics to include in exports")
                }

                Section {
                    HStack {
                        Text("Export Path")
                        Spacer()
                        Text(ExportService.shared.exportPathDisplayName)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    Button {
                        showingExportPathPicker = true
                    } label: {
                        Label("Change Export Path", systemImage: "folder.badge.plus")
                    }
                } header: {
                    Text("Export Location")
                } footer: {
                    Text("Choose a folder to store exported health data, including iCloud Drive")
                }

                // MARK: - Webhook Section
                Section {
                    Toggle("Enable Webhook", isOn: $settingsManager.settings.webhookEnabled)
                        .tint(.blue)

                    if settingsManager.settings.webhookEnabled {
                        TextField("Webhook URL", text: Binding(
                            get: { settingsManager.settings.webhookURL ?? "" },
                            set: { settingsManager.settings.webhookURL = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                        .font(.subheadline)

                        Stepper(
                            "Interval: \(settingsManager.settings.webhookSyncInterval) min",
                            value: $settingsManager.settings.webhookSyncInterval,
                            in: 5...240,
                            step: 5
                        )

                        Button {
                            Task { await testWebhook() }
                        } label: {
                            if isTestingWebhook {
                                ProgressView()
                            } else {
                                Label("Test Webhook", systemImage: "antenna.radiowaves.left.and.right")
                            }
                        }
                        .disabled(settingsManager.settings.webhookURL == nil || settingsManager.settings.webhookURL!.isEmpty)

                        Button {
                            Task { await sendWebhookNow() }
                        } label: {
                            if isSendingWebhook {
                                ProgressView()
                            } else {
                                Label("Send Now", systemImage: "paperplane.fill")
                            }
                        }
                        .disabled(settingsManager.settings.webhookURL == nil || settingsManager.settings.webhookURL!.isEmpty)

                        HStack {
                            Text("Pending")
                            Spacer()
                            Text("\(WebhookService.shared.pendingCount)")
                                .foregroundStyle(WebhookService.shared.pendingCount > 0 ? .orange : .secondary)
                        }

                        if let last = WebhookService.shared.lastSuccessDate ?? settingsManager.settings.lastWebhookSuccessDate {
                            HStack {
                                Text("Last Sent")
                                Spacer()
                                Text(last, style: .relative)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if WebhookService.shared.pendingCount > 0 {
                            Button {
                                Task { await retryQueue() }
                            } label: {
                                if isRetryingQueue {
                                    ProgressView()
                                } else {
                                    Label("Retry Queue (\(WebhookService.shared.pendingCount))", systemImage: "arrow.clockwise")
                                }
                            }

                            Button(role: .destructive) {
                                WebhookService.shared.clearQueue()
                            } label: {
                                Label("Clear Queue", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Webhook")
                } footer: {
                    Text("Automatically send health data to your webhook URL when data updates or on a schedule")
                }

                Section {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("Preview Export", systemImage: "doc.text")
                    }

                    Button {
                        Task { await exportNow() }
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Label("Export Now", systemImage: "arrow.down.doc")
                        }
                    }
                } header: {
                    Text("Manual Actions")
                }

                Section {
                    let dates = ExportService.shared.listDatesWithFileCount()
                    if dates.isEmpty {
                        Text("No exported files yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(dates.prefix(5), id: \.date) { item in
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.blue)
                                Text(item.date)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(item.count) files")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Exported Files")
                } footer: {
                    if settingsManager.settings.exportDirectoryBookmark != nil {
                        Text("Files are saved to your chosen export path")
                    } else {
                        Text("Visible in Files app > On My iPhone > HealthExport")
                    }
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("HealthKit")
                        Spacer()
                        Text(healthKitService.isAuthorized ? "Authorized" : "Not Authorized")
                            .foregroundStyle(healthKitService.isAuthorized ? .green : .orange)
                    }
                    HStack {
                        Text("Last Auto Export")
                        Spacer()
                        if let last = healthKitService.lastAutoExportDate {
                            Text(last, style: .time)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Never")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Status")
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingExportSheet) {
                ExportSheetView()
            }
            .sheet(isPresented: $showingExportPathPicker) {
                DocumentPickerView { url in
                    ExportService.shared.saveExportDirectory(url)
                }
            }
            .alert("Export", isPresented: $showingSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportMessage)
            }
            .onChange(of: settingsManager.settings.webhookEnabled) { enabled in
                if enabled {
                    // Schedule background refresh when webhook is enabled
                    let interval = Double(settingsManager.settings.webhookSyncInterval)
                    let request = BGAppRefreshTaskRequest(identifier: "com.healthexport.webhook.refresh")
                    request.earliestBeginDate = Date(timeIntervalSinceNow: interval * 60)
                    try? BGTaskScheduler.shared.submit(request)
                } else {
                    // Cancel pending background refresh when webhook is disabled
                    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: "com.healthexport.webhook.refresh")
                }
            }
        }
    }

    private func exportNow() async {
        isExporting = true
        do {
            let healthData = try await healthKitService.fetchAllData()
            let fileURL = try ExportService.shared.exportIncremental(healthData)
            exportMessage = "Saved: \(fileURL.lastPathComponent)"
            showingSuccessAlert = true
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
            showingSuccessAlert = true
        }
        isExporting = false
    }

    private func testWebhook() async {
        isTestingWebhook = true
        do {
            try await WebhookService.shared.testWebhook()
            exportMessage = "Webhook test successful!"
        } catch {
            exportMessage = "Webhook test failed: \(error.localizedDescription)"
        }
        showingSuccessAlert = true
        isTestingWebhook = false
    }

    private func sendWebhookNow() async {
        isSendingWebhook = true
        do {
            let healthData = try await healthKitService.fetchAllData()
            let payload = ExportPayload(
                deviceId: ExportPayload.deviceId,
                timestamp: Date(),
                data: healthData
            )
            await WebhookService.shared.send(payload)
            if WebhookService.shared.pendingCount == 0 {
                exportMessage = "Webhook sent successfully!"
            } else {
                exportMessage = "Webhook send failed — queued for retry"
            }
        } catch {
            exportMessage = "Failed to fetch health data: \(error.localizedDescription)"
        }
        showingSuccessAlert = true
        isSendingWebhook = false
    }

    private func retryQueue() async {
        isRetryingQueue = true
        await WebhookService.shared.retryPendingPayloads()
        isRetryingQueue = false
    }
}

// MARK: - Export Sheet View

struct ExportSheetView: View {
    @EnvironmentObject private var healthKitService: HealthKitService
    @Environment(\.dismiss) private var dismiss
    @State private var jsonOutput: String = ""
    @State private var isSharing = false
    @State private var shareURL: URL?

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
                                    UIPasteboard.general.string = jsonOutput
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                                    Task { await exportToLocal() }
                                } label: {
                                    Label("Save", systemImage: "arrow.down.doc")
                                        .frame(maxWidth: .infinity)
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
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await generateExport()
            }
            .sheet(isPresented: $isSharing) {
                if let url = shareURL {
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

    private func shareJSON() {
        Task {
            if let data = try? await healthKitService.fetchAllData(),
               let url = ExportService.shared.createShareFile(from: data) {
                shareURL = url
                isSharing = true
            }
        }
    }

    private func exportToLocal() async {
        do {
            let healthData = try await healthKitService.fetchAllData()
            let fileURL = try ExportService.shared.exportIncremental(healthData)
            jsonOutput = "Saved: \(fileURL.lastPathComponent)"
        } catch {
            jsonOutput = "Export failed: \(error.localizedDescription)"
        }
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

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
        .environmentObject(HealthKitService())
        .preferredColorScheme(.dark)
}
