import Foundation
import UIKit

@MainActor
final class CacheService: ObservableObject {
    static let shared = CacheService()

    /// Creates an isolated instance for unit tests using a unique temp directory.
    static func makeTestInstance(maxDiskSizeMB: Int = 50, cacheFullResolution: Bool = false) -> CacheService {
        let instance = CacheService(maxDiskSizeMB: maxDiskSizeMB, directoryName: "S3GalleryThumbnailsTest_\(UUID().uuidString)")
        instance.cacheFullResolution = cacheFullResolution
        return instance
    }

    @Published private(set) var diskUsageBytes: Int64 = 0

    private let memoryCache = NSCache<NSString, UIImage>()
    private let cacheDirectory: URL
    private let fileManager = FileManager.default
    private let maxMemoryCostMB = 50

    @Published var maxDiskSizeMB: Int {
        didSet {
            UserDefaults.standard.set(maxDiskSizeMB, forKey: "cacheMaxDiskSizeMB")
        }
    }

    @Published var cacheFullResolution: Bool {
        didSet {
            UserDefaults.standard.set(cacheFullResolution, forKey: "cacheFullResolution")
        }
    }

    var maxDiskSizeBytes: Int64 { Int64(maxDiskSizeMB) * 1_000_000 }

    private init(maxDiskSizeMB: Int? = nil, directoryName: String = "S3GalleryThumbnails") {
        self.maxDiskSizeMB = maxDiskSizeMB
            ?? UserDefaults.standard.integer(forKey: "cacheMaxDiskSizeMB").nonZero
            ?? 200
        self.cacheFullResolution = UserDefaults.standard.bool(forKey: "cacheFullResolution")

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = caches.appending(path: directoryName, directoryHint: .isDirectory)

        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        memoryCache.totalCostLimit = maxMemoryCostMB * 1_000_000

        Task { await refreshDiskUsage() }
    }

    // MARK: - Public API

    func thumbnail(forKey key: String) -> UIImage? {
        let cacheKey = key as NSString
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }
        let fileURL = diskURL(for: key)
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data)
        else { return nil }

        // Update access time for LRU
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: fileURL.path
        )
        let cost = data.count
        memoryCache.setObject(image, forKey: cacheKey, cost: cost)
        return image
    }

    func storeThumbnail(_ image: UIImage, forKey key: String) {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let cacheKey = key as NSString
        memoryCache.setObject(image, forKey: cacheKey, cost: data.count)

        let fileURL = diskURL(for: key)
        try? fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)

        Task { await refreshDiskUsage() }
        Task { await evictIfNeeded() }
    }

    /// Returns cached full-resolution image data for `key`, or nil if not cached.
    func fullResData(forKey key: String) -> Data? {
        let fileURL = diskURL(for: key + "?fullres")
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        return try? Data(contentsOf: fileURL)
    }

    /// Persists raw image data as a full-resolution cache entry for `key`.
    func storeFullResData(_ data: Data, forKey key: String) {
        let fileURL = diskURL(for: key + "?fullres")
        try? fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: fileURL, options: .atomic)
        Task { await refreshDiskUsage() }
        Task { await evictIfNeeded() }
    }

    func clearAll() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        diskUsageBytes = 0
    }

    // MARK: - Private helpers

    private func diskURL(for key: String) -> URL {
        // Sanitize key: replace slashes and ? with path-safe chars
        let sanitized = key
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cacheDirectory.appending(path: sanitized)
    }

    private func refreshDiskUsage() {
        let usage = (try? cacheDirectory.directorySize(fileManager: fileManager)) ?? 0
        diskUsageBytes = usage
    }

    private func evictIfNeeded() {
        guard diskUsageBytes > maxDiskSizeBytes else { return }

        let contents = (try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        )) ?? []

        // Sort by modification date ascending (oldest first)
        let sorted = contents.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return aDate < bDate
        }

        var currentSize = diskUsageBytes
        let targetSize = Int64(Double(maxDiskSizeBytes) * 0.8)

        for url in sorted {
            guard currentSize > targetSize else { break }
            let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
            try? fileManager.removeItem(at: url)
            currentSize -= fileSize
        }

        Task { await refreshDiskUsage() }
    }
}

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

private extension URL {
    func directorySize(fileManager: FileManager) throws -> Int64 {
        var total: Int64 = 0
        let contents = try fileManager.contentsOfDirectory(
            at: self,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        )
        for url in contents {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init) ?? 0
            total += size
        }
        return total
    }
}
