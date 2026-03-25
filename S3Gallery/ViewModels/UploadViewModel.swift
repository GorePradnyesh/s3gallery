import Foundation
import UniformTypeIdentifiers
import Observation

@Observable final class UploadViewModel {
    enum UploadState {
        case idle
        case uploading
        case success(S3FileItem)
        case failure(Error)
    }

    var state: UploadState = .idle

    let bucket: String
    let prefix: String
    let s3Service: any S3ServiceProtocol

    init(bucket: String, prefix: String, s3Service: any S3ServiceProtocol) {
        self.bucket = bucket
        self.prefix = prefix
        self.s3Service = s3Service
    }

    func upload(url: URL) async {
        let filename = url.lastPathComponent
        let contentType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

        guard url.startAccessingSecurityScopedResource() else {
            state = .failure(UploadError.fileAccessDenied)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            await performUpload(data: data, filename: filename, contentType: contentType)
        } catch {
            state = .failure(error)
        }
    }

    func upload(data: Data, filename: String, contentType: String) async {
        await performUpload(data: data, filename: filename, contentType: contentType)
    }

    private func performUpload(data: Data, filename: String, contentType: String) async {
        let uploadKey = key(for: filename)
        state = .uploading
        do {
            try await s3Service.uploadObject(bucket: bucket, key: uploadKey, data: data, contentType: contentType)
            let item = S3FileItem(
                key: uploadKey,
                bucket: bucket,
                size: Int64(data.count),
                lastModified: Date(),
                eTag: nil
            )
            state = .success(item)
        } catch {
            state = .failure(error)
        }
    }

    private func key(for filename: String) -> String {
        prefix + filename
    }
}

enum UploadError: Error, LocalizedError {
    case fileAccessDenied

    var errorDescription: String? {
        switch self {
        case .fileAccessDenied:
            return "Could not access the selected file."
        }
    }
}
