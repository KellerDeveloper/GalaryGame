import XCTest
@testable import GalaryGame

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
    }

    func testRankUpDetection() {
        XCTAssertTrue(GamificationEngine.didRankUp(from: 90, to: 120))
        XCTAssertFalse(GamificationEngine.didRankUp(from: 120, to: 140))
    }

    func testRankProgress() {
        // 250 XP: between novice(100) and organizer(400) → 150/300 = 0.5
        XCTAssertEqual(Rank.novice.progress(towardNextFrom: 250), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Rank.zenMaster.progress(towardNextFrom: 9999), 1.0)
    }

    // MARK: - Achievements

    func testAchievementUnlocks() {
        let stats = PlayerStats(
            duplicatesDeleted: 100, screenshotsTriaged: 200,
            storageFreedBytes: 1_024 * 1_024 * 1_024,
            streakCount: 7, unsortedPhotos: 0, totalActions: 12)
        let unlocked = GamificationEngine.unlockedAchievements(for: stats)
        XCTAssertTrue(unlocked.contains(.firstClean))
        XCTAssertTrue(unlocked.contains(.hundredDuplicates))
        XCTAssertTrue(unlocked.contains(.photoInboxZero))
        XCTAssertTrue(unlocked.contains(.weekStreak))
        XCTAssertTrue(unlocked.contains(.freedOneGig))
        XCTAssertTrue(unlocked.contains(.screenshotSlayer))
    }

    func testNoAchievementsForFreshPlayer() {
        XCTAssertTrue(GamificationEngine.unlockedAchievements(for: PlayerStats()).isEmpty)
    }
}
