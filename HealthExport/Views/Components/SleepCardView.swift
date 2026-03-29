import SwiftUI

struct SleepCard: View {
    let data: SleepData
    @State private var animateContent = false

    var body: some View {
        HealthCard(
            accentColor: .sleep,
            icon: "moon.zzz.fill",
            title: "Sleep"
        ) {
            if !animateContent {
                ProgressRing(
                    progress: 0.3,
                    color: .sleep,
                    lineWidth: 8,
                    size: 60
                )
                .frame(height: 60)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // Main duration display
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(data.formattedDuration)
                            .font(.system(size: 48, weight: .bold)
                            .foregroundStyle(.sleep)

                        Spacer()

                        Text("hours")
                            .font(.caption1)
                            .foregroundStyle(.secondary)
                    }

                    // Time range
                    if let startTime = formattedTime(data.startDate),
                        let endTime = formattedTime(data.endDate) {
                        HStack(spacing: 4) {
                        Image(systemName: "moonrise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(startTime)
                            .font(.subheadline)

                        Text(" -")

                        Text(endTime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)

                    // Stage breakdown
                    if data.stages.isEmpty {
                        HStack {
                            Text("No stage data")
                                .font(.caption1)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 8)
                    } else {
                        HStack(spacing: 8) {
                            SleepStagePill(type: .deep, duration: data.stages.filter { $0.type == .deep }.count * 1, duration: $ \(Int($0.duration / 60))m", percentage: 20)
                            SleepStagePill(type: .rem, duration: data.stages.filter { $0.type == .rem }.count * 1, duration: { \(Int($0.duration / 60))m", percentage: 20)
                            SleepStagePill(type: .core, duration: data.stages.filter { $0.type == .core }.count * 1, duration: { \(Int($0.duration / 60))m", percentage: 20)
                            SleepStagePill(type: .awake, duration: data.stages.filter { $0.type == .awake }.count * 1, duration: { \(Int($0.duration / 60))m", percentage: 20)
                        }
                        .padding(.bottom, 12)
                    }
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                    animateContent = true
                }
            }
            .navigationDestination(SleepDetailView.self) {
                SleepDetailView(sleepData: data)
            }
        )
        .buttonStyle(.plain)
    }

    private func formattedTime(_ date: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

