import Foundation
import SwiftData

/// Stable identifiers for every badge the game can award.
enum AchievementID: String, CaseIterable, Identifiable {
    case firstClean          // very first cleanup action
    case hundredDuplicates   // deleted 100 duplicates lifetime
    case photoInboxZero      // 0 unsorted photos
    case weekStreak          // 7-day streak
    case freedOneGig         // freed 1 GB lifetime
    case screenshotSlayer    // triaged 200 screenshots

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstClean:        return "Первый шаг"
        case .hundredDuplicates: return "Охотник за дубликатами"
        case .photoInboxZero:    return "Photo Inbox Zero"
        case .weekStreak:        return "Неделя без мусора"
        case .freedOneGig:       return "Освободил гигабайт"
        case .screenshotSlayer:  return "Гроза скриншотов"
        }
    }

    var detail: String {
        switch self {
        case .firstClean:        return "Сделай первое действие по уборке"
        case .hundredDuplicates: return "Удали 100 дубликатов"
        case .photoInboxZero:    return "Разложи все фото по альбомам"
        case .weekStreak:        return "Убирайся 7 дней подряд"
        case .freedOneGig:       return "Освободи 1 ГБ памяти"
        case .screenshotSlayer:  return "Разбери 200 скриншотов"
        }
    }

    var symbolName: String {
        switch self {
        case .firstClean:        return "figure.walk"
        case .hundredDuplicates: return "square.on.square.dashed"
        case .photoInboxZero:    return "tray.full"
        case .weekStreak:        return "flame"
        case .freedOneGig:       return "externaldrive.badge.checkmark"
        case .screenshotSlayer:  return "bolt.shield"
        }
    }
}

/// Persisted record that a given achievement was unlocked.
@Model
final class Achievement {
    /// `AchievementID.rawValue`; unique per profile.
    @Attribute(.unique) var idRaw: String
    var unlockedDate: Date

    init(id: AchievementID, unlockedDate: Date = .now) {
        self.idRaw = id.rawValue
        self.unlockedDate = unlockedDate
    }

    var achievementID: AchievementID? { AchievementID(rawValue: idRaw) }
}
