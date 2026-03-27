import SwiftUI

/// Routes to the correct viewer based on file type.
struct ViewerContainer: View {
    let item: S3FileItem
    let s3Service: any S3ServiceProtocol
    var index: Int
    var onShareReady: (Int, (() -> Void)?) -> Void

    @State private var viewModel: ViewerViewModel
    @State private var fileActionService = FileActionService()
    @State private var shareLocalURL: URL?
    @State private var isPreparingShare = false
    @State private var shareError: String?

    init(
        item: S3FileItem,
        s3Service: any S3ServiceProtocol,
        index: Int = 0,
        onShareReady: @escaping (Int, (() -> Void)?) -> Void = { _, _ in }
    ) {
        self.item = item
        self.s3Service = s3Service
        self.index = index
        self.onShareReady = onShareReady
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
        .onChange(of: viewModel.loadState) { _, newState in
            switch newState {
            case .ready(let url):
                let idx = index
                onShareReady(idx) { [self] in handleShare(presignedURL: url) }
            case .error:
                onShareReady(index, nil)
            default:
                break
            }
        }
        .sheet(isPresented: Binding(
            get: { shareLocalURL != nil },
            set: { if !$0 { cleanupShare() } }
        )) {
            if let local = shareLocalURL {
                ActivityViewController(activityItems: [local]) {
                    cleanupShare()
                }
            }
        }
        .overlay {
            if isPreparingShare {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text("Preparing…")
                            .foregroundStyle(.white)
                            .font(.footnote)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .alert("Share Failed", isPresented: Binding(
            get: { shareError != nil },
            set: { if !$0 { shareError = nil } }
        )) {
            Button("OK") { shareError = nil }
        } message: {
            Text(shareError ?? "")
        }
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
            PhotoViewer(item: item, presignedURL: url, fileName: viewModel.fileName)
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

    // MARK: - Share

    private func handleShare(presignedURL: URL) {
        Task {
            isPreparingShare = true
            defer { isPreparingShare = false }
            do {
                let local = try await fileActionService.download(
                    presignedURL: presignedURL,
                    fileName: item.name
                )
                shareLocalURL = local
            } catch {
                shareError = error.localizedDescription
            }
        }
    }

    private func cleanupShare() {
        if let url = shareLocalURL {
            fileActionService.cleanup(url: url)
        }
        shareLocalURL = nil
    }
}
