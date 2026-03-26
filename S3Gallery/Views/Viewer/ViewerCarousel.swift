import SwiftUI

struct ViewerCarousel: View {
    let items: [S3FileItem]
    let initialIndex: Int
    let s3Service: any S3ServiceProtocol

    @State private var currentIndex: Int

    init(items: [S3FileItem], initialIndex: Int, s3Service: any S3ServiceProtocol) {
        self.items = items
        self.initialIndex = initialIndex
        self.s3Service = s3Service
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ViewerContainer(item: item, s3Service: s3Service)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }
}
