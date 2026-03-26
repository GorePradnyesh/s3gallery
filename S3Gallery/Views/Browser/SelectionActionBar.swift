import SwiftUI

struct SelectionActionBar: View {
    let selectedCount: Int
    let canSaveToPhotos: Bool
    let onShare: () -> Void
    let onOpenIn: () -> Void
    let onSaveToPhotos: () -> Void
    let onCopyToFiles: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                actionButton(icon: "square.and.arrow.up", label: "Share", action: onShare)
                Spacer()
                actionButton(icon: "arrow.up.forward.app", label: "Open In", action: onOpenIn)
                if canSaveToPhotos {
                    Spacer()
                    actionButton(icon: "square.and.arrow.down", label: "Save", action: onSaveToPhotos)
                }
                Spacer()
                actionButton(icon: "folder.badge.plus", label: "Files", action: onCopyToFiles)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .disabled(selectedCount == 0)
        .accessibilityIdentifier("SelectionActionBar")
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(label)
    }
}
