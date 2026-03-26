import SwiftUI

struct BrowserGridView: View {
    let items: [S3Item]
    let s3Service: any S3ServiceProtocol
    let viewModel: BrowserViewModel
    let onSelectItem: (S3Item) -> Void
    let onAction: (S3FileItem, FileAction) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(items) { item in
                    GridCell(
                        item: item,
                        s3Service: s3Service,
                        isSelected: isSelected(item)
                    )
                    .onTapGesture {
                        if viewModel.isSelectionMode, case .file(let fi) = item {
                            viewModel.toggleSelection(fi)
                        } else {
                            onSelectItem(item)
                        }
                    }
                    .contextMenu {
                        if case .file(let fi) = item {
                            fileContextMenu(for: fi)
                        }
                    }
                }
            }
        }
    }

    private func isSelected(_ item: S3Item) -> Bool {
        guard case .file(let fi) = item else { return false }
        return viewModel.selectedItems.contains(fi)
    }

    @ViewBuilder
    private func fileContextMenu(for item: S3FileItem) -> some View {
        let category = FileTypeDetector.category(for: item)

        Button { onAction(item, .share) } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Button { onAction(item, .openIn) } label: {
            Label("Open In", systemImage: "arrow.up.forward.app")
        }
        if category == .image || category == .video {
            Button { onAction(item, .saveToPhotos) } label: {
                Label("Save to Photos", systemImage: "square.and.arrow.down")
            }
        }
        Button { onAction(item, .copyToFiles) } label: {
            Label("Copy to Files", systemImage: "folder.badge.plus")
        }
        Divider()
        Button {
            viewModel.enterSelectionMode()
            viewModel.toggleSelection(item)
        } label: {
            Label("Select", systemImage: "checkmark.circle")
        }
        .accessibilityIdentifier("context-menu-select")
    }
}

private struct GridCell: View {
    let item: S3Item
    let s3Service: any S3ServiceProtocol
    var isSelected: Bool = false

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

            if isSelected {
                Color.accentColor.opacity(0.25)
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.white, Color.accentColor)
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 110)
        .clipShape(Rectangle())
        .task { await loadThumbnail() }
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
