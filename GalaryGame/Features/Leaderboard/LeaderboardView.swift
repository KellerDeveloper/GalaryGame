import SwiftUI

/// Opt-in cloud leaderboard. Off by default; when enabled it syncs only the
/// player's chosen name + XP + Digital Order Score, and shows the global top list.
struct LeaderboardView: View {
    let store: GameStore
    private let service = LeaderboardService()

    @State private var entries: [LeaderboardService.Entry] = []
    @State private var loading = false
    @State private var nameDraft = ""
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if !SupabaseConfig.isConfigured {
                notConfigured
            } else if store.profile.isLeaderboardEnabled {
                board
            } else {
                consent
            }
        }
        .navigationTitle("Рейтинг")
        .task { await syncIfEnabled() }
    }

    // MARK: - States

    private var notConfigured: some View {
        ContentUnavailableView(
            "Рейтинг не настроен",
            systemImage: "cloud.slash",
            description: Text("Облачный рейтинг появится, когда будут заданы ключи Supabase в SupabaseConfig.")
        )
    }

    private var consent: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "trophy")
                .font(.system(size: 60)).foregroundStyle(Theme.accent)
            Text("Соревнуйся за порядок").font(.title2.bold())
            Text("Отправляется только твоё имя, очки (XP) и рейтинг порядка. Фото и данные галереи не передаются.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)

            TextField("Имя в рейтинге", text: $nameDraft)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)

            Button {
                let name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                store.enableLeaderboard(name: name)
                Task { await syncIfEnabled() }
            } label: {
                Text("Участвовать").font(.headline)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer()
        }
    }

    private var board: some View {
        List {
            Section {
                ForEach(Array(entries.enumerated()), id: \.element.id) { rank, entry in
                    HStack(spacing: 12) {
                        Text("\(rank + 1)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(rank < 3 ? Theme.accent : .secondary)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.displayName)
                                .fontWeight(entry.playerID == store.profile.remotePlayerID ? .bold : .regular)
                            Text("Порядок \(entry.dosScore)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(entry.xp) XP").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                    }
                }
            } footer: {
                if loading { Text("Обновляем…") }
            }

            Section {
                Button("Отключить участие", role: .destructive) {
                    store.disableLeaderboard()
                    entries = []
                }
            }
        }
        .refreshable { await syncIfEnabled() }
        .overlay { if entries.isEmpty && !loading { emptyBoard } }
        .alert("Ошибка синхронизации", isPresented: .constant(errorMessage != nil)) {
            Button("Ок") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var emptyBoard: some View {
        ContentUnavailableView("Пока пусто", systemImage: "person.3",
            description: Text("Наведи порядок — и попади в топ."))
    }

    // MARK: - Sync

    private func syncIfEnabled() async {
        guard store.profile.isLeaderboardEnabled,
              SupabaseConfig.isConfigured,
              let name = store.profile.displayName else { return }
        loading = true
        defer { loading = false }
        do {
            try await service.upsert(
                playerID: store.profile.remotePlayerID,
                displayName: name,
                xp: store.profile.xp,
                dosScore: store.profile.dosScore
            )
            entries = try await service.top()
        } catch {
            errorMessage = "\(error)"
        }
    }
}
