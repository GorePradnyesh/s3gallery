import SwiftUI

struct ViewerCarousel: View {
    let items: [S3FileItem]
    let initialIndex: Int
    let s3Service: any S3ServiceProtocol

    @State private var currentIndex: Int
    @State private var shareActions: [Int: () -> Void] = [:]
    @Environment(\.dismiss) private var dismiss

    init(items: [S3FileItem], initialIndex: Int, s3Service: any S3ServiceProtocol) {
        self.items = items
        self.initialIndex = initialIndex
        self.s3Service = s3Service
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ViewerContainer(item: item, s3Service: s3Service, index: index) { idx, action in
                        if let action {
                            shareActions[idx] = action
                        } else {
                            shareActions.removeValue(forKey: idx)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .navigationTitle(items[currentIndex].name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let share = shareActions[currentIndex] {
                        Button { share() } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share")
                        .accessibilityIdentifier("Share")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
