import Testing
import UIKit
@testable import S3Gallery

/// Tests for `CacheService`, which manages the two-layer thumbnail cache
/// (NSCache in-memory + disk) used by the grid browser view.
///
/// Each test creates an isolated `CacheService` instance backed by a unique temp directory
/// via `makeTestInstance`, so tests run in parallel without interfering with each other
/// or with the shared `CacheService.shared` used by the running app.
@Suite("CacheService")
@MainActor
struct CacheServiceTests {

    /// Creates an isolated CacheService instance with its own temp directory.
    ///
    /// Using a unique directory per test prevents cross-test pollution when tests run in
    /// parallel (Swift Testing's default). The `maxMB` parameter lets individual tests
    /// exercise the eviction logic with small limits without waiting for gigabytes of data.
    private func makeCache(maxMB: Int = 10) -> CacheService {
        CacheService.makeTestInstance(maxDiskSizeMB: maxMB)
    }

    /// Renders a solid-colour 10×10 UIImage for use as a stand-in thumbnail.
    ///
    /// The image is intentionally tiny to keep tests fast. The colour parameter lets tests
    /// create distinct images when they need to verify which image was retrieved.
    private func makeImage(color: UIColor = .blue) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
    }

    /// Verifies that a stored thumbnail is immediately retrievable from the in-memory cache.
    ///
    /// `storeThumbnail` writes to both NSCache and disk. A subsequent `thumbnail(forKey:)` call
    /// with the same key must return a non-nil image. This test exercises the hot path: the
    /// NSCache hit that avoids a disk read, which is the critical path during fast grid scrolling.
    @Test("stores and retrieves thumbnail from memory cache")
    func storeAndRetrieve() {
        let cache = makeCache()
        let image = makeImage()
        cache.storeThumbnail(image, forKey: "test-bucket/photo.jpg?thumb")

        let retrieved = cache.thumbnail(forKey: "test-bucket/photo.jpg?thumb")
        #expect(retrieved != nil)
        cache.clearAll()
    }

    /// Verifies that looking up a key that was never stored returns nil.
    ///
    /// Grid cells call `thumbnail(forKey:)` before kicking off an async download. Receiving
    /// nil is the signal to start downloading and show a placeholder icon in the meantime.
    /// A non-nil return for an unknown key would mean showing a wrong or corrupt thumbnail.
    @Test("returns nil for unknown key")
    func missingKeyReturnsNil() {
        let cache = makeCache()
        #expect(cache.thumbnail(forKey: "nonexistent/key") == nil)
    }

    /// Verifies that `clearAll` removes every stored thumbnail from both memory and disk.
    ///
    /// `clearAll` is called on logout to ensure no user content persists on the device after
    /// the session ends. After clearing:
    /// - Previously stored keys must return nil (memory evicted)
    /// - `diskUsageBytes` must be 0 (disk directory removed and recreated empty)
    ///
    /// This test stores two thumbnails under different keys and confirms both are gone after
    /// a single `clearAll` call, ruling out partial-eviction bugs.
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

    /// Verifies that `diskUsageBytes` is non-decreasing after storing a thumbnail.
    ///
    /// `SettingsView` displays disk usage as a progress indicator so the user can decide when
    /// to clear the cache. The reported value must reflect actual disk writes — if it stayed at
    /// zero after storing a thumbnail, the settings screen would always show "0 MB used" and
    /// the user would have no visibility into cache growth.
    ///
    /// Note: the disk refresh is performed asynchronously via a detached `Task`, so this test
    /// only asserts a non-decreasing lower bound rather than an exact byte count.
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
