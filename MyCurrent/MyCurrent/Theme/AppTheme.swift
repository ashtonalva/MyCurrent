import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.22, green: 0.79, blue: 0.95)
    static let screenBackground = Color(uiColor: .systemGroupedBackground)
    static let tabBarBackground = Color(uiColor: .secondarySystemBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let cardOverlay = LinearGradient(
        colors: [Color.cyan.opacity(0.12), Color.blue.opacity(0.06), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let warningBackground = Color.orange.opacity(0.16)
    static let recommendationBackground = Color.blue.opacity(0.12)
    static let oceanBackground = LinearGradient(
        colors: [
            Color(red: 0.34, green: 0.73, blue: 0.90),
            Color(red: 0.09, green: 0.38, blue: 0.60),
            Color(red: 0.01, green: 0.08, blue: 0.18)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let formRowBackground = Color.white.opacity(0.08)
    static let sectionHeader = Color.cyan.opacity(0.9)

    static func oceanStateColor(_ state: String) -> Color {
        switch state {
        case "Calm Waters":
            return Color.teal
        case "Steady Current":
            return Color.blue
        case "Choppy Tide":
            return Color.indigo
        default:
            return Color.orange
        }
    }

    static func oceanBackground(for state: String) -> LinearGradient {
        switch state {
        case "Calm Waters":
            return LinearGradient(
                colors: [
                    Color(red: 0.54, green: 0.83, blue: 0.96),
                    Color(red: 0.19, green: 0.57, blue: 0.76),
                    Color(red: 0.02, green: 0.20, blue: 0.36)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case "Steady Current":
            return LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.78, blue: 0.93),
                    Color(red: 0.14, green: 0.47, blue: 0.68),
                    Color(red: 0.01, green: 0.13, blue: 0.27)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case "Choppy Tide":
            return LinearGradient(
                colors: [
                    Color(red: 0.29, green: 0.56, blue: 0.74),
                    Color(red: 0.06, green: 0.28, blue: 0.45),
                    Color(red: 0.01, green: 0.08, blue: 0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            return LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.18, blue: 0.27),
                    Color(red: 0.03, green: 0.10, blue: 0.20),
                    Color(red: 0.00, green: 0.03, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
