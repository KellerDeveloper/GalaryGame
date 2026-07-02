import Foundation
import Photos
import UIKit
import Vision

/// Coordinates gallery scanning and prepares asset lists for the triage flow.
@MainActor
@Observable
final class DashboardViewModel {

    private let photos: PhotoLibraryService
    private let store: GameStore
    private let analyzer = ClutterAnalyzer()

    var isScanning = false
    var scanProgress: Double = 0
    var metrics: GalleryMetrics = .empty
    private(set) var assets: [PHAsset] = []

    init(photos: PhotoLibraryService, store: GameStore) {
        self.photos = photos
        self.store = store
    }

    /// Fast base scan: counts + screenshots + unsorted → refresh the DOS.
    func quickScan() async {
        isScanning = true
        defer { isScanning = false }
        assets = photos.fetchImageAssets()
        var m = photos.collectBaseMetrics(from: assets)
        // Keep any previously-detected heavy metrics if we haven't rescanned.
        m.duplicates = metrics.duplicates
        m.blurry = metrics.blurry
        metrics = m
        store.updateScore(from: m)
    }

    var screenshotAssets: [PHAsset] {
        assets.filter { photos.isScreenshot($0) }
    }

    /// Heavy scan for near-duplicates using Vision feature prints.
    /// Returns the assets that are members of a duplicate group.
    func findDuplicates() async -> [PHAsset] {
        isScanning = true
        scanProgress = 0
        defer { isScanning = false }

        let targets = assets.filter { !photos.isScreenshot($0) }
        var prints: [(id: String, print: VNFeaturePrintObservation)] = []
        var byID: [String: PHAsset] = [:]

        for (index, asset) in targets.enumerated() {
            byID[asset.localIdentifier] = asset
            if let image = await photos.requestImage(for: asset, targetSize: CGSize(width: 224, height: 224)),
               let cg = image.cgImage,
               let print = try? analyzer.featurePrint(for: cg) {
                prints.append((asset.localIdentifier, print))
            }
            scanProgress = Double(index + 1) / Double(max(targets.count, 1))
        }

        let groups = analyzer.duplicateGroups(prints: prints)
        // Offer every-but-one from each group as deletable duplicates.
        let duplicateIDs = groups.flatMap { $0.dropFirst() }
        metrics.duplicates = duplicateIDs.count
        store.updateScore(from: metrics)
        return duplicateIDs.compactMap { byID[$0] }
    }

    /// Heavy scan for blurry photos.
    func findBlurry() async -> [PHAsset] {
        isScanning = true
        scanProgress = 0
        defer { isScanning = false }

        let targets = assets.filter { !photos.isScreenshot($0) }
        var blurry: [PHAsset] = []
        for (index, asset) in targets.enumerated() {
            if let image = await photos.requestImage(for: asset, targetSize: CGSize(width: 256, height: 256)),
               let cg = image.cgImage,
               analyzer.isBlurry(cg) {
                blurry.append(asset)
            }
            scanProgress = Double(index + 1) / Double(max(targets.count, 1))
        }
        metrics.blurry = blurry.count
        store.updateScore(from: metrics)
        return blurry
    }
}
