import Foundation

class ExportService {
    static let shared = ExportService()

    private let iCloudContainerIdentifier = "iCloud.com.jingyi.healthexport"
    private let healthDirectoryName = "health"

    // MARK: - Container URLs

    var iCloudContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: iCloudContainerIdentifier)?
            .appendingPathComponent(healthDirectoryName)
    }

    var localDocumentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(healthDirectoryName)
    }

    // MARK: - Export to JSON

    func exportToJSON(_ healthData: HealthData) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try? encoder.encode(healthData)
    }

    func exportToJSONString(_ healthData: HealthData) -> String? {
        guard let data = exportToJSON(healthData) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Sync to iCloud (Primary Method)

    /// Syncs health data to iCloud Drive, with fallback to local Documents directory
    /// - Parameter healthData: The health data to sync
    /// - Returns: The URL where the file was saved
    /// - Throws: ExportError if encoding or file write fails
    func syncToiCloud(_ healthData: HealthData) async throws -> URL {
        // Generate filename based on date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "\(healthData.date).json"

        // Export health data to JSON
        guard let jsonData = exportToJSON(healthData) else {
            throw ExportError.encodingFailed
        }

        // Try iCloud first, fallback to local Documents
        let targetURL: URL
        let usingiCloud: Bool

        if let containerURL = iCloudContainerURL {
            targetURL = containerURL.appendingPathComponent(fileName)
            usingiCloud = true
        } else {
            targetURL = localDocumentsURL.appendingPathComponent(fileName)
            usingiCloud = false
        }

        // Create health directory if it doesn't exist
        try FileManager.default.createDirectory(at: usingiCloud ? iCloudContainerURL! : localDocumentsURL, withIntermediateDirectories: true)

        // Write to target location
        try jsonData.write(to: targetURL, options: [.atomic])

        print("Health data synced to \(usingiCloud ? "iCloud" : "local Documents"): \(targetURL.path)")
        return targetURL
    }

    // MARK: - iCloud Drive Export (Legacy - kept for compatibility)

    func exportToiCloud(_ healthData: HealthData) async throws -> URL {
        try await syncToiCloud(healthData)
    }

    func exportToiCloud(for date: Date, healthData: HealthData) async throws -> URL {
        try await syncToiCloud(healthData)
    }

    // MARK: - List Exported Files

    func listExportedFiles() -> [URL] {
        var allFiles: [URL] = []

        // Check iCloud
        if let containerURL = iCloudContainerURL {
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: containerURL,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )
                allFiles.append(contentsOf: files.filter { $0.pathExtension == "json" })
            } catch {}
        }

        // Check local Documents as fallback
        let localURL = localDocumentsURL
        if FileManager.default.fileExists(atPath: localURL.path) {
            do {
                let files = try FileManager.default.contentsOfDirectory(
                    at: localURL,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )
                allFiles.append(contentsOf: files.filter { $0.pathExtension == "json" })
            } catch {}
        }

        return allFiles.sorted { url1, url2 in
            (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast >
            (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
        }
    }

    // MARK: - Share Sheet Export

    func createShareFile(from healthData: HealthData) -> URL? {
        guard let jsonData = exportToJSON(healthData) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "health_export_\(ISO8601DateFormatter().string(from: Date())).json"
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try jsonData.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to create share file: \(error)")
            return nil
        }
    }
}

// MARK: - Response Model (kept for compatibility)

struct ExportResponse {
    let success: Bool
    let fileURL: URL?
    let message: String
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case iCloudNotAvailable
    case encodingFailed
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud Drive is not available. Please sign in to iCloud and enable iCloud Drive."
        case .encodingFailed:
            return "Failed to encode health data"
        case .fileWriteFailed:
            return "Failed to write file to iCloud Drive"
        }
    }
}
