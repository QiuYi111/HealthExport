import SwiftUI

struct SleepStagePill: View {
    let type: SleepStageType
    let duration: Int
    let percentage: Int

    var body: some View {
        HStack(spacing: 8) {
        Circle()
            .fill(type.color)
            .frame(width: 12, height: 12)

        VStack(alignment: .leading, spacing: 2) {
            Text(type.displayName)
                .font(.caption2.bold)
                .foregroundStyle(.primary)

            Text("\(duration) mins")
                .font(.caption1)
                .foregroundStyle(.secondary)
        }

        Spacer()

        Text("\(percentage)%")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(
        RoundedRectangle(cornerRadius: 10)
            .fill(type.color.opacity(0.15))
    )
}
}
