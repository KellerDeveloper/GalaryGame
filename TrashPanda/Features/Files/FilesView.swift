import SwiftUI
import UniformTypeIdentifiers

/// "Files" cleanup: pick a folder in the Files app, scan it for junk (large /
/// old / duplicate files) and delete what the user selects. Freed space awards XP.
struct FilesView: View {
    let store: GameStore
    private let service = FileCleanupService()

    @State private var showImporter = false
    @State private var scannedFolder: URL?
    @State private var items: [FileCleanupService.FileItem] = []
    @State private var selected = Set<UUID>()
    @State private var scanning = false
    @State private var errorMessage: String?

    private var selectedItems: [FileCleanupService.FileItem] {
        items.filter { selected.contains($0.id) }
    }
    private var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        NavigationStack {
            Group {
                if scanning {
                    ProgressView("Сканируем…").frame(maxHeight: .infinity)
                } else if items.isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .navigationTitle("Файлы")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Выбрать папку") { showImporter = true }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.folder]) { result in
                handlePick(result)
            }
            .safeAreaInset(edge: .bottom) {
                if !selectedItems.isEmpty { deleteBar }
            }
            .alert("Ошибка", isPresented: .constant(errorMessage != nil)) {
                Button("Ок") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    // MARK: - Sections

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Разбери файлы", systemImage: "folder.badge.gearshape")
        } description: {
            Text("Выбери папку в «Файлах» (iCloud Drive или «На iPhone») — найдём крупные, старые и дублирующиеся файлы.\n\niOS не даёт доступ к общей папке «Загрузки» и кэшу мессенджеров, поэтому сканируем только выбранную папку.")
        } actions: {
            Button("Выбрать папку") { showImporter = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
    }

    private var fileList: some View {
        List(items) { item in
            Button {
                toggle(item)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selected.contains(item.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected.contains(item.id) ? Theme.accent : .secondary)
                    Image(systemName: item.reason.symbolName)
                        .foregroundStyle(.secondary).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.url.lastPathComponent).lineLimit(1)
                        Text("\(item.reason.title) · \(Theme.format(bytes: item.size))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var deleteBar: some View {
        Button {
            deleteSelected()
        } label: {
            Text("Удалить \(selectedItems.count) · освободит \(Theme.format(bytes: selectedBytes))")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .background(Theme.danger, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(.white)
        .padding()
        .background(.thinMaterial)
    }

    // MARK: - Logic

    private func toggle(_ item: FileCleanupService.FileItem) {
        if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
    }

    private func handlePick(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            scannedFolder.map { $0.stopAccessingSecurityScopedResource() }
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Нет доступа к папке."
                return
            }
            scannedFolder = url
            selected.removeAll()
            Task {
                scanning = true
                defer { scanning = false }
                do { items = try service.scan(folder: url) }
                catch { errorMessage = error.localizedDescription; items = [] }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSelected() {
        let toDelete = selectedItems
        do {
            let freed = try service.delete(toDelete)
            store.recordCleanup(type: .storageFreed, count: toDelete.count, bytesFreed: freed)
            let deletedIDs = Set(toDelete.map(\.id))
            items.removeAll { deletedIDs.contains($0.id) }
            selected.removeAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
