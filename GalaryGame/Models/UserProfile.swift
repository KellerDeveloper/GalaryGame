import Foundation
import SwiftData

/// The single persisted profile for the player. There is exactly one instance.
@Model
final class UserProfile {
    /// Total accumulated experience points.
    var xp: Int
    /// Most recently computed Digital Order Score (0...100).
    var dosScore: Int
    /// Current consecutive-day streak.
    var streakCount: Int
    /// Start of the last day (midnight) the player performed an action.
    var lastActiveDay: Date?
    /// Lifetime bytes freed across all cleanups.
    var storageFreedBytes: Int64
    /// Remaining "streak freeze" tokens that protect the streak on a missed day.
    var streakFreezes: Int
    /// When the profile was first created.
    var createdAt: Date

    init(
        xp: Int = 0,
        dosScore: Int = 0,
        streakCount: Int = 0,
        lastActiveDay: Date? = nil,
        storageFreedBytes: Int64 = 0,
        streakFreezes: Int = 1,
        createdAt: Date = .now
    ) {
        self.xp = xp
        self.dosScore = dosScore
        self.streakCount = streakCount
        self.lastActiveDay = lastActiveDay
        self.storageFreedBytes = storageFreedBytes
        self.streakFreezes = streakFreezes
        self.createdAt = createdAt
    }

    /// Current rank derived from XP.
    var rank: Rank { Rank.rank(forXP: xp) }

    /// Progress toward the next rank in [0, 1].
    var rankProgress: Double { rank.progress(towardNextFrom: xp) }
}
