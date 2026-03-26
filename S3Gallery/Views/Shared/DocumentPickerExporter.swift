import SwiftUI
import UIKit

struct DocumentPickerExporter: UIViewControllerRepresentable {
    let urls: [URL]
    var onDismiss: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onDismiss: (() -> Void)?
        init(onDismiss: (() -> Void)?) { self.onDismiss = onDismiss }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDismiss?()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onDismiss?()
        }
    }
}
