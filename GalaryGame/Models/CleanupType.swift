import Foundation

/// A single kind of "tidy up" action the player can perform.
/// Each type carries its own XP reward so the scoring rules live in one place.
enum CleanupType: String, Codable, CaseIterable, Identifiable {
    case duplicate      // deleted a near-duplicate photo
    case blurry         // deleted a blurry / low-quality photo
    case screenshot     // triaged (kept or deleted) a screenshot
    case sortToAlbum    // moved a photo into an album
    case emptyTrash     // emptied "Recently Deleted"
    case storageFreed   // freed storage (scored per 100 MB, handled separately)

    var id: String { rawValue }

    /// Base XP awarded per unit of this action.
    var baseXP: Int {
        switch self {
        case .duplicate:    return 5
        case .blurry:       return 5
        case .screenshot:   return 3
        case .sortToAlbum:  return 2
        case .emptyTrash:   return 20
        case .storageFreed: return 1   // per 100 MB, see ScoringEngine
        }
    }

    var title: String {
        switch self {
        case .duplicate:    return "Дубликат удалён"
        case .blurry:       return "Размытое удалено"
        case .screenshot:   return "Скриншот разобран"
        case .sortToAlbum:  return "Фото в альбоме"
        case .emptyTrash:   return "Корзина очищена"
        case .storageFreed: return "Место освобождено"
        }
    }

    var symbolName: String {
        switch self {
        case .duplicate:    return "square.on.square"
        case .blurry:       return "camera.filters"
        case .screenshot:   return "iphone"
        case .sortToAlbum:  return "rectangle.stack.badge.plus"
        case .emptyTrash:   return "trash"
        case .storageFreed: return "internaldrive"
        }
    }
}
