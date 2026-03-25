import SwiftUI

struct BrowserGridView: View {
    let items: [S3Item]
    let s3Service: any S3ServiceProtocol
    let onSelectItem: (S3Item) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(items) { item in
                    GridCell(item: item, s3Service: s3Service)
                        .onTapGesture { onSelectItem(item) }
                }
            }
        }
    }
}

private struct GridCell: View {
    let item: S3Item
    let s3Service: any S3ServiceProtocol

    @State private var thumbnail: UIImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: item.systemImageName)
                            .font(.title2)
                            .foregroundStyle(item.iconColor)
                    }
                    Text(item.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                }
            }
        }
        .frame(height: 110)
        .clipShape(Rectangle())
        .task { await loadThumbnail() }
        .accessibilityLabel(item.name)
    }

    private func loadThumbnail() async {
        guard case .file(let fileItem) = item,
              FileTypeDetector.category(for: fileItem) == .image
        else { return }

        let cacheKey = "\(fileItem.bucket)/\(fileItem.key)?thumb"

        if let cached = CacheService.shared.thumbnail(forKey: cacheKey) {
            thumbnail = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let url = try await s3Service.presignedURL(for: fileItem, ttl: 900)
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let full = UIImage(data: data) else { return }
            let thumb = await full.thumbnailScaled(to: CGSize(width: 300, height: 300))
            CacheService.shared.storeThumbnail(thumb, forKey: cacheKey)
            thumbnail = thumb
        } catch {
            // Fall through to placeholder icon
        }
    }
}

// MARK: - UIImage thumbnail helper

private extension UIImage {
    func thumbnailScaled(to maxSize: CGSize) async -> UIImage {
        await withCheckedContinuation { continuation in
            Task.detached(priority: .utility) {
                let scale = min(maxSize.width / self.size.width, maxSize.height / self.size.height)
                let scaledSize = CGSize(width: self.size.width * scale, height: self.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: scaledSize)
                let thumb = renderer.image { _ in
                    self.draw(in: CGRect(origin: .zero, size: scaledSize))
                }
                continuation.resume(returning: thumb)
            }
        }
    }
}
