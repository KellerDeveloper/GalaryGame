import Foundation

/// Builds the daily set of quests. Deterministic per day so the same three
/// quests are shown all day and can be regenerated safely after a relaunch.
enum QuestFactory {

    private struct Template {
        let id: String
        let title: String
        let symbol: String
        let type: CleanupType
        let target: Int
        let reward: Int
    }

    private static let pool: [Template] = [
        Template(id: "triage_screenshots", title: "Разбери 20 скриншотов", symbol: "iphone", type: .screenshot, target: 20, reward: 30),
        Template(id: "sort_photos", title: "Разложи 30 фото по альбомам", symbol: "rectangle.stack.badge.plus", type: .sortToAlbum, target: 30, reward: 40),
        Template(id: "kill_duplicates", title: "Удали 15 дубликатов", symbol: "square.on.square", type: .duplicate, target: 15, reward: 35),
        Template(id: "clear_blurry", title: "Удали 10 размытых", symbol: "camera.filters", type: .blurry, target: 10, reward: 25),
        Template(id: "free_storage", title: "Освободи 500 МБ", symbol: "internaldrive", type: .storageFreed, target: 500, reward: 30),
    ]

    /// Deterministically pick `count` quests for a given day.
    /// Uses the day's ordinal to rotate the pool — no RNG, stable across launches.
    static func quests(for day: Date, count: Int = 3, calendar: Calendar = .current) -> [Quest] {
        let start = calendar.startOfDay(for: day)
        let ordinal = calendar.ordinality(of: .day, in: .era, for: start) ?? 0
        let n = min(count, pool.count)
        return (0..<n).map { offset in
            let t = pool[(ordinal + offset) % pool.count]
            return Quest(
                templateID: t.id,
                title: t.title,
                symbolName: t.symbol,
                type: t.type,
                target: t.target,
                rewardXP: t.reward,
                day: start
            )
        }
    }
}
