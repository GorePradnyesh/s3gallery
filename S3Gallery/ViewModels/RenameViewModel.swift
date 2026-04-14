import Foundation
import Observation

enum RenameFolderError: LocalizedError {
    case alreadyExists(String)
    case emptyName

    var errorDescription: String? {
        switch self {
        case .alreadyExists(let name):
            return "A folder named \"\(name)\" already exists here."
        case .emptyName:
            return "Folder name cannot be empty."
        }
    }
}

@Observable
@MainActor
final class RenameViewModel {

    enum Phase: Equatable {
        case idle
        case checking
        case renaming(completed: Int, total: Int)
    }

    private(set) var phase: Phase = .idle

    let folderName: String
    let folderPrefix: String   // e.g. "2024/photos/" — always ends with "/"
    let bucket: String
    private let s3Service: any S3ServiceProtocol

    init(
        folderName: String,
        folderPrefix: String,
        bucket: String,
        s3Service: any S3ServiceProtocol
    ) {
        self.folderName = folderName
        self.folderPrefix = folderPrefix
        self.bucket = bucket
        self.s3Service = s3Service
    }

    var isRenaming: Bool {
        switch phase {
        case .checking, .renaming: return true
        case .idle: return false
        }
    }

    // MARK: - Rename

    /// Renames the folder to `newName`. Throws on conflict or S3 errors; resets phase to `.idle` on failure.
    func rename(to newName: String) async throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { throw RenameFolderError.emptyName }

        // Derive the parent prefix and build the new prefix
        let withoutSlash = String(folderPrefix.dropLast())
        let parentPrefix: String
        if let lastSlash = withoutSlash.lastIndex(of: "/") {
            parentPrefix = String(withoutSlash[...lastSlash])
        } else {
            parentPrefix = ""
        }
        let newPrefix = parentPrefix + trimmedName + "/"

        guard newPrefix != folderPrefix else { return }

        phase = .checking
        do {
            let exists = try await s3Service.prefixExists(bucket: bucket, prefix: newPrefix)
            guard !exists else { throw RenameFolderError.alreadyExists(trimmedName) }

            let keys = try await s3Service.listAllObjects(bucket: bucket, prefix: folderPrefix)

            if keys.isEmpty {
                // No S3 objects found — create a probe file in the new location
                try await s3Service.createFolder(bucket: bucket, key: newPrefix + ".s3gallery-probe")
                phase = .idle
                return
            }

            let total = keys.count
            for (i, key) in keys.enumerated() {
                phase = .renaming(completed: i, total: total)
                let relPath = String(key.dropFirst(folderPrefix.count))
                let destKey = newPrefix + relPath
                try await s3Service.copyObject(bucket: bucket, sourceKey: key, destKey: destKey)
                try await s3Service.deleteObject(bucket: bucket, key: key)
            }
            phase = .idle
        } catch {
            phase = .idle
            throw error
        }
    }
}
