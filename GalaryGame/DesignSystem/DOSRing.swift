import SwiftUI

/// Circular gauge for the Digital Order Score (0...100).
struct DOSRing: View {
    let score: Int
    var lineWidth: CGFloat = 16

    private var fraction: Double { Double(min(max(score, 0), 100)) / 100 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.tertiarySystemFill), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    Theme.scoreColor(score),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: fraction)
            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("Порядок")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
