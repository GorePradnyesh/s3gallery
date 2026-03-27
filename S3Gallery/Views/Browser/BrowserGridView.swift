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

    // Palette of two-tone complementary gradient pairs (top-leading → bottom-trailing)
    private static let gradientPairs: [(Color, Color)] = [
        (Color(hue: 0.58, saturation: 0.75, brightness: 0.90),
         Color(hue: 0.47, saturation: 0.65, brightness: 0.82)), // blue → teal
        (Color(hue: 0.78, saturation: 0.70, brightness: 0.82),
         Color(hue: 0.90, saturation: 0.65, brightness: 0.78)), // purple → pink
        (Color(hue: 0.10, saturation: 0.80, brightness: 0.95),
         Color(hue: 0.03, saturation: 0.82, brightness: 0.88)), // orange → red
        (Color(hue: 0.48, saturation: 0.68, brightness: 0.80),
         Color(hue: 0.37, saturation: 0.62, brightness: 0.75)), // teal → green
        (Color(hue: 0.65, saturation: 0.72, brightness: 0.82),
         Color(hue: 0.78, saturation: 0.68, brightness: 0.78)), // indigo → purple
        (Color(hue: 0.94, saturation: 0.72, brightness: 0.88),
         Color(hue: 0.08, saturation: 0.80, brightness: 0.95)), // pink → amber
    ]

    private var tileGradientColors: (Color, Color) {
        switch item {
        case .folder:
            return Self.gradientPairs[0] // blue → teal
        case .file(let f):
            switch FileTypeDetector.category(for: f) {
            case .image:  return Self.gradientPairs[4] // indigo → purple
            case .video:  return Self.gradientPairs[1] // purple → pink
            case .audio:  return Self.gradientPairs[2] // orange → red
            case .pdf:    return Self.gradientPairs[5] // pink → amber
            case .other:
                return (Color(hue: 0.60, saturation: 0.15, brightness: 0.45),
                        Color(hue: 0.60, saturation: 0.10, brightness: 0.38))
            }
        }
    }

    private var tileLinearGradient: LinearGradient {
        let (c1, c2) = tileGradientColors
        return LinearGradient(colors: [c1.opacity(0.6), c2.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var fileExtension: String {
        guard case .file(let f) = item else { return "" }
        return URL(fileURLWithPath: f.name).pathExtension.uppercased()
    }

    var body: some View {
        ZStack {
            if let thumb = thumbnail {
                Color(.secondarySystemBackground)
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFit()
            } else {
                tileLinearGradient
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if case .folder = item {
                    VStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                        Text(item.name)
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }
                } else {
                    let ext = fileExtension
                    VStack(spacing: 4) {
                        if ext.isEmpty {
                            Image(systemName: item.systemImageName)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        } else {
                            Text(ext)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        Text(item.name)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                    }
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

        let cacheKey = "\(fileItem.bucket)/\(fileItem.key)"
        let thumbKey = cacheKey + "?thumb"

        if let cached = CacheService.shared.thumbnail(forKey: thumbKey) {
            thumbnail = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let url = try await s3Service.presignedURL(for: fileItem, ttl: 900)
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let full = UIImage(data: data) else { return }

            // Store full-res data if the setting is enabled
            if CacheService.shared.cacheFullResolution {
                CacheService.shared.storeFullResData(data, forKey: cacheKey)
            }

            // Scale to 1/4 resolution (half each dimension), capped at HD
            let thumb = await full.thumbnailScaled(to: full.quarterResolutionSize)
            CacheService.shared.storeThumbnail(thumb, forKey: thumbKey)
            thumbnail = thumb
        } catch {
            // Fall through to placeholder icon
        }
    }
}

// MARK: - UIImage thumbnail helper

private extension UIImage {
    /// 1/4 of the original pixel count (half each dimension), capped at HD (1920×1080).
    var quarterResolutionSize: CGSize {
        let quarter = CGSize(width: size.width / 2, height: size.height / 2)
        let hdCap = CGSize(width: 1920, height: 1080)
        let capScale = min(hdCap.width / quarter.width, hdCap.height / quarter.height)
        guard capScale < 1 else { return quarter }
        return CGSize(width: (quarter.width * capScale).rounded(), height: (quarter.height * capScale).rounded())
    }

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
