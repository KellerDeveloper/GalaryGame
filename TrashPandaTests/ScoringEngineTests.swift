import XCTest
@testable import TrashPanda

final class ScoringEngineTests: XCTestCase {

    func testXPPerActionType() {
        XCTAssertEqual(ScoringEngine.xp(for: .duplicate, count: 3), 15)
        XCTAssertEqual(ScoringEngine.xp(for: .blurry, count: 2), 10)
        XCTAssertEqual(ScoringEngine.xp(for: .screenshot, count: 4), 12)
        XCTAssertEqual(ScoringEngine.xp(for: .sortToAlbum, count: 10), 20)
        XCTAssertEqual(ScoringEngine.xp(for: .emptyTrash, count: 1), 20)
    }

    func testStorageXPIsPer100MB() {
        let bytes: Int64 = 250 * 1_024 * 1_024 // 250 MB → 2 points (floored)
        XCTAssertEqual(ScoringEngine.xp(for: .storageFreed, count: 0, bytesFreed: bytes), 2)
        XCTAssertEqual(ScoringEngine.xp(for: .storageFreed, count: 0, bytesFreed: 0), 0)
    }

    func testNegativeCountsClampToZero() {
        XCTAssertEqual(ScoringEngine.xp(for: .duplicate, count: -5), 0)
    }

    func testEmptyGalleryScoresPerfect() {
        XCTAssertEqual(ScoringEngine.digitalOrderScore(from: .empty), 100)
    }

    func testCleanGalleryScoresPerfect() {
        let m = GalleryMetrics(totalPhotos: 100, duplicates: 0, blurry: 0,
                               screenshots: 0, unsorted: 0, recentlyDeleted: 0)
        XCTAssertEqual(ScoringEngine.digitalOrderScore(from: m), 100)
    }

    func testFullyClutteredGalleryScoresLow() {
        // Everything is a duplicate, blurry, screenshot and unsorted at once.
        let m = GalleryMetrics(totalPhotos: 100, duplicates: 100, blurry: 100,
                               screenshots: 100, unsorted: 100, recentlyDeleted: 100)
        XCTAssertEqual(ScoringEngine.digitalOrderScore(from: m), 0)
    }

    func testPartialClutterIsBetween() {
        let m = GalleryMetrics(totalPhotos: 100, duplicates: 10, blurry: 0,
                               screenshots: 0, unsorted: 20, recentlyDeleted: 0)
        let score = ScoringEngine.digitalOrderScore(from: m)
        // 10% dupes (weight 30) → -3; 20% unsorted (weight 25) → -5; total 92.
        XCTAssertEqual(score, 92)
    }

    func testScoreNeverGoesNegative() {
        let m = GalleryMetrics(totalPhotos: 10, duplicates: 10, blurry: 10,
                               screenshots: 10, unsorted: 10, recentlyDeleted: 10)
        XCTAssertGreaterThanOrEqual(ScoringEngine.digitalOrderScore(from: m), 0)
    }
}
