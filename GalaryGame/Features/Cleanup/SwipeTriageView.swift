import SwiftUI
import Photos

/// A batch of assets to triage, tagged with what kind of cleanup it represents.
struct TriageSession: Identifiable {
    let id = UUID()
    let type: CleanupType
    let assets: [PHAsset]
}

/// "Tinder for photos": swipe left to delete, right to keep. When the deck is
/// done, deletions are committed (system confirmation) and XP is awarded.
struct SwipeTriageView: View {
    let session: TriageSession
    let photos: PhotoLibraryService
    let store: GameStore
    var onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var drag: CGSize = .zero
    @State private var toDelete: [PHAsset] = []
    @State private var kept = 0
    @State private var committing = false

    private var remaining: [PHAsset] { Array(session.assets[min(index, session.assets.count)...]) }
    private var finished: Bool { index >= session.assets.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            if session.assets.isEmpty {
                emptyState
            } else if finished {
                summary
            } else {
                deck
                controls
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("Закрыть") { dismiss() }
            Spacer()
            Text(session.type.title).font(.headline)
            Spacer()
            Text("\(min(index + 1, session.assets.count))/\(session.assets.count)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Deck

    private var deck: some View {
        ZStack {
            ForEach(Array(remaining.prefix(3).enumerated().reversed()), id: \.element.localIdentifier) { offset, asset in
                AssetImage(asset: asset, photos: photos)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(radius: offset == 0 ? 8 : 0)
                    .scaleEffect(offset == 0 ? 1 : 1 - CGFloat(offset) * 0.04)
                    .offset(y: CGFloat(offset) * 10)
                    .offset(offset == 0 ? drag : .zero)
                    .rotationEffect(offset == 0 ? .degrees(Double(drag.width / 20)) : .zero)
                    .overlay(alignment: .top) { if offset == 0 { swipeLabel } }
                    .gesture(offset == 0 ? swipeGesture : nil)
                    .animation(.spring(duration: 0.3), value: drag)
                    .animation(.spring(duration: 0.3), value: index)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxHeight: .infinity)
    }

    private var swipeLabel: some View {
        HStack {
            Text("УДАЛИТЬ")
                .swipeBadge(Theme.danger)
                .opacity(Double(max(-drag.width, 0) / 100))
            Spacer()
            Text("ОСТАВИТЬ")
                .swipeBadge(Theme.accent)
                .opacity(Double(max(drag.width, 0) / 100))
        }
        .padding(24)
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { drag = $0.translation }
            .onEnded { value in
                if value.translation.width < -100 { decide(delete: true) }
                else if value.translation.width > 100 { decide(delete: false) }
                else { drag = .zero }
            }
    }

    private var controls: some View {
        HStack(spacing: 40) {
            circleButton("trash", Theme.danger) { decide(delete: true) }
            circleButton("checkmark", Theme.accent) { decide(delete: false) }
        }
        .padding(.bottom, 32)
    }

    // MARK: - States

    private var emptyState: some View {
        ContentUnavailableView("Здесь чисто!", systemImage: "sparkles",
            description: Text("Нечего разбирать в этой категории."))
            .frame(maxHeight: .infinity)
    }

    private var summary: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64)).foregroundStyle(Theme.accent)
            Text("Готово!").font(.largeTitle.bold())
            Text("К удалению: \(toDelete.count) · Оставлено: \(kept)")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await commit() }
            } label: {
                Text(committing ? "Удаляем…" : "Удалить \(toDelete.count) и забрать XP")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
            .disabled(committing)
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    // MARK: - Logic

    private func decide(delete: Bool) {
        guard index < session.assets.count else { return }
        if delete { toDelete.append(session.assets[index]) } else { kept += 1 }
        index += 1
        drag = .zero
    }

    private func commit() async {
        committing = true
        defer { committing = false }
        var freed: Int64 = 0
        if !toDelete.isEmpty {
            // iOS shows its own confirmation sheet here.
            freed = (try? await photos.delete(toDelete)) ?? 0
        }
        // The number of graded items depends on the cleanup type.
        let count = session.type == .screenshot ? session.assets.count : toDelete.count
        store.recordCleanup(type: session.type, count: count, bytesFreed: freed)
        if freed > 0 {
            store.recordCleanup(type: .storageFreed, count: 0, bytesFreed: freed)
        }
        onFinish()
        dismiss()
    }

    private func circleButton(_ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 64, height: 64)
                .background(Color(.secondarySystemBackground), in: Circle())
        }
    }
}

private extension View {
    func swipeBadge(_ color: Color) -> some View {
        self.font(.headline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color, in: RoundedRectangle(cornerRadius: 8))
    }
}
