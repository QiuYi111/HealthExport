import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var healthKitService: HealthKitService
    @EnvironmentObject private var settingsManager: SettingsManager
    @State private var selectedDate = Date()
    @State private var healthData: HealthData?
    @State private var isLoading = false
    @State private var showContent = false
    @State private var showingSettings = false
    @State private var showingExportSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView

                    // Authorization prompt if needed
                    if !healthKitService.isAuthorized {
                        authorizationCard
                    } else if isLoading {
                        loadingView
                    } else if let data = healthData {
                        // Health data cards
                        cardsSection(data: data)
                    } else {
                        emptyStateView
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .background(Color(.systemBackground))
            .refreshable {
                await loadData()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportSheetView()
            }
            .task {
                await loadData()
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formattedTitle)
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            Text("Health Summary")
                .font(.title2)
                .foregroundStyle(.secondary)

            // Date navigation
            HStack(spacing: 16) {
                Button {
                    Task {
                        await changeDate(by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task {
                        await changeDate(by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(
                            Calendar.current.isDateInToday(selectedDate)
                                ? .tertiary
                                : .secondary
                        )
                }
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
    }

    // MARK: - Authorization Card

    private var authorizationCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 60))
                .foregroundStyle(.pink)

            Text("Access Health Data")
                .font(.title2.bold())

            Text("HealthExport needs permission to read your health data from Apple Health.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    try? await healthKitService.requestAuthorization()
                    await loadData()
                }
            } label: {
                Text("Grant Access")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading health data...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Data Available")
                .font(.headline)

            Text("Pull down to refresh or select a different date.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Cards Section

    @ViewBuilder
    private func cardsSection(data: HealthData) -> some View {
        VStack(spacing: 16) {
            // Sleep Card
            if let sleep = data.sleep {
                NavigationLink {
                    SleepDetailView(sleepData: sleep)
                } label: {
                    SleepCard(data: sleep)
                }
                .buttonStyle(.plain)
            }

            // Heart Rate Card
            if let heartRate = data.heartRate {
                HeartRateCard(data: heartRate)
            }

            // Steps Card
            if let steps = data.steps {
                StepsCard(data: steps)
            }

            // Active Energy Card
            if let activeEnergy = data.activeEnergy {
                ActiveEnergyCard(data: activeEnergy)
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
    }

    // MARK: - Computed Properties

    private var formattedTitle: String {
        Calendar.current.isDateInToday(selectedDate) ? "Today" : "Health"
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Actions

    private func loadData() async {
        guard healthKitService.isAuthorized else { return }

        isLoading = true
        showContent = false

        do {
            let data = try await healthKitService.fetchAllData(for: selectedDate)
            await MainActor.run {
                healthData = data
                isLoading = false

                withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                    showContent = true
                }
            }
        } catch {
            print("Error loading data: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }

    private func changeDate(by days: Int) async {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = newDate
        showContent = false
        await loadData()
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(HealthKitService())
        .environmentObject(SettingsManager())
        .preferredColorScheme(.dark)
}
