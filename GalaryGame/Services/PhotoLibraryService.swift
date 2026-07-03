import Foundation
import Photos
import UIKit

/// Thin, testable-ish wrapper around PhotoKit. Owns authorization, asset
/// fetching, metric collection, deletion and album management.
///
/// Photos never leave the device — this class only reads pixel data locally to
/// feed the on-device `ClutterAnalyzer`.
@MainActor
@Observable
final class PhotoLibraryService {

    enum AuthState: Equatable {
        case notDetermined, authorized, limited, denied
    }

    private(set) var authState: AuthState = .notDetermined

    private let imageManager = PHCachingImageManager()

    // MARK: - Authorization

    func refreshAuthState() {
        authState = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    @discardableResult
    func requestAuthorization() async -> AuthState {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let mapped = Self.map(status)
        authState = mapped
        return mapped
    }

    private static func map(_ status: PHAuthorizationStatus) -> AuthState {
        switch status {
        case .authorized: return .authorized
        case .limited:    return .limited
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    // MARK: - Fetching

    /// All image assets, newest first.
    func fetchImageAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func isScreenshot(_ asset: PHAsset) -> Bool {
        asset.mediaSubtypes.contains(.photoScreenshot)
    }

    /// Best-effort byte size of an asset via its primary resource.
    /// Falls back to 0 when the size is unavailable.
    func estimatedByteSize(of asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        for resource in resources {
            if let size = resource.value(forKey: "fileSize") as? CLong {
                return Int64(size)
            }
        }
        return 0
    }

    // MARK: - Metrics

    /// Collect the metrics that do NOT require heavy ML (screenshots, unsorted).
    /// Duplicate/blurry counts are filled in by `ClutterAnalyzer`.
    ///
    /// Note: "Recently Deleted" contents are not publicly enumerable on iOS, so
    /// `recentlyDeleted` is left at 0 here.
    func collectBaseMetrics(from assets: [PHAsset]) -> GalleryMetrics {
        let screenshots = assets.reduce(into: 0) { $0 += isScreenshot($1) ? 1 : 0 }
        let unsorted = unsortedImageAssets(from: assets).count
        return GalleryMetrics(
            totalPhotos: assets.count,
            duplicates: 0,
            blurry: 0,
            screenshots: screenshots,
            unsorted: unsorted,
            recentlyDeleted: 0
        )
    }

    /// Local identifiers of every asset that belongs to at least one user album.
    private func identifiersInUserAlbums() -> Set<String> {
        var ids = Set<String>()
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        albums.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            assets.enumerateObjects { asset, _, _ in ids.insert(asset.localIdentifier) }
        }
        return ids
    }

    /// Image assets that belong to no user album — the "sort me" backlog.
    func unsortedImageAssets(from assets: [PHAsset]) -> [PHAsset] {
        let sortedIDs = identifiersInUserAlbums()
        return assets.filter { !sortedIDs.contains($0.localIdentifier) }
    }

    /// Lightweight description of a user album for the sort UI.
    struct AlbumInfo: Identifiable {
        let collection: PHAssetCollection
        let title: String
        let count: Int
        var id: String { collection.localIdentifier }
    }

    /// All user-created albums with titles and item counts.
    func userAlbums() -> [AlbumInfo] {
        var result: [AlbumInfo] = []
        let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        albums.enumerateObjects { collection, _, _ in
            let count = PHAsset.fetchAssets(in: collection, options: nil).count
            result.append(AlbumInfo(
                collection: collection,
                title: collection.localizedTitle ?? "Без названия",
                count: count
            ))
        }
        return result.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    // MARK: - Image loading (for analysis / thumbnails)

    /// Load a downscaled image for a given asset, suitable for Vision analysis.
    func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = false
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // Ignore the low-res "degraded" first callback.
                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded { return }
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Mutations (all show the system confirmation sheet)

    /// Delete assets. iOS presents its own confirmation UI. Returns freed bytes.
    @discardableResult
    func delete(_ assets: [PHAsset]) async throws -> Int64 {
        guard !assets.isEmpty else { return 0 }
        let freed = assets.reduce(Int64(0)) { $0 + estimatedByteSize(of: $1) }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
        return freed
    }

    /// Create a named album (if needed) and add assets to it.
    func addAssets(_ assets: [PHAsset], toAlbumNamed name: String) async throws {
        guard !assets.isEmpty else { return }
        let collection = try await albumNamed(name) ?? (try await createAlbum(named: name))
        try await addAssets(assets, to: collection)
    }

    /// Add assets to an existing album collection.
    func addAssets(_ assets: [PHAsset], to collection: PHAssetCollection) async throws {
        guard !assets.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            guard let request = PHAssetCollectionChangeRequest(for: collection) else { return }
            request.addAssets(assets as NSArray)
        }
    }

    /// Create a new empty album and return it.
    func createAlbum(titled name: String) async throws -> PHAssetCollection {
        try await createAlbum(named: name)
    }

    private func albumNamed(_ name: String) async -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", name)
        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
        return result.firstObject
    }

    private func createAlbum(named name: String) async throws -> PHAssetCollection {
        var placeholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = request.placeholderForCreatedAssetCollection
        }
        guard let id = placeholder?.localIdentifier,
              let collection = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [id], options: nil).firstObject
        else { throw PhotoError.albumCreationFailed }
        return collection
    }

    enum PhotoError: Error { case albumCreationFailed }
}
