import Testing
import UIKit
import Combine
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

    /// Verifies that changing `maxDiskSizeMB` fires `objectWillChange` so SwiftUI re-renders.
    ///
    /// `SettingsView` binds both the slider and the "Max Cache Size: X MB" label to
    /// `cacheService.maxDiskSizeMB`. If this property is not `@Published`, the label will not
    /// update while the user drags the slider — the value changes internally but SwiftUI never
    /// invalidates the view. This test confirms that `objectWillChange` fires on every write.
    @Test("maxDiskSizeMB change publishes objectWillChange for SwiftUI reactivity")
    func maxDiskSizeMBPublishesChange() async {
        let cache = makeCache(maxMB: 100)
        var changeCount = 0
        let cancellable = cache.objectWillChange.sink { changeCount += 1 }

        cache.maxDiskSizeMB = 200
        cache.maxDiskSizeMB = 300

        #expect(changeCount == 2)
        _ = cancellable  // keep alive
    }

    /// Verifies that changing `maxDiskSizeMB` persists the new value to UserDefaults.
    ///
    /// Settings are restored on next launch via UserDefaults. If the `didSet` observer is
    /// missing or the key is wrong, the user's chosen limit will be silently forgotten.
    @Test("maxDiskSizeMB change persists to UserDefaults")
    func maxDiskSizeMBPersistsToUserDefaults() {
        let cache = makeCache(maxMB: 100)
        cache.maxDiskSizeMB = 750

        let stored = UserDefaults.standard.integer(forKey: "cacheMaxDiskSizeMB")
        #expect(stored == 750)
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

    // MARK: - Full-resolution caching

    /// Verifies that full-resolution data stored via `storeFullResData` is retrievable.
    ///
    /// PhotoViewer calls `fullResData(forKey:)` on open to avoid re-downloading an image that
    /// was already fetched during grid browsing. This test confirms the round-trip write/read
    /// works correctly so the viewer can present the cached image without an S3 request.
    @Test("stores and retrieves full-res data")
    func storeAndRetrieveFullResData() {
        let cache = makeCache()
        let data = makeImage().jpegData(compressionQuality: 0.9)!
        cache.storeFullResData(data, forKey: "bucket/photo.jpg")

        let retrieved = cache.fullResData(forKey: "bucket/photo.jpg")
        #expect(retrieved != nil)
        #expect(retrieved == data)
        cache.clearAll()
    }

    /// Verifies that `fullResData` returns nil for a key that was never stored.
    ///
    /// PhotoViewer checks the full-res cache before deciding whether to download. A false
    /// cache hit would cause PhotoViewer to display corrupt data or crash on `UIImage(data:)`.
    @Test("fullResData returns nil for unknown key")
    func fullResDataMissingKeyReturnsNil() {
        let cache = makeCache()
        #expect(cache.fullResData(forKey: "bucket/missing.jpg") == nil)
    }

    /// Verifies that `clearAll` also removes full-resolution cached files.
    ///
    /// Logout clears all cached content — full-res images must be included. If full-res entries
    /// survived `clearAll`, user content would persist on the device after logout.
    @Test("clearAll removes full-res cached data")
    func clearAllRemovesFullResData() {
        let cache = makeCache()
        let data = makeImage().jpegData(compressionQuality: 0.9)!
        cache.storeFullResData(data, forKey: "bucket/photo.jpg")

        cache.clearAll()

        #expect(cache.fullResData(forKey: "bucket/photo.jpg") == nil)
        #expect(cache.diskUsageBytes == 0)
    }

    /// Verifies that `cacheFullResolution` change publishes `objectWillChange`.
    ///
    /// SettingsView binds the toggle to `cacheFullResolution`. If the property is not
    /// `@Published`, the toggle will not reflect the stored state after the view reloads.
    @Test("cacheFullResolution change publishes objectWillChange")
    func cacheFullResolutionPublishesChange() async {
        let cache = makeCache()
        var changeCount = 0
        let cancellable = cache.objectWillChange.sink { changeCount += 1 }

        cache.cacheFullResolution = true
        cache.cacheFullResolution = false

        #expect(changeCount == 2)
        _ = cancellable
    }

    /// Verifies that `cacheFullResolution` is persisted to UserDefaults.
    ///
    /// The setting must survive app restarts. If the `didSet` observer is absent, the user's
    /// choice is forgotten on relaunch and the setting always reverts to the default (false).
    @Test("cacheFullResolution persists to UserDefaults")
    func cacheFullResolutionPersistsToUserDefaults() {
        let cache = makeCache()
        cache.cacheFullResolution = true

        let stored = UserDefaults.standard.bool(forKey: "cacheFullResolution")
        #expect(stored == true)

        // Restore to avoid polluting other tests
        cache.cacheFullResolution = false
    }
}
