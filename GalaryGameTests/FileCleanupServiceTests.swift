import XCTest
@testable import GalaryGame

final class FileCleanupServiceTests: XCTestCase {

    private var root: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent("GGTest-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    @discardableResult
    private func write(_ name: String, bytes: Int, modified: Date? = nil) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(repeating: 0xAB, count: bytes).write(to: url)
        if let modified {
            try fm.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
        return url
    }

    func testFlagsLargeFiles() throws {
        try write("small.bin", bytes: 1_024)
        try write("big.bin", bytes: 60 * 1_024 * 1_024)
        let items = try FileCleanupService().scan(folder: root, now: .now)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.reason, .large)
        XCTAssertEqual(items.first?.url.lastPathComponent, "big.bin")
    }

    func testFlagsOldFiles() throws {
        let twoYearsAgo = Date(timeIntervalSinceNow: -2 * 365 * 24 * 3_600)
        try write("ancient.txt", bytes: 10, modified: twoYearsAgo)
        try write("fresh.txt", bytes: 10)
        let items = try FileCleanupService().scan(folder: root, now: .now)
        XCTAssertEqual(items.map(\.reason), [.old])
    }

    func testFlagsDuplicatesByContent() throws {
        // Same size AND same content → the later one is a duplicate.
        let a = root.appendingPathComponent("a.dat")
        let b = root.appendingPathComponent("b.dat")
        let payload = Data(repeating: 0x11, count: 2_048)
        try payload.write(to: a)
        try payload.write(to: b)
        // Same size but different content → NOT a duplicate.
        try Data(repeating: 0x22, count: 2_048).write(to: root.appendingPathComponent("c.dat"))

        let items = try FileCleanupService().scan(folder: root, now: .now)
        let dupes = items.filter { $0.reason == .duplicate }
        XCTAssertEqual(dupes.count, 1)
    }

    func testDeleteFreesReportedBytes() throws {
        try write("junk.bin", bytes: 60 * 1_024 * 1_024)
        let service = FileCleanupService()
        let items = try service.scan(folder: root, now: .now)
        let freed = try service.delete(items)
        XCTAssertEqual(freed, Int64(60 * 1_024 * 1_024))
        XCTAssertTrue(try service.scan(folder: root, now: .now).isEmpty)
    }

    func testCleanFolderReportsNothing() throws {
        try write("ok.txt", bytes: 100)
        XCTAssertTrue(try FileCleanupService().scan(folder: root, now: .now).isEmpty)
    }
}
