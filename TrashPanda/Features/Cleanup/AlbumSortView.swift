import SwiftUI
import Photos

/// One-photo-at-a-time flow for distributing unsorted photos into albums.
/// Each assignment awards `sortToAlbum` XP and advances to the next photo.
struct AlbumSortView: View {
    let assets: [PHAsset]
    let photos: PhotoLibraryService
    let store: GameStore
    var onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var albums: [PhotoLibraryService.AlbumInfo] = []
    @State private var sortedCount = 0
    @State private var skipped = 0
    @State private var busy = false
    @State private var showNewAlbum = false
    @State private var newAlbumName = ""

    private var finished: Bool { index >= assets.count }
    private var current: PHAsset? { finished ? nil : assets[index] }

    var body: some View {
        VStack(spacing: 0) {
            header
            if assets.isEmpty {
                ContentUnavailableView("Всё разложено!", systemImage: "rectangle.stack.badge.checkmark",
                    description: Text("Нет фото без альбома."))
                    .frame(maxHeight: .infinity)
            } else if finished {
                summary
            } else {
                photo
                albumPicker
            }
        }
        .background(Color(.systemGroupedBackground))
        .task { albums = photos.userAlbums() }
        .alert("Новый альбом", isPresented: $showNewAlbum) {
            TextField("Название", text: $newAlbumName)
            Button("Отмена", role: .cancel) { newAlbumName = "" }
            Button("Создать") { Task { await createAndAssign() } }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Button("Закрыть") { finishUp() }
            Spacer()
            Text("В альбомы").font(.headline)
            Spacer()
            Text("\(min(index + 1, assets.count))/\(assets.count)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding()
    }

    private var photo: some View {
        Group {
            if let current {
                AssetImage(asset: current, photos: photos)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private var albumPicker: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        showNewAlbum = true
                    } label: {
                        chipLabel("＋ Новый", symbol: "plus.rectangle.on.rectangle", highlighted: true)
                    }
                    ForEach(albums) { album in
                        Button {
                            Task { await assign(to: album.collection) }
                        } label: {
                            chipLabel("\(album.title) · \(album.count)", symbol: "rectangle.stack")
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            Button("Пропустить") { skipped += 1; advance() }
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
        .disabled(busy)
    }

    private func chipLabel(_ text: String, symbol: String, highlighted: Bool = false) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text).lineLimit(1)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(highlighted ? Theme.accentSoft : Color(.secondarySystemBackground),
                    in: Capsule())
        .foregroundStyle(highlighted ? Theme.accent : .primary)
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.checkmark")
                .font(.system(size: 64)).foregroundStyle(Theme.accent)
            Text("Разложено: \(sortedCount)").font(.largeTitle.bold())
            if skipped > 0 { Text("Пропущено: \(skipped)").foregroundStyle(.secondary) }
            Spacer()
            Button {
                finishUp()
            } label: {
                Text("Готово").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    // MARK: - Logic

    private func assign(to collection: PHAssetCollection) async {
        guard let asset = current else { return }
        busy = true
        defer { busy = false }
        do {
            try await photos.addAssets([asset], to: collection)
            store.recordCleanup(type: .sortToAlbum, count: 1)
            sortedCount += 1
            advance()
        } catch {
            // Non-fatal: leave the photo in place for another try.
        }
    }

    private func createAndAssign() async {
        let name = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
        newAlbumName = ""
        guard !name.isEmpty, let asset = current else { return }
        busy = true
        defer { busy = false }
        do {
            let collection = try await photos.createAlbum(titled: name)
            try await photos.addAssets([asset], to: collection)
            store.recordCleanup(type: .sortToAlbum, count: 1)
            sortedCount += 1
            albums = photos.userAlbums()
            advance()
        } catch {
            // Ignore; user can retry.
        }
    }

    private func advance() { index += 1 }

    private func finishUp() {
        onFinish()
        dismiss()
    }
}
