import Foundation
import Observation

enum ViewerLoadState: Equatable {
    case idle
    case loading
    case ready(URL)
    case error(String)
}

@Observable
final class ViewerViewModel {
    var loadState: ViewerLoadState = .idle
    var fileCategory: FileCategory = .other

    private let item: S3FileItem
    private let s3Service: any S3ServiceProtocol
    private let presignTTL: TimeInterval = 900 // 15 minutes

    init(item: S3FileItem, s3Service: any S3ServiceProtocol) {
        self.item = item
        self.s3Service = s3Service
        self.fileCategory = FileTypeDetector.category(for: item)
    }

    var fileName: String { item.name }
    var fileSize: String { item.formattedSize }

    func loadPresignedURL() async {
        guard case .idle = loadState else { return }
        loadState = .loading
        do {
            let url = try await s3Service.presignedURL(for: item, ttl: presignTTL)
            loadState = .ready(url)
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    func retry() async {
        loadState = .idle
        await loadPresignedURL()
    }
}
