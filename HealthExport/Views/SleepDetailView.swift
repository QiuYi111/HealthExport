import SwiftUI

struct SleepDetailView: View {
    let sleepData: SleepData
    @State private var animateTimeline = false
    @State private var selectedStage: SleepStage?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Summary
                headerSection

                // Sleep Timeline
                timelineSection

                // Stage Breakdown
                stageBreakdownSection

                // Additional Stats
                additionalStatsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Sleep Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateTimeline = true
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Total Duration
            VStack(spacing: 8) {
                Text(sleepData.formattedDuration)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.sleep)

                Text("Total Sleep")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            // Time range
            HStack(spacing: 8) {
                Image(systemName: "moonrise")
                    .foregroundStyle(.secondary)

                Text("\(formattedTime(sleepData.startDate)) - \(formattedTime(sleepData.endDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Efficiency if available
            if let efficiency = sleepData.efficiency {
                HStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("\(Int(efficiency * 100))%")
                            .font(.title.bold())
                            .foregroundStyle(.sleep)
                        Text("Efficiency")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.sleep.opacity(0.15))
                )
            }
        }
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stages")
                .font(.headline)

            // Timeline visualization
            VStack(spacing: 16) {
                // Stage bars
                SleepTimelineView(
                    stages: sleepData.stages,
                    startTime: sleepData.startDate,
                    endTime: sleepData.endDate
                )
                .frame(height: 60)
                .opacity(animateTimeline ? 1 : 0)
                .offset(y: animateTimeline ? 0 : 20)

                // Time labels
                HStack {
                    Text(formattedTime(sleepData.startDate))
                    Spacer()
                    Text(formattedTime(sleepData.endDate))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                // Legend
                HStack(spacing: 16) {
                    ForEach(SleepStageType.allCases, id: \.self) { type in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(type.color)
                                .frame(width: 8, height: 8)
                            Text(type.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - Stage Breakdown Section

    private var stageBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Breakdown")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(stageBreakdown, id: \.type) { item in
                    StageBreakdownRow(
                        type: item.type,
                        duration: item.duration,
                        percentage: item.percentage
                    )
                    .opacity(animateTimeline ? 1 : 0)
                    .offset(x: animateTimeline ? 0 : -20)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - Additional Stats Section

    private var additionalStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            HStack(spacing: 12) {
                StatCard(
                    title: "Longest Stage",
                    value: longestStage.type.displayName,
                    subtitle: formatDuration(longestStage.duration)
                )

                StatCard(
                    title: "Times Awake",
                    value: "\(awakeCount)",
                    subtitle: "times"
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var stageBreakdown: [(type: SleepStageType, duration: TimeInterval, percentage: Double)] {
        let grouped = Dictionary(grouping: sleepData.stages, by: { $0.type })
        var result: [(type: SleepStageType, duration: TimeInterval, percentage: Double)] = []

        for stageType in SleepStageType.allCases {
            let stages = grouped[stageType] ?? []
            let totalDuration = stages.reduce(0) { $0 + $1.duration }
            let percentage = sleepData.totalDuration > 0 ? totalDuration / sleepData.totalDuration : 0
            result.append((stageType, totalDuration, percentage))
        }

        return result.sorted { $0.duration > $1.duration }
    }

    private var longestStage: SleepStage {
        sleepData.stages.max(by: { $0.duration < $1.duration }) ?? sleepData.stages[0]
    }

    private var awakeCount: Int {
        sleepData.stages.filter { $0.type == .awake }.count
    }

    // MARK: - Helpers

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Sleep Timeline View

struct SleepTimelineView: View {
    let stages: [SleepStage]
    let startTime: Date
    let endTime: Date

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))

                // Stage bars
                HStack(spacing: 2) {
                    ForEach(stages) { stage in
                        Rectangle()
                            .fill(stage.type.color)
                            .frame(width: stageWidth(stage, totalWidth: geometry.size.width))
                    }
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func stageWidth(_ stage: SleepStage, totalWidth: CGFloat) -> CGFloat {
        let totalDuration = endTime.timeIntervalSince(startTime)
        let stageProportion = stage.duration / totalDuration
        return max(totalWidth * stageProportion - 2, 4)
    }
}

// MARK: - Stage Breakdown Row

struct StageBreakdownRow: View {
    let type: SleepStageType
    let duration: TimeInterval
    let percentage: Double

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(type.color)
                .frame(width: 12, height: 12)

            Text(type.displayName)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Text(formatDuration(duration))
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

            Text("\(Int(percentage * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.sleep)

            Text(subtitle)
                .font(.caption1)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SleepDetailView(sleepData: SleepData(
            totalDuration: 28880,
            stages: [
                SleepStage(type: .awake, startDate: Date().addingTimeInterval(-28880), endDate: Date().addingTimeInterval(-28000)),
                SleepStage(type: .deep, startDate: Date().addingTimeInterval(-28000), endDate: Date().addingTimeInterval(-24000)),
                SleepStage(type: .core, startDate: Date().addingTimeInterval(-24000), endDate: Date().addingTimeInterval(-18000)),
                SleepStage(type: .rem, startDate: Date().addingTimeInterval(-18000), endDate: Date().addingTimeInterval(-12000)),
                SleepStage(type: .awake, startDate: Date().addingTimeInterval(-12000), endDate: Date().addingTimeInterval(-11800)),
                SleepStage(type: .deep, startDate: Date().addingTimeInterval(-11800), endDate: Date().addingTimeInterval(-6000)),
                SleepStage(type: .core, startDate: Date().addingTimeInterval(-6000), endDate: Date())
            ],
            startDate: Date().addingTimeInterval(-28880),
            endDate: Date(),
            efficiency: 0.92
        ))
    }
    .preferredColorScheme(.dark)
}
