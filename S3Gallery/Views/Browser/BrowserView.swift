import SwiftUI

struct BrowserView: View {
    @Bindable var viewModel: BrowserViewModel
    let credentials: Credentials
    let onLogout: () -> Void

    @State private var viewMode: ViewMode = .grid
    @State private var selectedItem: S3FileItem?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isAtRoot {
                    bucketListView
                } else {
                    folderContentView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(viewModel.isAtRoot ? .large : .inline)
            .toolbar { toolbarContent }
            .sheet(item: $selectedItem) { item in
                ViewerContainer(item: item, s3Service: viewModel.s3Service)
            }
        }
        .task { await viewModel.loadBuckets() }
    }

    // MARK: - Subviews

    private var bucketListView: some View {
        Group {
            switch viewModel.loadState {
            case .loading:
                ProgressView("Loading buckets...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let msg):
                errorView(message: msg, retry: { Task { await viewModel.loadBuckets() } })
            default:
                List(viewModel.buckets, id: \.self) { bucket in
                    Button {
                        Task { await viewModel.enterBucket(bucket) }
                    } label: {
                        Label(bucket, systemImage: "externaldrive.fill")
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
                .refreshable { await viewModel.loadBuckets() }
                .overlay {
                    if viewModel.loadState == .loaded && viewModel.buckets.isEmpty {
                        ContentUnavailableView("No Buckets", systemImage: "externaldrive", description: Text("No S3 buckets found for this account."))
                    }
                }
            }
        }
    }

    private var folderContentView: some View {
        VStack(spacing: 0) {
            if let state = viewModel.currentState {
                BreadcrumbBar(state: state) { targetState in
                    Task { await viewModel.navigate(to: targetState) }
                }
                Divider()
            }

            Group {
                switch viewModel.loadState {
                case .loading:
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .error(let msg):
                    errorView(message: msg, retry: { Task { await viewModel.refresh() } })
                default:
                    contentView
                        .refreshable { await viewModel.refresh() }
                        .overlay {
                            if viewModel.loadState == .loaded && viewModel.sortedItems.isEmpty {
                                ContentUnavailableView("Empty Folder", systemImage: "folder", description: Text("This folder contains no files."))
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewMode {
        case .list:
            BrowserListView(items: viewModel.sortedItems) { item in
                handleSelection(item)
            }
        case .grid:
            BrowserGridView(
                items: viewModel.sortedItems,
                s3Service: viewModel.s3Service
            ) { item in
                handleSelection(item)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !viewModel.isAtRoot {
                Button {
                    Task { await viewModel.popToRoot() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "externaldrive")
                        Text("Buckets")
                    }
                }
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            if !viewModel.isAtRoot {
                SortMenuButton(sortOption: $viewModel.sortOption)
                ViewModeToggle(mode: $viewMode)
            }
            NavigationLink {
                SettingsView(
                    credentials: credentials,
                    onLogout: onLogout
                )
            } label: {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("Settings")
            }
        }
    }

    private var navigationTitle: String {
        guard let state = viewModel.currentState else { return "S3 Gallery" }
        return state.prefix.isEmpty ? state.bucket : (state.breadcrumbs.last?.name ?? state.bucket)
    }

    private func handleSelection(_ item: S3Item) {
        switch item {
        case .folder(_, let prefix):
            Task { await viewModel.enterFolder(name: item.name, prefix: prefix) }
        case .file(let fileItem):
            selectedItem = fileItem
        }
    }

    private func errorView(message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

