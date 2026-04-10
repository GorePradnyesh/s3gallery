import Foundation
import UniformTypeIdentifiers

enum FileCategory {
    case image
    case video
    case pdf
    case audio
    case other
}

enum FileTypeDetector {
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "tif", "bmp", "raw"
    ]
    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "wmv", "3gp", "webm"
    ]
    private static let audioExtensions: Set<String> = [
        "mp3", "aac", "m4a", "flac", "wav", "aiff", "ogg", "opus", "wma"
    ]

    // Built once at load; covers all natively previewable extensions without UTType overhead.
    static let previewableExtensions: Set<String> =
        imageExtensions.union(videoExtensions).union(audioExtensions).union(["pdf"])

    /// Returns true if the app has a native viewer for this extension.
    /// Checks the pre-built set first (O(1)), then falls back to UTType for uncommon extensions.
    static func canPreview(_ fileExtension: String) -> Bool {
        let ext = fileExtension.lowercased()
        if previewableExtensions.contains(ext) { return true }
        if let utType = UTType(filenameExtension: ext) {
            return utType.conforms(to: .image) || utType.conforms(to: .movie)
                || utType.conforms(to: .audio) || utType.conforms(to: .pdf)
        }
        return false
    }

    static func category(for fileExtension: String) -> FileCategory {
        let ext = fileExtension.lowercased()

        if ext == "pdf" { return .pdf }
        if imageExtensions.contains(ext) { return .image }
        if videoExtensions.contains(ext) { return .video }
        if audioExtensions.contains(ext) { return .audio }

        // Fallback: check UTType conformance
        if let utType = UTType(filenameExtension: ext) {
            if utType.conforms(to: .image) { return .image }
            if utType.conforms(to: .movie) { return .video }
            if utType.conforms(to: .audio) { return .audio }
            if utType.conforms(to: .pdf) { return .pdf }
        }

        return .other
    }

    static func category(for item: S3FileItem) -> FileCategory {
        category(for: item.fileExtension)
    }
}
