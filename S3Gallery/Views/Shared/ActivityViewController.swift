import SwiftUI
import UIKit

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onDismiss: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            onDismiss?()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
