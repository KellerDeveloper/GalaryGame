import Foundation
import Vision
import CoreImage

/// On-device image analysis: blur detection and near-duplicate grouping.
/// All work is local (Vision + Core Image); nothing is uploaded.
struct ClutterAnalyzer {

    /// Shared CIContext — expensive to create, cheap to reuse.
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    // MARK: - Blur detection (variance of Laplacian)

    /// Sharpness score: variance of the Laplacian. Low values mean blurry.
    /// Returns 0 if the metric can't be computed.
    func sharpness(of image: CGImage) -> Double {
        let input = CIImage(cgImage: image)

        // 3x3 Laplacian edge kernel.
        guard let laplacian = CIFilter(name: "CIConvolution3X3") else { return 0 }
        let weights = CIVector(values: [0, 1, 0, 1, -4, 1, 0, 1, 0], count: 9)
        laplacian.setValue(input, forKey: kCIInputImageKey)
        laplacian.setValue(weights, forKey: "inputWeights")
        laplacian.setValue(0, forKey: "inputBias")
        guard let edges = laplacian.outputImage else { return 0 }

        // variance = E[x^2] - E[x]^2, using CIAreaAverage over the edge map.
        let extent = input.extent
        let mean = areaAverageLuma(of: edges, extent: extent)
        let squared = edges.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: edges])
        let meanOfSquares = areaAverageLuma(of: squared, extent: extent)
        return max(meanOfSquares - mean * mean, 0)
    }

    /// A photo is considered blurry when its sharpness falls below `threshold`.
    /// The default is a conservative starting point — tune on-device.
    func isBlurry(_ image: CGImage, threshold: Double = 0.0008) -> Bool {
        sharpness(of: image) < threshold
    }

    /// Average luma of an image over `extent`, in [0, 1].
    private func areaAverageLuma(of image: CIImage, extent: CGRect) -> Double {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0 }
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        guard let output = filter.outputImage else { return 0 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        // Rec. 601 luma.
        let r = Double(bitmap[0]), g = Double(bitmap[1]), b = Double(bitmap[2])
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    }

    // MARK: - Duplicate detection (Vision feature prints)

    /// Compute a feature print for similarity comparison.
    func featurePrint(for image: CGImage) throws -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        return request.results?.first as? VNFeaturePrintObservation
    }

    /// Group items whose feature prints are within `threshold` distance.
    /// Lower distance = more similar; ~0.3–0.6 is a typical near-dupe range.
    /// Pure over the prints, so it is unit-testable with synthetic observations.
    ///
    /// - Returns: groups of 2+ ids that are mutual near-duplicates.
    func duplicateGroups<ID: Hashable>(
        prints: [(id: ID, print: VNFeaturePrintObservation)],
        threshold: Float = 0.5
    ) -> [[ID]] {
        var groups: [[ID]] = []
        var assigned = Set<ID>()

        for i in prints.indices where !assigned.contains(prints[i].id) {
            var group = [prints[i].id]
            for j in (i + 1)..<prints.count where !assigned.contains(prints[j].id) {
                var distance: Float = .greatestFiniteMagnitude
                do {
                    try prints[i].print.computeDistance(&distance, to: prints[j].print)
                } catch { continue }
                if distance <= threshold {
                    group.append(prints[j].id)
                    assigned.insert(prints[j].id)
                }
            }
            if group.count > 1 {
                assigned.insert(prints[i].id)
                groups.append(group)
            }
        }
        return groups
    }
}
