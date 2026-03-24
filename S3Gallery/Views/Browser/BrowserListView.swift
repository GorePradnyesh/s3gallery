import SwiftUI

struct BrowserListView: View {
    let items: [S3Item]
    let onSelectItem: (S3Item) -> Void
    @State private var thumbnails: [String: UIImage] = [:]

    var body: some View {
        List(items) { item in
            Button {
                onSelectItem(item)
            } label: {
                S3ItemRow(item: item, thumbnail: thumbnails[item.id])
            }
            .buttonStyle(.plain)
            .task {
                await loadThumbnail(for: item)
            }
        }
        .listStyle(.plain)
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
