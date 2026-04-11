import SwiftUI

struct StepsCard: View {
    let data: StepsData
    @State private var animateContent = false
    @State private var animatedCount: Int = 0

    var body: some View {
        HealthCard(
            accentColor: .steps,
            icon: "figure.walk",
            title: "Steps"
        ) {
            if !animateContent {
                ProgressRing(
                    progress: 0,
                    color: .steps,
                    lineWidth: 10,
                    size: 80
                )
                .frame(height: 80)
            } else {
                VStack(spacing: 16) {
                    // Main count
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(animatedCount.formattedWithCommas)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.steps)

                        Spacer()

                        Text("/ \(data.goal.formattedWithCommas)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.steps.opacity(0.2))
                                .frame(height: 8)

                            Capsule()
                                .fill(Color.steps)
                                .frame(width: geometry.size.width * min(data.progress, 1.0), height: 8)
                        }
                    }
                    .frame(height: 8)

                    // Distance if available
                    if let distance = data.distance {
                        HStack {
                            Image(systemName: "location")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f km", distance / 1000))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                animateContent = true
                animatedCount = data.count
            }
        }
    }
}

// MARK: - Active Energy Card

struct ActiveEnergyCard: View {
    let data: ActiveEnergyData
    @State private var animateContent = false
    @State private var animatedCalories: Double = 0

    var body: some View {
        HealthCard(
            accentColor: .activeEnergy,
            icon: "flame.fill",
            title: "Active Energy"
        ) {
            if !animateContent {
                ProgressRing(
                    progress: 0,
                    color: .activeEnergy,
                    lineWidth: 10,
                    size: 80
                )
                .frame(height: 80)
            } else {
                VStack(spacing: 16) {
                    // Main calories display
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(Int(animatedCalories))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.activeEnergy)

                        Text("CAL")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("/ \(Int(data.goal))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.activeEnergy.opacity(0.2))
                                .frame(height: 8)

                            Capsule()
                                .fill(Color.activeEnergy)
                                .frame(width: geometry.size.width * min(data.progress, 1.0), height: 8)
                        }
                    }
                    .frame(height: 8)

                    // Progress percentage
                    HStack {
                        Spacer()
                        Text("\(data.progressPercentage)% of goal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateContent = true
                animatedCalories = data.calories
            }
        }
    }
}
