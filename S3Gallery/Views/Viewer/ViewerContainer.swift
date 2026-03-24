import SwiftUI

/// Routes to the correct viewer based on file type.
struct ViewerContainer: View {
    let item: S3FileItem
    let s3Service: any S3ServiceProtocol

    @State private var viewModel: ViewerViewModel

    init(item: S3FileItem, s3Service: any S3ServiceProtocol) {
        self.item = item
        self.s3Service = s3Service
        self._viewModel = State(initialValue: ViewerViewModel(item: item, s3Service: s3Service))
    }

    var body: some View {
        Group {
            switch viewModel.loadState {
            case .idle, .loading:
                loadingView
            case .ready(let url):
                viewerForCategory(url: url)
            case .error(let message):
                errorView(message: message)
            }
        }
        .task { await viewModel.loadPresignedURL() }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Preparing \(viewModel.fileName)...")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func viewerForCategory(url: URL) -> some View {
        switch viewModel.fileCategory {
        case .image:
            PhotoViewer(url: url, fileName: viewModel.fileName)
        case .video:
            VideoPlayerView(url: url, fileName: viewModel.fileName)
        case .pdf:
            PDFViewerView(url: url, fileName: viewModel.fileName)
        case .audio:
            AudioPlayerView(url: url, fileName: viewModel.fileName)
        case .other:
            GenericFileView(url: url, fileName: viewModel.fileName)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
