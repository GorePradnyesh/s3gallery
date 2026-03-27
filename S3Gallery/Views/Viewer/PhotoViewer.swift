import SwiftUI

struct PhotoViewer: View {
    let item: S3FileItem
    let presignedURL: URL
    let fileName: String

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var displayImage: UIImage?
    @State private var isLoadingFullRes = false
    @State private var loadFailed = false

    var body: some View {
        GeometryReader { geo in
            if loadFailed && displayImage == nil {
                ContentUnavailableView(
                    "Failed to Load",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("Could not load the image.")
                )
            } else if let img = displayImage {
                photoContent(image: Image(uiImage: img), geo: geo)
                    .overlay(alignment: .bottomTrailing) {
                        if isLoadingFullRes {
                            ProgressView()
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(12)
                        }
                    }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .bottom)
        .task { await loadImage() }
    }

    // MARK: - Image loading

    private func loadImage() async {
        let cacheKey = "\(item.bucket)/\(item.key)"

        // 1. Full-res already cached — show immediately, no download needed
        if let data = CacheService.shared.fullResData(forKey: cacheKey),
           let image = UIImage(data: data) {
            displayImage = image
            return
        }

        // 2. Show thumbnail as placeholder while full-res loads
        let thumbKey = cacheKey + "?thumb"
        if let thumb = CacheService.shared.thumbnail(forKey: thumbKey) {
            displayImage = thumb
            isLoadingFullRes = true
        }

        // 3. Debounce: wait before hitting S3 so rapid carousel swipes don't fire many requests.
        //    The .task modifier cancels this task when the view disappears, so the sleep throws
        //    CancellationError and we return without making a network call.
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }

        // 4. Download full-res from presigned URL
        do {
            let (data, _) = try await URLSession.shared.data(from: presignedURL)

            if CacheService.shared.cacheFullResolution {
                CacheService.shared.storeFullResData(data, forKey: cacheKey)
            }

            if let image = UIImage(data: data) {
                displayImage = image
            }
        } catch {
            if displayImage == nil {
                loadFailed = true
            }
        }

        isLoadingFullRes = false
    }

    // MARK: - Gesture interaction

    @ViewBuilder
    private func photoContent(image: Image, geo: GeometryProxy) -> some View {
        let base = image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnifyGesture)
            .onTapGesture(count: 2) { resetZoom() }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()

        if scale > 1 {
            base.gesture(dragGesture)
        } else {
            base
        }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(1, min(lastScale * value, 5))
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 { resetZoom() }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func resetZoom() {
        withAnimation(.spring(duration: 0.3)) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }
}
