import SwiftUI
import Photos

/// The home screen: DOS ring, rank, streak, daily quests and cleanup actions.
struct DashboardView: View {
    let store: GameStore
    let photos: PhotoLibraryService

    @State private var model: DashboardViewModel
    @State private var triage: TriageSession?
    @State private var showAlbumSort = false

    init(store: GameStore, photos: PhotoLibraryService) {
        self.store = store
        self.photos = photos
        _model = State(initialValue: DashboardViewModel(photos: photos, store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    scoreHeader
                    rankCard
                    questsCard
                    actionsCard
                }
                .padding()
            }
            .navigationTitle("Trash Panda")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if model.isScanning { ProgressView() }
                }
            }
            .task { if model.metrics.totalPhotos == 0 { await model.quickScan() } }
            .refreshable { await model.quickScan() }
            .fullScreenCover(item: $triage) { session in
                SwipeTriageView(session: session, photos: photos, store: store) {
                    Task { await model.quickScan() }
                }
            }
            .fullScreenCover(isPresented: $showAlbumSort) {
                AlbumSortView(assets: model.unsortedAssets, photos: photos, store: store) {
                    Task { await model.quickScan() }
                }
            }
        }
    }

    // MARK: - Sections

    private var scoreHeader: some View {
        VStack(spacing: 8) {
            DOSRing(score: store.profile.dosScore)
                .frame(width: 180, height: 180)
            Text("\(model.metrics.totalPhotos) фото · \(Theme.format(bytes: store.profile.storageFreedBytes)) освобождено")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var rankCard: some View {
        Card {
            HStack(spacing: 16) {
                Image(systemName: store.profile.rank.symbolName)
                    .font(.title)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .background(Theme.accentSoft, in: Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.profile.rank.title).font(.headline)
                    ProgressView(value: store.profile.rankProgress)
                        .tint(Theme.accent)
                    Text("\(store.profile.xp) XP")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill").foregroundStyle(Theme.warn)
                    Text("\(store.profile.streakCount)").font(.headline)
                    Text("дней").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var questsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Задания дня").font(.headline)
                ForEach(store.todaysQuests) { quest in
                    HStack(spacing: 12) {
                        Image(systemName: quest.symbolName)
                            .foregroundStyle(quest.isCompleted ? Theme.accent : .secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(quest.title)
                                .font(.subheadline)
                                .strikethrough(quest.isCompleted)
                            ProgressView(value: quest.fractionComplete).tint(Theme.accent)
                        }
                        Text("+\(quest.rewardXP)")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
    }

    private var actionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Убраться").font(.headline)
                actionButton("iphone", "Разобрать скриншоты", count: model.screenshotAssets.count) {
                    triage = TriageSession(type: .screenshot, assets: model.screenshotAssets)
                }
                actionButton("rectangle.stack.badge.plus", "Разложить по альбомам", count: model.unsortedAssets.count) {
                    showAlbumSort = true
                }
                actionButton("square.on.square", "Найти дубликаты", count: nil) {
                    Task {
                        let dupes = await model.findDuplicates()
                        triage = TriageSession(type: .duplicate, assets: dupes)
                    }
                }
                actionButton("camera.filters", "Найти размытые", count: nil) {
                    Task {
                        let blurry = await model.findBlurry()
                        triage = TriageSession(type: .blurry, assets: blurry)
                    }
                }
            }
        }
    }

    private func actionButton(_ symbol: String, _ title: String, count: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: symbol).frame(width: 24)
                Text(title)
                Spacer()
                if let count { Text("\(count)").foregroundStyle(.secondary) }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isScanning)
    }
}
