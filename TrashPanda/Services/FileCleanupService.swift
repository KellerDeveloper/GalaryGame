import Foundation
import CryptoKit

/// Scans a user-picked folder (iCloud Drive / On My iPhone) for "junk" files and
/// deletes the ones the user confirms. iOS sandboxes the filesystem, so this only
/// ever touches the folder the user explicitly granted via the document picker.
struct FileCleanupService {

    /// Why a file was flagged. A file is reported under exactly one reason,
    /// with priority duplicate > large > old.
    enum Reason: String {
        case large, old, duplicate

        var title: String {
            switch self {
            case .large:     return "Крупный"
            case .old:       return "Старый"
            case .duplicate: return "Дубликат"
            }
        }
        var symbolName: String {
            switch self {
            case .large:     return "doc.badge.gearshape"
            case .old:       return "calendar.badge.clock"
            case .duplicate: return "doc.on.doc"
            }
        }
    }

    struct FileItem: Identifiable, Hashable {
        let id = UUID()
        let url: URL
        let size: Int64
        let modified: Date
        let reason: Reason
    }

    var largeThreshold: Int64 = 50 * 1_024 * 1_024      // 50 MB
    var oldThreshold: TimeInterval = 365 * 24 * 3_600   // 1 year

    /// Enumerate regular files under `folder` and flag junk.
    /// `now` is injectable for deterministic tests.
    func scan(folder: URL, now: Date = .now) throws -> [FileItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        struct Raw { let url: URL; let size: Int64; let modified: Date }
        var raws: [Raw] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else { continue }
            raws.append(Raw(
                url: url,
                size: Int64(values.fileSize ?? 0),
                modified: values.contentModificationDate ?? now
            ))
        }

        let duplicateURLs = duplicateFileURLs(among: raws.map { ($0.url, $0.size) })

        var items: [FileItem] = []
        for raw in raws {
            let reason: Reason?
            if duplicateURLs.contains(raw.url) {
                reason = .duplicate
            } else if raw.size >= largeThreshold {
                reason = .large
            } else if now.timeIntervalSince(raw.modified) >= oldThreshold {
                reason = .old
            } else {
                reason = nil
            }
            if let reason {
                items.append(FileItem(url: raw.url, size: raw.size, modified: raw.modified, reason: reason))
            }
        }
        return items.sorted { $0.size > $1.size }
    }

    /// Delete the given files. Returns total bytes freed.
    /// The caller is responsible for holding the security-scoped access.
    @discardableResult
    func delete(_ items: [FileItem]) throws -> Int64 {
        let fm = FileManager.default
        var freed: Int64 = 0
        for item in items {
            try fm.removeItem(at: item.url)
            freed += item.size
        }
        return freed
    }

    // MARK: - Duplicate detection

    /// Files that duplicate an earlier file (same size AND same content hash).
    /// The first occurrence in each group is kept; the rest are returned.
    private func duplicateFileURLs(among files: [(url: URL, size: Int64)]) -> Set<URL> {
        var bySize: [Int64: [URL]] = [:]
        for f in files where f.size > 0 { bySize[f.size, default: []].append(f.url) }

        var duplicates = Set<URL>()
        for (_, urls) in bySize where urls.count > 1 {
            var seenHashes = Set<String>()
            for url in urls {
                guard let hash = try? contentHash(of: url) else { continue }
                if seenHashes.contains(hash) {
                    duplicates.insert(url)
                } else {
                    seenHashes.insert(hash)
                }
            }
        }
        return duplicates
    }

    private func contentHash(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
