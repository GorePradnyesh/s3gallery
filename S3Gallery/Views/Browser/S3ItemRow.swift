import SwiftUI

struct S3ItemRow: View {
    let item: S3Item
    var thumbnail: UIImage? = nil
    var isSelected: Bool = false
    var inSelectionMode: Bool = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            iconView
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .lineLimit(2)
                    .font(.body)
                if case .file(let fileItem) = item {
                    Text("\(fileItem.formattedSize) · \(Self.dateFormatter.string(from: fileItem.lastModified))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if inSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)
            } else if case .folder = item {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var iconView: some View {
        if let thumb = thumbnail {
            Image(uiImage: thumb)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: item.systemImageName)
                .font(.title2)
                .foregroundStyle(item.iconColor)
                .frame(width: 44, height: 44)
        }
    }
}

// MARK: - S3Item extensions for display

extension S3Item {
    var systemImageName: String {
        switch self {
        case .folder:
            return "folder.fill"
        case .file(let f):
            switch FileTypeDetector.category(for: f) {
            case .image: return "photo.fill"
            case .video: return "play.rectangle.fill"
            case .pdf:   return "doc.fill"
            case .audio: return "music.note"
            case .other: return "doc.fill"
            }
        }
    }

    var iconColor: Color {
        switch self {
        case .folder: return .accentColor
        case .file(let f):
            switch FileTypeDetector.category(for: f) {
            case .image: return .blue
            case .video: return .purple
            case .pdf:   return .red
            case .audio: return .orange
            case .other: return .gray
            }
        }
    }
}
