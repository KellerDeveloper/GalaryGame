import SwiftUI

/// The "digital garden": a reward space that visibly flourishes as the player's
/// Digital Order Score climbs. Gives cleanup a tangible, emotional payoff.
struct GardenView: View {
    let store: GameStore

    /// Score-driven growth stage 0...4.
    private var stage: Int {
        switch store.profile.dosScore {
        case ..<20: return 0
        case 20..<40: return 1
        case 40..<60: return 2
        case 60..<80: return 3
        default: return 4
        }
    }

    private let stageTitles = ["Пустошь", "Ростки", "Кусты", "Цветение", "Райский сад"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Theme.accentSoft, .clear],
                            startPoint: .top, endPoint: .bottom))
                        .frame(width: 240, height: 240)

                    // Plants grow in number and size with the score.
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(0..<max(stage + 1, 1), id: \.self) { i in
                            Image(systemName: plantSymbol(i))
                                .font(.system(size: 30 + CGFloat(stage) * 8))
                                .foregroundStyle(Theme.accent)
                                .symbolEffect(.bounce, value: stage)
                        }
                    }
                }

                Text(stageTitles[stage])
                    .font(.largeTitle.bold())
                Text("Порядок \(store.profile.dosScore)/100 растит твой сад")
                    .foregroundStyle(.secondary)

                Card {
                    HStack {
                        stat("Уровень", store.profile.rank.title)
                        Divider()
                        stat("Освобождено", Theme.format(bytes: store.profile.storageFreedBytes))
                        Divider()
                        stat("Стрик", "\(store.profile.streakCount) дн.")
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Сад порядка")
        }
    }

    private func plantSymbol(_ i: Int) -> String {
        let symbols = ["leaf.fill", "camera.macro", "tree.fill", "laurel.leading", "sparkles"]
        return symbols[min(i, symbols.count - 1)]
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.subheadline.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
