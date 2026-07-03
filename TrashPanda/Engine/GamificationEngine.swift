import Foundation

/// Aggregate lifetime stats used to evaluate achievement unlocks.
struct PlayerStats: Equatable {
    var duplicatesDeleted: Int = 0
    var screenshotsTriaged: Int = 0
    var storageFreedBytes: Int64 = 0
    var streakCount: Int = 0
    var unsortedPhotos: Int = 0
    var totalActions: Int = 0
    /// Photos moved into albums, lifetime.
    var photosSorted: Int = 0
}

/// The outcome of applying a day's activity to a streak.
struct StreakResult: Equatable {
    var newStreak: Int
    var remainingFreezes: Int
    /// True when a streak freeze was consumed to bridge a single missed day.
    var usedFreeze: Bool
}

/// Pure gamification rules: streaks, ranks and achievement evaluation.
/// No PhotoKit / SwiftData dependencies so it can be unit-tested directly.
enum GamificationEngine {

    /// Update a streak given the last active day and "today".
    /// - Same day: streak unchanged.
    /// - Consecutive day: +1.
    /// - Exactly one missed day with a freeze available: freeze is consumed,
    ///   streak continues (+1 for today).
    /// - Otherwise: streak resets to 1.
    static func updateStreak(
        lastActiveDay: Date?,
        today: Date,
        currentStreak: Int,
        freezes: Int,
        calendar: Calendar = .current
    ) -> StreakResult {
        let today = calendar.startOfDay(for: today)
        guard let last = lastActiveDay.map({ calendar.startOfDay(for: $0) }) else {
            return StreakResult(newStreak: 1, remainingFreezes: freezes, usedFreeze: false)
        }

        let days = calendar.dateComponents([.day], from: last, to: today).day ?? 0
        switch days {
        case ...0:
            // Same day (or clock skew) — no change.
            return StreakResult(newStreak: max(currentStreak, 1), remainingFreezes: freezes, usedFreeze: false)
        case 1:
            return StreakResult(newStreak: currentStreak + 1, remainingFreezes: freezes, usedFreeze: false)
        case 2 where freezes > 0:
            // One missed day, bridged by a freeze.
            return StreakResult(newStreak: currentStreak + 1, remainingFreezes: freezes - 1, usedFreeze: true)
        default:
            return StreakResult(newStreak: 1, remainingFreezes: freezes, usedFreeze: false)
        }
    }

    /// Returns true if a rank-up happened between two XP totals.
    static func didRankUp(from oldXP: Int, to newXP: Int) -> Bool {
        Rank.rank(forXP: newXP) > Rank.rank(forXP: oldXP)
    }

    /// Evaluate which achievements should be unlocked given current stats.
    /// Returns every qualifying id; callers skip those already persisted.
    static func unlockedAchievements(for stats: PlayerStats) -> Set<AchievementID> {
        var result: Set<AchievementID> = []
        if stats.totalActions >= 1 { result.insert(.firstClean) }
        if stats.duplicatesDeleted >= 100 { result.insert(.hundredDuplicates) }
        if stats.unsortedPhotos == 0 && stats.totalActions > 0 { result.insert(.photoInboxZero) }
        if stats.streakCount >= 7 { result.insert(.weekStreak) }
        if stats.storageFreedBytes >= 1_024 * 1_024 * 1_024 { result.insert(.freedOneGig) }
        if stats.screenshotsTriaged >= 200 { result.insert(.screenshotSlayer) }
        if stats.streakCount >= 100 { result.insert(.hundredDayStreak) }
        if stats.storageFreedBytes >= 10 * 1_024 * 1_024 * 1_024 { result.insert(.freedTenGigs) }
        if stats.photosSorted >= 100 { result.insert(.sortedHundred) }
        return result
    }
}
