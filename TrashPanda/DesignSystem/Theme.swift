import SwiftUI

/// Central palette and small style helpers so the app reads as one system.
enum Theme {
    static let accent = Color(red: 0.20, green: 0.78, blue: 0.55)   // fresh green
    static let accentSoft = Color(red: 0.20, green: 0.78, blue: 0.55).opacity(0.15)
    static let warn = Color(red: 0.95, green: 0.61, blue: 0.24)     // amber
    static let danger = Color(red: 0.92, green: 0.34, blue: 0.36)   // red

    /// Color for a Digital Order Score, red → amber → green.
    static func scoreColor(_ score: Int) -> Color {
        switch score {
        case ..<40: return danger
        case 40..<70: return warn
        default: return accent
        }
    }

    static func format(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// A soft card container used across screens.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
