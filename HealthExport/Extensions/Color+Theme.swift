import SwiftUI

// MARK: - Color Theme

extension Color {
    // Sleep - Purple/Indigo
    static let sleep = Color(
        red: 147 / 255,
        green: 112 / 255,
        blue: 219 / 255
    )

    // Heart Rate - Red/Pink
    static let heartRate = Color(
        red: 255 / 255,
        green: 100 / 255,
        blue: 130 / 255
    )

    // Steps - Green
    static let steps = Color(
        red: 52 / 255,
        green: 199 / 255,
        blue: 89 / 255
    )

    // Active Energy - Orange
    static let activeEnergy = Color(
        red: 255 / 255,
        green: 159 / 255,
        blue: 10 / 255
    )

    // Background colors for dark theme
    static let deepNavy = Color(
        red: 12 / 255,
        green: 15 / 255,
        blue: 26 / 255
    )

    static let cardBackground = Color(
        red: 28 / 255,
        green: 32 / 255,
        blue: 45 / 255
    )

    static let cardBackgroundSecondary = Color(
        red: 38 / 255,
        green: 42 / 255,
        blue: 58 / 255
    )
}

// MARK: - Gradient Helpers

extension Color {
    func gradient(isVertical: Bool = true) -> LinearGradient {
        LinearGradient(
            colors: [self, self.opacity(0.6)],
            startPoint: isVertical ? .top : .leading,
            endPoint: isVertical ? .bottom : .trailing
        )
    }

    static func gradient(from: Color, to: Color, isVertical: Bool = true) -> LinearGradient {
        LinearGradient(
            colors: [from, to],
            startPoint: isVertical ? .top : .leading,
            endPoint: isVertical ? .bottom : .trailing
        )
    }
}
