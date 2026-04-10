import Testing
import UIKit
@testable import S3Gallery

/// Tests for `makeImageIOThumbnail`, which decodes image data via ImageIO sub-sampling
/// so the full pixel buffer is never allocated — the core memory-saving step in the
/// thumbnail loading pipeline.
@Suite("makeImageIOThumbnail")
struct ImageIOThumbnailTests {

    /// Creates a solid-colour JPEG of the given dimensions.
    ///
    /// Using a real JPEG (not just raw pixel bytes) exercises the actual ImageIO
    /// JPEG decoder path, which is what the app encounters for the vast majority
    /// of S3 image objects.
    private func makeJPEG(width: Int, height: Int) -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        }.jpegData(compressionQuality: 0.8)!
    }

    // MARK: - Invalid input

    /// Verifies that corrupt / non-image bytes return nil rather than crashing.
    ///
    /// S3 objects can be unexpectedly non-image files (text, binaries). `makeImageIOThumbnail`
    /// must handle bad input gracefully so the grid cell falls back to its placeholder icon.
    @Test("invalid data returns nil")
    func invalidDataReturnsNil() async {
        let result = await makeImageIOThumbnail(from: Data("not an image".utf8), maxPixelSize: 100)
        #expect(result == nil)
    }

    /// Verifies that empty `Data` returns nil without crashing.
    @Test("empty data returns nil")
    func emptyDataReturnsNil() async {
        let result = await makeImageIOThumbnail(from: Data(), maxPixelSize: 100)
        #expect(result == nil)
    }

    // MARK: - Valid JPEG

    /// Verifies that a valid JPEG produces a non-nil UIImage.
    ///
    /// This is the primary success path for every grid cell that loads a thumbnail.
    @Test("valid JPEG returns non-nil image")
    func validJPEGReturnsImage() async {
        let data = makeJPEG(width: 200, height: 100)
        let result = await makeImageIOThumbnail(from: data, maxPixelSize: 960)
        #expect(result != nil)
    }

    /// Verifies that the thumbnail's longest edge does not exceed `maxPixelSize`.
    ///
    /// Grid cells are displayed at 130–390 pt. Decoding a 5000×4000 image without the
    /// cap allocates ~80 MB per image; with the cap it's ~3 MB. The limit must be
    /// enforced or the memory savings from ImageIO sub-sampling are lost.
    @Test("longest edge of thumbnail does not exceed maxPixelSize")
    func thumbnailRespectsMaxPixelSize() async {
        let data = makeJPEG(width: 3000, height: 1500)
        guard let image = await makeImageIOThumbnail(from: data, maxPixelSize: 960) else {
            Issue.record("expected non-nil image for valid JPEG")
            return
        }
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        #expect(longest <= 960)
    }

    /// Verifies that the thumbnail preserves the source image's aspect ratio.
    ///
    /// `BrowserGridView` drives its masonry cell height from
    /// `image.size.width / image.size.height`. A distorted thumbnail would produce
    /// incorrect column heights, visually breaking the grid layout.
    @Test("thumbnail preserves source aspect ratio")
    func thumbnailPreservesAspectRatio() async {
        // Strict 2:1 landscape source
        let data = makeJPEG(width: 2000, height: 1000)
        guard let image = await makeImageIOThumbnail(from: data, maxPixelSize: 960) else {
            Issue.record("expected non-nil image for valid JPEG")
            return
        }
        let w = image.size.width * image.scale
        let h = image.size.height * image.scale
        let ratio = w / h
        // Allow ±2 % tolerance for JPEG block-boundary rounding
        #expect(abs(ratio - 2.0) < 0.02, "expected ~2:1 ratio, got \(ratio)")
    }

    /// Verifies that portrait images (height > width) also pass the cap correctly.
    ///
    /// `kCGImageSourceThumbnailMaxPixelSize` applies to the longest edge. A portrait
    /// image's longest edge is its height; the cap must still be respected.
    @Test("portrait image longest edge does not exceed maxPixelSize")
    func portraitImageRespectsCap() async {
        let data = makeJPEG(width: 800, height: 2400)
        guard let image = await makeImageIOThumbnail(from: data, maxPixelSize: 960) else {
            Issue.record("expected non-nil image for valid JPEG")
            return
        }
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        #expect(longest <= 960)
    }
}
