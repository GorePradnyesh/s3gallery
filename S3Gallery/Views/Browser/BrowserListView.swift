import SwiftUI

struct BrowserListView: View {
    let items: [S3Item]
    let viewModel: BrowserViewModel
    let onSelectItem: (S3Item) -> Void
    let onAction: (S3FileItem, FileAction) -> Void

    @State private var thumbnails: [String: UIImage] = [:]

    var body: some View {
        List(items) { item in
            Button {
                if viewModel.isSelectionMode, case .file(let fi) = item {
                    viewModel.toggleSelection(fi)
                } else {
                    onSelectItem(item)
                }
            } label: {
                S3ItemRow(
                    item: item,
                    thumbnail: thumbnails[item.id],
                    isSelected: isSelected(item),
                    inSelectionMode: viewModel.isSelectionMode
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                if case .file(let fi) = item {
                    fileContextMenu(for: fi)
                }
            }
            .task {
                await loadThumbnail(for: item)
            }
        }
        .listStyle(.plain)
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
        .accessibilityIdentifier("Select")
    }

    private func loadThumbnail(for item: S3Item) async {
        guard case .file(let fileItem) = item,
              FileTypeDetector.category(for: fileItem) == .image
        else { return }

        let key = "\(fileItem.bucket)/\(fileItem.key)?thumb"
        if let cached = CacheService.shared.thumbnail(forKey: key) {
            thumbnails[item.id] = cached
        }
    }
}
