import SwiftUI
import PDFKit

struct PDFViewerView: View {
    let url: URL
    let fileName: String

    var body: some View {
        PDFKitView(url: url)
            .ignoresSafeArea(edges: .bottom)
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
    }
}
