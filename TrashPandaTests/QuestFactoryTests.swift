import XCTest
@testable import TrashPanda

final class QuestFactoryTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testGeneratesRequestedCount() {
        let quests = QuestFactory.quests(for: day(2026, 7, 2), count: 3, calendar: cal)
        XCTAssertEqual(quests.count, 3)
    }

    func testDeterministicPerDay() {
        let a = QuestFactory.quests(for: day(2026, 7, 2), calendar: cal).map(\.templateID)
        let b = QuestFactory.quests(for: day(2026, 7, 2), calendar: cal).map(\.templateID)
        XCTAssertEqual(a, b)
    }

    func testDifferentDaysRotate() {
        let a = QuestFactory.quests(for: day(2026, 7, 2), calendar: cal).map(\.templateID)
        let b = QuestFactory.quests(for: day(2026, 7, 3), calendar: cal).map(\.templateID)
        XCTAssertNotEqual(a, b)
    }

    func testQuestsBelongToRequestedDay() {
        let target = cal.startOfDay(for: day(2026, 7, 2))
        for quest in QuestFactory.quests(for: day(2026, 7, 2), calendar: cal) {
            XCTAssertEqual(quest.day, target)
            XCTAssertFalse(quest.isCompleted)
            XCTAssertEqual(quest.progress, 0)
        }
    }
}
