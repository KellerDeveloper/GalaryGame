import XCTest
@testable import TrashPanda

final class GamificationEngineTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Streaks

    func testFirstEverActivityStartsStreakAtOne() {
        let r = GamificationEngine.updateStreak(
            lastActiveDay: nil, today: day(2026, 7, 2),
            currentStreak: 0, freezes: 1, calendar: cal)
        XCTAssertEqual(r.newStreak, 1)
        XCTAssertFalse(r.usedFreeze)
    }

    func testSameDayDoesNotIncrement() {
        let r = GamificationEngine.updateStreak(
            lastActiveDay: day(2026, 7, 2), today: day(2026, 7, 2),
            currentStreak: 5, freezes: 1, calendar: cal)
        XCTAssertEqual(r.newStreak, 5)
    }

    func testConsecutiveDayIncrements() {
        let r = GamificationEngine.updateStreak(
            lastActiveDay: day(2026, 7, 1), today: day(2026, 7, 2),
            currentStreak: 5, freezes: 1, calendar: cal)
        XCTAssertEqual(r.newStreak, 6)
        XCTAssertFalse(r.usedFreeze)
    }

    func testOneMissedDayConsumesFreeze() {
        let r = GamificationEngine.updateStreak(
            lastActiveDay: day(2026, 7, 1), today: day(2026, 7, 3),
            currentStreak: 5, freezes: 1, calendar: cal)
        XCTAssertEqual(r.newStreak, 6)
        XCTAssertTrue(r.usedFreeze)
        XCTAssertEqual(r.remainingFreezes, 0)
    }

    func testMissedDayWithoutFreezeResets() {
        let r = GamificationEngine.updateStreak(
            lastActiveDay: day(2026, 7, 1), today: day(2026, 7, 3),
            currentStreak: 5, freezes: 0, calendar: cal)
        XCTAssertEqual(r.newStreak, 1)
    }

    func testLongGapResets() {
        let r = GamificationEngine.updateStreak(
            lastActiveDay: day(2026, 7, 1), today: day(2026, 7, 10),
            currentStreak: 5, freezes: 3, calendar: cal)
        XCTAssertEqual(r.newStreak, 1)
    }

    // MARK: - Ranks

    func testRankThresholds() {
        XCTAssertEqual(Rank.rank(forXP: 0), .chaos)
        XCTAssertEqual(Rank.rank(forXP: 99), .chaos)
        XCTAssertEqual(Rank.rank(forXP: 100), .novice)
        XCTAssertEqual(Rank.rank(forXP: 999), .organizer)
        XCTAssertEqual(Rank.rank(forXP: 2500), .zenMaster)
        // Prestige ranks above Дзен-мастер.
        XCTAssertEqual(Rank.rank(forXP: 4999), .zenMaster)
        XCTAssertEqual(Rank.rank(forXP: 5000), .curator)
        XCTAssertEqual(Rank.rank(forXP: 10000), .archivist)
        XCTAssertEqual(Rank.rank(forXP: 25000), .legend)
        XCTAssertEqual(Rank.rank(forXP: 999999), .legend)
    }

    func testRankUpDetection() {
        XCTAssertTrue(GamificationEngine.didRankUp(from: 90, to: 120))
        XCTAssertFalse(GamificationEngine.didRankUp(from: 120, to: 140))
        // Crossing into a prestige rank counts as a rank-up.
        XCTAssertTrue(GamificationEngine.didRankUp(from: 4900, to: 5100))
    }

    func testRankProgress() {
        // 250 XP: between novice(100) and organizer(400) → 150/300 = 0.5
        XCTAssertEqual(Rank.novice.progress(towardNextFrom: 250), 0.5, accuracy: 0.0001)
        // zenMaster(2500) → curator(5000): 3750 XP → 1250/2500 = 0.5
        XCTAssertEqual(Rank.zenMaster.progress(towardNextFrom: 3750), 0.5, accuracy: 0.0001)
        // legend is the top rank → always 1.0
        XCTAssertEqual(Rank.legend.progress(towardNextFrom: 999999), 1.0)
    }

    // MARK: - Achievements

    func testAchievementUnlocks() {
        let stats = PlayerStats(
            duplicatesDeleted: 100, screenshotsTriaged: 200,
            storageFreedBytes: 10 * 1_024 * 1_024 * 1_024,
            streakCount: 100, unsortedPhotos: 0, totalActions: 12,
            photosSorted: 100)
        let unlocked = GamificationEngine.unlockedAchievements(for: stats)
        XCTAssertTrue(unlocked.contains(.firstClean))
        XCTAssertTrue(unlocked.contains(.hundredDuplicates))
        XCTAssertTrue(unlocked.contains(.photoInboxZero))
        XCTAssertTrue(unlocked.contains(.weekStreak))
        XCTAssertTrue(unlocked.contains(.freedOneGig))
        XCTAssertTrue(unlocked.contains(.screenshotSlayer))
        XCTAssertTrue(unlocked.contains(.hundredDayStreak))
        XCTAssertTrue(unlocked.contains(.freedTenGigs))
        XCTAssertTrue(unlocked.contains(.sortedHundred))
    }

    /// Prestige-tier achievements must NOT unlock at the lower tiers.
    func testPrestigeAchievementsNeedHigherThresholds() {
        let stats = PlayerStats(
            duplicatesDeleted: 0, screenshotsTriaged: 0,
            storageFreedBytes: 1_024 * 1_024 * 1_024, // exactly 1 GB
            streakCount: 7, unsortedPhotos: 5, totalActions: 3,
            photosSorted: 99)
        let unlocked = GamificationEngine.unlockedAchievements(for: stats)
        XCTAssertTrue(unlocked.contains(.freedOneGig))
        XCTAssertTrue(unlocked.contains(.weekStreak))
        XCTAssertFalse(unlocked.contains(.freedTenGigs))
        XCTAssertFalse(unlocked.contains(.hundredDayStreak))
        XCTAssertFalse(unlocked.contains(.sortedHundred))
    }

    func testNoAchievementsForFreshPlayer() {
        XCTAssertTrue(GamificationEngine.unlockedAchievements(for: PlayerStats()).isEmpty)
    }
}
