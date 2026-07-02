import Foundation

/// Player ranks, unlocked by accumulating XP.
/// Order matters: `allCases` is ascending by `xpThreshold`.
enum Rank: Int, Codable, CaseIterable, Comparable, Identifiable {
    case chaos          // Хаос
    case novice         // Новичок порядка
    case organizer      // Организатор
    case minimalist     // Минималист
    case zenMaster      // Дзен-мастер

    var id: Int { rawValue }

    /// Minimum total XP required to hold this rank.
    var xpThreshold: Int {
        switch self {
        case .chaos:      return 0
        case .novice:     return 100
        case .organizer:  return 400
        case .minimalist: return 1000
        case .zenMaster:  return 2500
        }
    }

    var title: String {
        switch self {
        case .chaos:      return "Хаос"
        case .novice:     return "Новичок порядка"
        case .organizer:  return "Организатор"
        case .minimalist: return "Минималист"
        case .zenMaster:  return "Дзен-мастер"
        }
    }

    var symbolName: String {
        switch self {
        case .chaos:      return "tornado"
        case .novice:     return "leaf"
        case .organizer:  return "square.grid.2x2"
        case .minimalist: return "circle.dashed"
        case .zenMaster:  return "sparkles"
        }
    }

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The highest rank whose threshold is satisfied by `totalXP`.
    static func rank(forXP totalXP: Int) -> Rank {
        allCases.last { totalXP >= $0.xpThreshold } ?? .chaos
    }

    /// The next rank to aim for, or `nil` if already at the top.
    var next: Rank? {
        Rank(rawValue: rawValue + 1)
    }

    /// Progress in [0, 1] toward the next rank given `totalXP`.
    /// Returns 1.0 when already at the maximum rank.
    func progress(towardNextFrom totalXP: Int) -> Double {
        guard let next else { return 1.0 }
        let span = Double(next.xpThreshold - xpThreshold)
        guard span > 0 else { return 1.0 }
        let gained = Double(totalXP - xpThreshold)
        return min(max(gained / span, 0), 1)
    }
}
