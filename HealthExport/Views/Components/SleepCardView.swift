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
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(Color.sleep)

                        Spacer()

                        Text("hours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Time range
                    let startTime = formattedTime(data.startDate)
                    let endTime = formattedTime(data.endDate)
                    HStack(spacing: 4) {
                        Image(systemName: "moonrise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(startTime)
                            .font(.subheadline)

                        Text(" - ")

                        Text(endTime)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 8)

                    // Stage breakdown
                    if data.stages.isEmpty {
                        HStack {
                            Text("No stage data")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 8)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(SleepStageType.allCases, id: \.self) { stageType in
                                let stageDuration = totalDuration(for: stageType)
                                let percentage = data.totalDuration > 0
                                    ? Int(stageDuration / data.totalDuration * 100)
                                    : 0
                                SleepStagePill(
                                    type: stageType,
                                    duration: Int(stageDuration / 60),
                                    percentage: percentage
                                )
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                animateContent = true
            }
        }
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func totalDuration(for stageType: SleepStageType) -> TimeInterval {
        data.stages
            .filter { $0.type == stageType }
            .reduce(0) { $0 + $1.duration }
    }
}
