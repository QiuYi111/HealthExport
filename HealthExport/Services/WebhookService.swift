import Foundation

class WebhookService {
    static let shared = WebhookService()

    @Published var pendingCount: Int = 0
    @Published var lastSuccessDate: Date?

    private let queueDirectoryURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("webhook_queue")
    }()

    private let maxRetryCount = 5
    private let maxQueueSize = 100
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private init() {
        createQueueDirectoryIfNeeded()
        updatePendingCount()
    }

    // MARK: - Public API

    /// Send payload to webhook. On failure, enqueues for later retry.
    func send(_ payload: ExportPayload) async {
        guard let urlString = SettingsManager().settings.webhookURL,
              let url = URL(string: urlString),
              SettingsManager().settings.webhookEnabled else {
            return
        }

        do {
            try await performRequest(payload: payload, to: url)
            DispatchQueue.main.async { self.lastSuccessDate = Date() }
            SettingsManager().settings.lastSyncDate = Date()
        } catch {
            print("Webhook send failed: \(error.localizedDescription)")
            enqueue(payload)
        }
    }

    /// Retry all pending payloads in the queue.
    func retryPendingPayloads() async {
        guard let urlString = SettingsManager().settings.webhookURL,
              let url = URL(string: urlString),
              SettingsManager().settings.webhookEnabled else {
            return
        }

        let files = queuedFiles()
        for file in files {
            guard let payload = decodePayload(from: file) else {
                // Corrupt file, remove it
                try? FileManager.default.removeItem(at: file)
                continue
            }

            let retryCount = retryCountFrom(filename: file.lastPathComponent)
            if retryCount >= maxRetryCount {
                try? FileManager.default.removeItem(at: file)
                continue
            }

            do {
                try await performRequest(payload: payload, to: url)
                try? FileManager.default.removeItem(at: file)
                DispatchQueue.main.async { self.lastSuccessDate = Date() }
            } catch {
                // Re-enqueue with incremented retry count
                try? FileManager.default.removeItem(at: file)
                enqueue(payload, retryCount: retryCount + 1)
            }
        }
        updatePendingCount()
    }

    /// Test connectivity by sending a test payload.
    func testWebhook() async throws {
        guard let urlString = SettingsManager().settings.webhookURL,
              let url = URL(string: urlString) else {
            throw WebhookError.invalidURL
        }

        let testData = HealthData(
            date: "test", sleep: nil, heartRate: nil, oxygenSaturation: nil,
            wristTemperature: nil, respiratoryRate: nil, steps: nil,
            activeEnergy: nil, distance: nil, exerciseMinutes: nil,
            standMinutes: nil, restingHeartRate: nil,
            walkingHeartRateAverage: nil, heartRateVariability: nil
        )
        let payload = ExportPayload(
            deviceId: ExportPayload.deviceId,
            timestamp: Date(),
            data: testData
        )
        try await performRequest(payload: payload, to: url)
    }

    /// Delete all queued payloads.
    func clearQueue() {
        let files = queuedFiles()
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
        updatePendingCount()
    }

    // MARK: - Queue Management

    private func enqueue(_ payload: ExportPayload, retryCount: Int = 0) {
        createQueueDirectoryIfNeeded()
        enforceMaxQueueSize()

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "\(timestamp)-\(retryCount).json"
        let fileURL = queueDirectoryURL.appendingPathComponent(fileName)

        do {
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Failed to enqueue payload: \(error)")
        }
        updatePendingCount()
    }

    private func queuedFiles() -> [URL] {
        guard FileManager.default.fileExists(atPath: queueDirectoryURL.path) else { return [] }
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: queueDirectoryURL,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            return files.filter { $0.pathExtension == "json" }
                .sorted { ($0.lastPathComponent) < ($1.lastPathComponent) }
        } catch {
            return []
        }
    }

    private func retryCountFrom(filename: String) -> Int {
        // Format: "{timestamp}-{retryCount}.json"
        let name = filename.replacingOccurrences(of: ".json", with: "")
        let parts = name.split(separator: "-")
        guard parts.count >= 2, let count = Int(parts.last ?? "") else { return 0 }
        return count
    }

    private func decodePayload(from url: URL) -> ExportPayload? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ExportPayload.self, from: data)
    }

    private func createQueueDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: queueDirectoryURL.path) {
            try? FileManager.default.createDirectory(at: queueDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func enforceMaxQueueSize() {
        var files = queuedFiles()
        while files.count >= maxQueueSize, let oldest = files.first {
            try? FileManager.default.removeItem(at: oldest)
            files.removeFirst()
        }
    }

    private func updatePendingCount() {
        DispatchQueue.main.async {
            self.pendingCount = self.queuedFiles().count
        }
    }

    // MARK: - Network

    private func performRequest(payload: ExportPayload, to url: URL) async throws {
        let data = try encoder.encode(payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw WebhookError.serverError(statusCode)
        }
    }
}

// MARK: - Errors

enum WebhookError: LocalizedError {
    case invalidURL
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid webhook URL"
        case .serverError(let code):
            return "Server returned status \(code)"
        }
    }
}
