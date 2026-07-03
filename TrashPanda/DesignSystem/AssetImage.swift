import SwiftUI
import Photos

/// Loads and displays a PHAsset thumbnail asynchronously, on-device only.
struct AssetImage: View {
    let asset: PHAsset
    let photos: PhotoLibraryService

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.tertiarySystemFill)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .task(id: asset.localIdentifier) {
                let size = CGSize(width: geo.size.width * 2, height: geo.size.height * 2)
                image = await photos.requestImage(for: asset, targetSize: size)
            }
        }
    }
}
