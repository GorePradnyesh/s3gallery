import SwiftUI

func clampedColumnCount(current: Int, scale: CGFloat) -> Int {
    let raw = Double(current) / Double(scale)
    return max(3, min(20, Int(raw.rounded())))
}

struct BrowserGridView: View {
    let items: [S3Item]
    let s3Service: any S3ServiceProtocol
    let viewModel: BrowserViewModel
    @Binding var columnCount: Int
    let onSelectItem: (S3Item) -> Void
    let onAction: (S3FileItem, FileAction) -> Void

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 2) {
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
            // Attaches a UIPinchGestureRecognizer to the parent UIScrollView so pinch
            // takes priority over scroll — SwiftUI's MagnificationGesture conflicts with
            // ScrollView's own pan recognizer and causes accidental scrolling.
            .background(GridPinchHandler(columnCount: $columnCount))
        }
        .accessibilityIdentifier("grid-scroll-view")
        .accessibilityValue("\(columnCount)")
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

// MARK: - Pinch handler

// Transparent view placed inside the ScrollView content. On first layout it walks
// up the UIKit hierarchy to find the UIScrollView, then attaches a
// UIPinchGestureRecognizer directly to it. During a pinch:
//   • scrolling is disabled so two-finger panning doesn't interfere
//   • columnCount updates live for immediate visual feedback
//   • scrolling re-enables when the pinch ends/cancels
private struct GridPinchHandler: UIViewRepresentable {
    @Binding var columnCount: Int

    func makeCoordinator() -> Coordinator { Coordinator($columnCount) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.columnCount = $columnCount
        guard context.coordinator.attachedScrollView == nil else { return }
        DispatchQueue.main.async {
            guard context.coordinator.attachedScrollView == nil,
                  let sv = uiView.firstAncestor(ofType: UIScrollView.self) else { return }
            context.coordinator.attach(to: sv)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var columnCount: Binding<Int>
        weak var attachedScrollView: UIScrollView?
        private var startCount = 0

        init(_ binding: Binding<Int>) { self.columnCount = binding }

        func attach(to scrollView: UIScrollView) {
            attachedScrollView = scrollView
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handle(_:)))
            pinch.delegate = self
            scrollView.addGestureRecognizer(pinch)
        }

        @objc func handle(_ r: UIPinchGestureRecognizer) {
            switch r.state {
            case .began:
                startCount = columnCount.wrappedValue
                attachedScrollView?.isScrollEnabled = false
            case .changed:
                columnCount.wrappedValue = clampedColumnCount(current: startCount, scale: r.scale)
            case .ended, .cancelled, .failed:
                columnCount.wrappedValue = clampedColumnCount(current: startCount, scale: r.scale)
                attachedScrollView?.isScrollEnabled = true
            default:
                break
            }
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

private extension UIView {
    func firstAncestor<T: UIView>(ofType: T.Type) -> T? {
        var v: UIView? = superview
        while let current = v {
            if let typed = current as? T { return typed }
            v = current.superview
        }
        return nil
    }
}

// MARK: - Grid cell

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
        .aspectRatio(1, contentMode: .fit)
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
