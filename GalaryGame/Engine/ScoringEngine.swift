import Foundation

/// A snapshot of gallery "clutter" used to compute the Digital Order Score.
/// All counts refer to the image library only.
struct GalleryMetrics: Equatable {
    var totalPhotos: Int
    var duplicates: Int
    var blurry: Int
    var screenshots: Int
    /// Photos that belong to no user album.
    var unsorted: Int
    /// Items still sitting in "Recently Deleted".
    var recentlyDeleted: Int

    static let empty = GalleryMetrics(
        totalPhotos: 0, duplicates: 0, blurry: 0,
        screenshots: 0, unsorted: 0, recentlyDeleted: 0
    )
}

/// Pure functions that turn actions and metrics into numbers.
/// Deliberately free of PhotoKit / SwiftData so it is trivially unit-testable.
enum ScoringEngine {

    static let bytesPerStoragePoint: Int64 = 100 * 1_024 * 1_024 // 100 MB

    /// XP awarded for a batch of one cleanup type.
    /// `storageFreed` scores 1 XP per 100 MB (from `bytesFreed`); all other
    /// types score `baseXP * count`.
    static func xp(for type: CleanupType, count: Int, bytesFreed: Int64 = 0) -> Int {
        switch type {
        case .storageFreed:
            return Int(max(bytesFreed, 0) / bytesPerStoragePoint)
        default:
            return type.baseXP * max(count, 0)
        }
    }

    /// Weights applied to each clutter ratio. They sum to 100 so the score maps
    /// cleanly onto a 0...100 scale (a perfectly clean gallery scores 100).
    private enum Weight {
        static let duplicate: Double = 30
        static let blurry: Double = 20
        static let screenshot: Double = 15
        static let unsorted: Double = 25
        static let recentlyDeleted: Double = 10
    }

    /// Digital Order Score in 0...100. Higher = tidier.
    /// An empty library is treated as perfectly tidy (100).
    static func digitalOrderScore(from m: GalleryMetrics) -> Int {
        guard m.totalPhotos > 0 else { return 100 }
        let total = Double(m.totalPhotos)

        func ratio(_ n: Int) -> Double { min(Double(max(n, 0)) / total, 1) }

        // "Recently deleted" is a soft, capped penalty — any leftover counts,
        // fully penalized once it reaches ~5% of the library.
        let rdRatio = min(ratio(m.recentlyDeleted) / 0.05, 1)

        let penalty =
            ratio(m.duplicates)   * Weight.duplicate +
            ratio(m.blurry)       * Weight.blurry +
            ratio(m.screenshots)  * Weight.screenshot +
            ratio(m.unsorted)     * Weight.unsorted +
            rdRatio               * Weight.recentlyDeleted

        let score = 100.0 - penalty
        return Int(score.rounded().clamped(to: 0...100))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
