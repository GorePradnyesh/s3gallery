import SwiftUI

struct PhotoViewer: View {
    let url: URL
    let fileName: String

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    photoContent(image: image, geo: geo)
                case .failure:
                    ContentUnavailableView("Failed to Load", systemImage: "photo.badge.exclamationmark", description: Text("Could not load the image."))
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .bottom)
    }

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
