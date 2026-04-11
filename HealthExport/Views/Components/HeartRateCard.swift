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
                            .foregroundStyle(Color.heartRate)

                        Text("BPM")
                            .font(.caption)
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
                            .font(.title3.bold())
                            .foregroundStyle(Color.heartRate)
                    }

                    if let resting = data.restingBPM {
                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Resting")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("\(Int(resting)) BPM")
                                .font(.title3.bold())
                                .foregroundStyle(Color.heartRate)
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
            graphPath(for: geometry.size)
                .stroke(Color.red, style: StrokeStyle(lineWidth: 2))
        }
        .frame(height: 100)
    }

    private func graphPath(for size: CGSize) -> Path {
        guard !samples.isEmpty else {
            return Path()
        }

        let minHeight: CGFloat = 40
        let maxHeight: CGFloat = 160
        let bpmRange = maxHeight - minHeight

        let points = samples.enumerated().map { index, sample in
            CGPoint(
                x: size.width * CGFloat(index) / CGFloat(max(samples.count - 1, 1)),
                y: size.height - (CGFloat(sample.bpm - minHeight) / bpmRange) * size.height
            )
        }

        var path = Path()
        guard let firstPoint = points.first else { return path }
        path.move(to: firstPoint)

        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        return path
    }
}
