import Foundation
import SwiftData

/// An immutable log entry describing one batch of cleanup work.
/// Drives history, statistics and (re)computation of totals.
@Model
final class CleanupEvent {
    var date: Date
    /// Stored as `CleanupType.rawValue` so SwiftData persists a primitive.
    var typeRaw: String
    /// How many items this event covers (e.g. 12 duplicates deleted).
    var count: Int
    /// Bytes freed by this event (0 for non-deleting actions).
    var bytesFreed: Int64
    /// XP awarded for this event.
    var xpEarned: Int

    init(date: Date = .now, type: CleanupType, count: Int, bytesFreed: Int64 = 0, xpEarned: Int) {
        self.date = date
        self.typeRaw = type.rawValue
        self.count = count
        self.bytesFreed = bytesFreed
        self.xpEarned = xpEarned
    }

    var type: CleanupType { CleanupType(rawValue: typeRaw) ?? .duplicate }
}
