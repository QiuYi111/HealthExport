import SwiftUI

struct HeartRateCard: View {
    let data: HeartRateData
    @State private var animateContent = false
    @State private var currentBPM: Double = 0

    var body: some View {
        HealthCard(
            accentColor: .heartRate,
            icon: "heart.fill",
            title: "Heart Rate"
        ) {
            if !animateContent {
                ProgressRing(
                    progress: 0,
                    color: .heartRate,
                    lineWidth: 8,
                    size: 60
                )
                .frame(height: 60)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Main BPM display
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(currentBPM))")
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundStyle(.heartRate)
                                    .contentTransition(
                                        numericValue: currentBPM,
                                        from: 0,
                                        using: .spring(response: 0.5, dampingFraction: 0.7)
                                    )

                                Text("BPM")
                                    .font(.caption1)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                            }

                            Spacer()

                            // Range
                            VStack(alignment: .trailing) {
                                Text("Today's Range")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text(data.range)
                                    .font(.title3.bold)
                                    .foregroundStyle(.heartRate)
                            }

                            if let resting = data.restingBPM {
                                Spacer()

                                VStack(alignment: .trailing) {
                                    Text("Resting")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Text("\(Int(resting)) BPM")
                                        .font(.title3.bold)
                                        .foregroundStyle(.heartRate)
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                    animateContent = true
                    currentBPM = data.currentBPM
                }
            }
    }
}

// MARK: - Heart Rate Graph

struct HeartRateGraphView: View {
    let samples: [HeartRateSample]

    var body: some View {
        GeometryReader { geometry in
            Path(
                (graphPath(for: geometry.size.width)
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 2))
            )
        }
        .frame(height: 100)
    }

    private func graphPath(for width: CGFloat) -> Path {
        guard !samples.isEmpty else {
            return Path()
        }

        let points = samples.enumerated().map { sample in
            CGPoint(
                x: width * CGFloat(sample.date.timeIntervalSince1970) / 86400,
                y: 100 - CGFloat(sample.bpm)
            )
        }

        var path = Path()
        var previousPoint: CGPoint?

        for point in points {
            if let prev = previousPoint {
                path = path.cgPath.move(to: prev)
                path = path.cgPath.addLine(to: point)
            }
            previousPoint = point
        }

        return path
    }
}

// MARK: - Color Extensions

extension Color {
    static let sleep = Color(red: 0.5, green: 0.3, blue: 0.9)
    static let heartRate = Color(red: 0.95, green: 0.3, blue: 0.4)
    static let steps = Color(red: 0.2, green: 0.85, blue: 0.4)
    static let activeEnergy = Color(red: 1.0, green: 0.6, blue: 0.2)
}
