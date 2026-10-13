import Foundation
import Combine

import UIKit

import UniformTypeIdentifiers

import SwiftUI

import UniformTypeIdentifiers

@MainActor
class DashboardViewModel: ObservableObject {
    // Dependencies
    private let healthKitService: HealthKitService
    private let exportService: ExportService

    // Published State
    @Published var healthData: HealthData?
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var showingAuthSheet = false
    @Published var showingExportSheet = false
    @Published var selectedDate = Date()
    @Published var exportSuccessMessage: String?
    @Published var showingExportSuccess = false

    // Animation states
    @Published var showContent = false

    // MARK: - Computed Properties

    var sleepData: SleepData? { healthData?.sleep }
    var heartRateData: HeartRateData? { healthData?.heartRate }
    var stepsData: StepsData? { healthData?.steps }
    var activeEnergyData: ActiveEnergyData? { healthData?.activeEnergy }

    var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    // MARK: - Init

    init(healthKitService: HealthKitService, exportService: ExportService = .shared) {
        self.healthKitService = healthKitService
        self.exportService = exportService

        // Check authorization status on init
        healthKitService.checkAuthorizationStatus()
    }

    // MARK: - Actions

    func checkAuthorization() {
        healthKitService.checkAuthorizationStatus()

        if healthKitService.authorizationStatus != .sharingAuthorized {
            showingAuthSheet = true
        }
    }

    func requestAuthorization() async {
        do {
            let granted = try await healthKitService.requestAuthorization()
            if granted {
                await loadData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadData() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            let data = try await healthKitService.fetchAllData(for: selectedDate)
            healthData = data

            // Animate in content
            withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                showContent = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async {
        isRefreshing = true
        await loadData()
        isRefreshing = false
    }

    func changeDate(by days: Int) async {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
            showContent = false
            await loadData()
        }
    }

    // MARK: - iCloud Export

    func exportToiCloud() async throws -> URL {
        guard let data = healthData else {
            throw ExportError.encodingFailed
        }

        return try await exportService.exportToiCloud(for: selectedDate, healthData: data)
    }

    func getJSONExport() -> String? {
        guard let data = healthData else { return nil }
        return exportService.exportToJSONString(data)
    }

    func createShareFile() -> URL? {
        guard let data = healthData else { return nil }
        return exportService.createShareFile(from: data)
    }
}
