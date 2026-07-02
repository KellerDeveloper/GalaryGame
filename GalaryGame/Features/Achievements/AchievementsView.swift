import SwiftUI

/// Grid of every badge, showing locked vs. unlocked state.
struct AchievementsView: View {
    let store: GameStore

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                let unlocked = store.unlockedAchievementIDs
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AchievementID.allCases) { id in
                        badge(id, isUnlocked: unlocked.contains(id))
                    }
                }
                .padding()
            }
            .navigationTitle("Награды")
        }
    }

    private func badge(_ id: AchievementID, isUnlocked: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: id.symbolName)
                .font(.system(size: 34))
                .foregroundStyle(isUnlocked ? Theme.accent : .secondary)
                .frame(width: 64, height: 64)
                .background(isUnlocked ? Theme.accentSoft : Color(.tertiarySystemFill), in: Circle())
            Text(id.title)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
            Text(id.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(isUnlocked ? 1 : 0.55)
        .overlay(alignment: .topTrailing) {
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.caption).foregroundStyle(.secondary).padding(10)
            }
        }
    }
}
