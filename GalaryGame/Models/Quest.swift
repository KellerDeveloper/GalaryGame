import Foundation
import SwiftData

/// A daily quest instance. One set of quests is generated per calendar day.
@Model
final class Quest {
    /// Stable template id (e.g. "triage_screenshots").
    var templateID: String
    /// Human-readable goal shown in the UI.
    var title: String
    /// SF Symbol name for the quest row.
    var symbolName: String
    /// The cleanup type this quest tracks progress against.
    var typeRaw: String
    /// Target amount to complete the quest.
    var target: Int
    /// Current progress toward `target`.
    var progress: Int
    /// XP granted once completed.
    var rewardXP: Int
    /// Start-of-day this quest belongs to.
    var day: Date
    var isCompleted: Bool

    init(
        templateID: String,
        title: String,
        symbolName: String,
        type: CleanupType,
        target: Int,
        progress: Int = 0,
        rewardXP: Int,
        day: Date,
        isCompleted: Bool = false
    ) {
        self.templateID = templateID
        self.title = title
        self.symbolName = symbolName
        self.typeRaw = type.rawValue
        self.target = target
        self.progress = progress
        self.rewardXP = rewardXP
        self.day = day
        self.isCompleted = isCompleted
    }

    var type: CleanupType { CleanupType(rawValue: typeRaw) ?? .duplicate }

    var fractionComplete: Double {
        target > 0 ? min(Double(progress) / Double(target), 1) : 0
    }
}
