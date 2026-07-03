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

    // MARK: Cloud leaderboard (opt-in, scores only)

    /// Stable anonymous id used as this player's leaderboard row key.
    var remotePlayerID: UUID = UUID()
    /// Public display name shown on the leaderboard (nil until chosen).
    var displayName: String?
    /// Whether the player opted in to sync their score to the cloud leaderboard.
    var isLeaderboardEnabled: Bool = false

    init(
        xp: Int = 0,
        dosScore: Int = 0,
        streakCount: Int = 0,
        lastActiveDay: Date? = nil,
        storageFreedBytes: Int64 = 0,
        streakFreezes: Int = 1,
        createdAt: Date = .now,
        remotePlayerID: UUID = UUID(),
        displayName: String? = nil,
        isLeaderboardEnabled: Bool = false
    ) {
        self.xp = xp
        self.dosScore = dosScore
        self.streakCount = streakCount
        self.lastActiveDay = lastActiveDay
        self.storageFreedBytes = storageFreedBytes
        self.streakFreezes = streakFreezes
        self.createdAt = createdAt
        self.remotePlayerID = remotePlayerID
        self.displayName = displayName
        self.isLeaderboardEnabled = isLeaderboardEnabled
    }

    /// Current rank derived from XP.
    var rank: Rank { Rank.rank(forXP: xp) }

    /// Progress toward the next rank in [0, 1].
    var rankProgress: Double { rank.progress(towardNextFrom: xp) }
}
