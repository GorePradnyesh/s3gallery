import SwiftUI
import QuickLook

struct GenericFileView: View {
    let url: URL
    let fileName: String

    @State private var localURL: URL?
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var downloadProgress: Double = 0

    var body: some View {
        Group {
            if let local = localURL {
                QuickLookView(url: local)
                    .ignoresSafeArea(edges: .bottom)
            } else if let error = downloadError {
                errorView(message: error)
            } else {
                downloadingView
            }
        }
        .task { await download() }
        .onDisappear { cleanupTempFile() }
    }

    private var downloadingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: downloadProgress > 0 ? downloadProgress : nil)
                .progressViewStyle(.circular)
            Text("Downloading...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        ContentUnavailableView(
            "Download Failed",
            systemImage: "arrow.down.circle.badge.exclamationmark",
            description: Text(message)
        )
    }

    private func download() async {
        isDownloading = true
        let tempURL = FileManager.default.temporaryDirectory
            .appending(path: fileName)

        do {
            let (downloadedURL, _) = try await URLSession.shared.download(from: url)
            try? FileManager.default.removeItem(at: tempURL)
            try FileManager.default.moveItem(at: downloadedURL, to: tempURL)
            localURL = tempURL
        } catch {
            downloadError = error.localizedDescription
        }
        isDownloading = false
    }

    private func cleanupTempFile() {
        if let local = localURL {
            try? FileManager.default.removeItem(at: local)
        }
    }
}

private struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}
