import Foundation
import SwiftData

/// Feedback returned after recording a cleanup, so the UI can celebrate.
struct CleanupOutcome {
    var xpGained: Int
    var didRankUp: Bool
    var newRank: Rank
    var unlocked: [AchievementID]
}

/// Central coordinator between SwiftData persistence and the pure engines.
/// All game-state mutations flow through here.
@MainActor
@Observable
final class GameStore {

    let modelContext: ModelContext
    private(set) var profile: UserProfile
    private var calendar: Calendar { .current }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.profile = Self.loadOrCreateProfile(in: modelContext)
        ensureTodaysQuests()
    }

    // MARK: - Bootstrap

    private static func loadOrCreateProfile(in context: ModelContext) -> UserProfile {
        let existing = try? context.fetch(FetchDescriptor<UserProfile>())
        if let profile = existing?.first { return profile }
        let profile = UserProfile()
        context.insert(profile)
        try? context.save()
        return profile
    }

    /// Generate today's quests once per calendar day.
    func ensureTodaysQuests() {
        let today = calendar.startOfDay(for: .now)
        let descriptor = FetchDescriptor<Quest>(predicate: #Predicate { $0.day == today })
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        for quest in QuestFactory.quests(for: today) {
            modelContext.insert(quest)
        }
        try? modelContext.save()
    }

    var todaysQuests: [Quest] {
        let today = calendar.startOfDay(for: .now)
        let descriptor = FetchDescriptor<Quest>(predicate: #Predicate { $0.day == today })
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Recording cleanups

    /// Record a batch of cleanup work: awards XP, logs an event, advances the
    /// streak, progresses quests and unlocks achievements. Returns UI feedback.
    @discardableResult
    func recordCleanup(type: CleanupType, count: Int, bytesFreed: Int64 = 0) -> CleanupOutcome {
        let xp = ScoringEngine.xp(for: type, count: count, bytesFreed: bytesFreed)
        let oldXP = profile.xp

        // Log the event.
        let event = CleanupEvent(type: type, count: count, bytesFreed: bytesFreed, xpEarned: xp)
        modelContext.insert(event)

        // Apply to profile.
        profile.xp += xp
        profile.storageFreedBytes += bytesFreed

        // Streak.
        let streak = GamificationEngine.updateStreak(
            lastActiveDay: profile.lastActiveDay,
            today: .now,
            currentStreak: profile.streakCount,
            freezes: profile.streakFreezes
        )
        profile.streakCount = streak.newStreak
        profile.streakFreezes = streak.remainingFreezes
        profile.lastActiveDay = calendar.startOfDay(for: .now)

        advanceQuests(for: type, by: count, bytesFreed: bytesFreed)
        let unlocked = evaluateAchievements()

        try? modelContext.save()

        return CleanupOutcome(
            xpGained: xp,
            didRankUp: GamificationEngine.didRankUp(from: oldXP, to: profile.xp),
            newRank: profile.rank,
            unlocked: unlocked
        )
    }

    /// Recompute and persist the Digital Order Score from fresh metrics.
    func updateScore(from metrics: GalleryMetrics) {
        profile.dosScore = ScoringEngine.digitalOrderScore(from: metrics)
        try? modelContext.save()
    }

    // MARK: - Quests

    private func advanceQuests(for type: CleanupType, by count: Int, bytesFreed: Int64) {
        // Storage quests are measured in MB, others in item count.
        let increment = type == .storageFreed ? Int(bytesFreed / (1_024 * 1_024)) : count
        for quest in todaysQuests where quest.type == type && !quest.isCompleted {
            quest.progress = min(quest.progress + increment, quest.target)
            if quest.progress >= quest.target {
                quest.isCompleted = true
                profile.xp += quest.rewardXP
            }
        }
    }

    // MARK: - Achievements

    private func aggregateStats() -> PlayerStats {
        let events = (try? modelContext.fetch(FetchDescriptor<CleanupEvent>())) ?? []
        var stats = PlayerStats()
        for e in events {
            stats.totalActions += 1
            switch e.type {
            case .duplicate:  stats.duplicatesDeleted += e.count
            case .screenshot: stats.screenshotsTriaged += e.count
            default: break
            }
        }
        stats.storageFreedBytes = profile.storageFreedBytes
        stats.streakCount = profile.streakCount
        return stats
    }

    /// Unlock any newly-qualifying achievements; returns the freshly unlocked ids.
    @discardableResult
    private func evaluateAchievements() -> [AchievementID] {
        let stats = aggregateStats()
        let qualifying = GamificationEngine.unlockedAchievements(for: stats)
        let existing = (try? modelContext.fetch(FetchDescriptor<Achievement>())) ?? []
        let already = Set(existing.compactMap { $0.achievementID })
        let fresh = qualifying.subtracting(already)
        for id in fresh { modelContext.insert(Achievement(id: id)) }
        return Array(fresh)
    }

    var unlockedAchievementIDs: Set<AchievementID> {
        let existing = (try? modelContext.fetch(FetchDescriptor<Achievement>())) ?? []
        return Set(existing.compactMap { $0.achievementID })
    }
}
