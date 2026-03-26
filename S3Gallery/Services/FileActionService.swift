import Foundation
import Photos

enum FileAction {
    case share, openIn, saveToPhotos, copyToFiles
}

enum FileActionError: LocalizedError {
    case downloadFailed(String)
    case photoLibraryDenied

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .photoLibraryDenied: return "Photo library access is denied. Allow access in Settings to save files."
        }
    }
}

@Observable
@MainActor
final class FileActionService {
    var isDownloading = false

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Downloads the file at `presignedURL` to a unique temp directory.
    /// Returns the local URL. Caller is responsible for calling `cleanup(url:)`.
    func download(presignedURL: URL, fileName: String) async throws -> URL {
        isDownloading = true
        defer { isDownloading = false }

        #if DEBUG
        if UITestArgs.mockFileAction {
            return try stubFile(named: fileName)
        }
        #endif

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(fileName)

        let (tmpURL, response) = try await session.download(from: presignedURL)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            try? FileManager.default.removeItem(at: dir)
            throw FileActionError.downloadFailed("HTTP \(http.statusCode)")
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmpURL, to: dest)
        return dest
    }

    /// Removes the UUID-prefixed temp directory that contains `url`.
    func cleanup(url: URL) {
        let parent = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: parent)
    }

    /// Saves the file at `localURL` to the photo library. Only valid for image and video categories.
    func saveToPhotos(localURL: URL, category: FileCategory) async throws {
        guard category == .image || category == .video else { return }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw FileActionError.photoLibraryDenied
        }

        let url = localURL
        let cat = category
        try await PHPhotoLibrary.shared().performChanges {
            if cat == .image {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            } else {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        }
    }

    // MARK: - Private

    #if DEBUG
    private func stubFile(named fileName: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(fileName)
        try Data("stub".utf8).write(to: dest)
        return dest
    }
    #endif
}
