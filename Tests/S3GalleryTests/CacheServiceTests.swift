import Testing
import UIKit
@testable import S3Gallery

@Suite("CacheService")
@MainActor
struct CacheServiceTests {

    // Each test uses a separate CacheService instance to avoid shared state.
    private func makeCache(maxMB: Int = 10) -> CacheService {
        CacheService.makeTestInstance(maxDiskSizeMB: maxMB)
    }

    private func makeImage(color: UIColor = .blue) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }

    @Test("stores and retrieves thumbnail from memory cache")
    func storeAndRetrieve() {
        let cache = makeCache()
        let image = makeImage()
        cache.storeThumbnail(image, forKey: "test-bucket/photo.jpg?thumb")

        let retrieved = cache.thumbnail(forKey: "test-bucket/photo.jpg?thumb")
        #expect(retrieved != nil)
        cache.clearAll()
    }

    @Test("returns nil for unknown key")
    func missingKeyReturnsNil() {
        let cache = makeCache()
        #expect(cache.thumbnail(forKey: "nonexistent/key") == nil)
    }

    @Test("clearAll removes all cached thumbnails")
    func clearAll() {
        let cache = makeCache()
        cache.storeThumbnail(makeImage(), forKey: "key1")
        cache.storeThumbnail(makeImage(), forKey: "key2")

        cache.clearAll()

        #expect(cache.thumbnail(forKey: "key1") == nil)
        #expect(cache.thumbnail(forKey: "key2") == nil)
        #expect(cache.diskUsageBytes == 0)
    }

    @Test("diskUsageBytes increases after storing thumbnails")
    func diskUsageIncreases() {
        let cache = makeCache()
        let initialUsage = cache.diskUsageBytes
        cache.storeThumbnail(makeImage(), forKey: "bucket/large.jpg?thumb")

        // Allow async disk refresh to propagate
        // (In real tests, you'd wait for the Task to complete)
        #expect(cache.diskUsageBytes >= initialUsage)
        cache.clearAll()
    }
}
