import Foundation

class ExportService {
    static let shared = ExportService()

    private let healthDirectoryName = "health"

    // MARK: - URLs

    private var defaultHealthDirectoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(healthDirectoryName)
    }

    var healthDirectoryURL: URL {
        resolveExportDirectory() ?? defaultHealthDirectoryURL
    }

    var hasCustomExportPath: Bool {
        SettingsManager().settings.exportDirectoryBookmark != nil
    }

    var exportPathDisplayName: String {
        if let url = resolveExportDirectory() {
            return url.lastPathComponent
        }
        return "On My iPhone > HealthExport"
    }

    func dateFolderURL(for dateString: String) -> URL {
        healthDirectoryURL.appendingPathComponent(dateString)
    }

    var isExportAvailable: Bool { true }

    // MARK: - Bookmark

    private func resolveExportDirectory() -> URL? {
        guard let bookmarkData = SettingsManager().settings.exportDirectoryBookmark else { return nil }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return url
        } catch {
            print("Failed to resolve bookmark: \(error)")
            return nil
        }
    }

    func saveExportDirectory(_ url: URL) {
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            let bookmarkData = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            SettingsManager().settings.exportDirectoryBookmark = bookmarkData
            print("Saved export directory: \(url.path)")
        } catch {
            print("Failed to save bookmark: \(error)")
        }
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

    // MARK: - Incremental Export

    func exportIncremental(_ healthData: HealthData) throws -> URL {
        guard let jsonData = exportToJSON(healthData) else {
            throw ExportError.encodingFailed
        }

        let baseURL = healthDirectoryURL
        let needsScopedAccess = resolveExportDirectory() != nil
        if needsScopedAccess {
            _ = baseURL.startAccessingSecurityScopedResource()
        }
        defer {
            if needsScopedAccess {
                baseURL.stopAccessingSecurityScopedResource()
            }
        }

        let dateFolder = baseURL.appendingPathComponent(healthData.date)
        try FileManager.default.createDirectory(
            at: dateFolder,
            withIntermediateDirectories: true
        )

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH-mm-ss"
        let fileName = "\(timeFormatter.string(from: Date())).json"
        let targetURL = dateFolder.appendingPathComponent(fileName)
        try jsonData.write(to: targetURL, options: [.atomic])
        return targetURL
    }

    func exportToLocal(_ healthData: HealthData) throws -> URL {
        try exportIncremental(healthData)
    }

    // MARK: - List Exported Files

    func listAllExportedFiles() -> [URL] {
        let baseURL = healthDirectoryURL
        guard FileManager.default.fileExists(atPath: baseURL.path) else { return [] }

        var result: [URL] = []
        do {
            let dateFolders = try FileManager.default.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for folder in dateFolders {
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
                    if folder.pathExtension == "json" { result.append(folder) }
                    continue
                }
                let files = try FileManager.default.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )
                result.append(contentsOf: files.filter { $0.pathExtension == "json" })
            }
            result.sort { url1, url2 in
                (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast >
                (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            }
        } catch {
            return []
        }
        return result
    }

    func listExportedFiles() -> [URL] {
        listAllExportedFiles()
    }

    func listDatesWithFileCount() -> [(date: String, count: Int)] {
        let baseURL = healthDirectoryURL
        guard FileManager.default.fileExists(atPath: baseURL.path) else { return [] }

        var result: [(String, Int)] = []
        do {
            let items = try FileManager.default.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for item in items {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    let files = try FileManager.default.contentsOfDirectory(at: item, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                    let jsonCount = files.filter { $0.pathExtension == "json" }.count
                    if jsonCount > 0 {
                        result.append((item.lastPathComponent, jsonCount))
                    }
                }
            }
            result.sort { $0.0 > $1.0 }
        } catch { }
        return result
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

// MARK: - Errors

enum ExportError: LocalizedError {
    case encodingFailed
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode health data"
        case .fileWriteFailed: return "Failed to write file"
        }
    }
}
