import SwiftUI

enum ViewMode: String, CaseIterable {
    case list, grid
}

struct BreadcrumbBar: View {
    let state: BrowseState
    let onTap: (BrowseState) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(state.breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Button(crumb.name) {
                        onTap(BrowseState(bucket: crumb.bucket, prefix: crumb.prefix))
                    }
                    .font(.caption)
                    .foregroundStyle(index == state.breadcrumbs.count - 1 ? Color.primary : Color.accentColor)
                    .disabled(index == state.breadcrumbs.count - 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

struct SortMenuButton: View {
    @Binding var sortOption: SortOption

    var body: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    sortOption = option
                } label: {
                    if sortOption == option {
                        Label(option.rawValue, systemImage: "checkmark")
                    } else {
                        Text(option.rawValue)
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .accessibilityLabel("Sort options")
        }
    }
}

struct ViewModeToggle: View {
    @Binding var mode: ViewMode

    var body: some View {
        let label = mode == .list ? "Switch to grid view" : "Switch to list view"
        Button {
            mode = mode == .list ? .grid : .list
        } label: {
            Image(systemName: mode == .list ? "square.grid.2x2" : "list.bullet")
                .accessibilityLabel(label)
                .accessibilityIdentifier(label)
        }
    }
}
