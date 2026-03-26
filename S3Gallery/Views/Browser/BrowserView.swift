import SwiftUI

private enum BrowserSheet: Identifiable {
    case viewer(S3FileItem)
    case upload(BrowseState)
    case share([URL])
    case copyToFiles([URL])

    var id: String {
        switch self {
        case .viewer(let item): return "viewer-\(item.id)"
        case .upload(let state): return "upload-\(state.bucket)-\(state.prefix)"
        case .share: return "share"
        case .copyToFiles: return "copyToFiles"
        }
    }
}

struct BrowserView: View {
    @Bindable var viewModel: BrowserViewModel
    let credentials: Credentials
    let onLogout: () -> Void

    @State private var viewMode: ViewMode = .grid
    @State private var activeSheet: BrowserSheet?
    @State private var fileActionService = FileActionService()
    @State private var isDownloadingForAction = false
    @State private var actionError: String?

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
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .viewer(let item):
                    ViewerContainer(item: item, s3Service: viewModel.s3Service)
                case .upload(let state):
                    UploadSheet(
                        viewModel: UploadViewModel(
                            bucket: state.bucket,
                            prefix: state.prefix,
                            s3Service: viewModel.s3Service
                        ),
                        onSuccess: { await viewModel.refresh() },
                        onDismiss: { activeSheet = nil }
                    )
                case .share(let urls):
                    ActivityViewController(activityItems: urls) {
                        urls.forEach { fileActionService.cleanup(url: $0) }
                        activeSheet = nil
                    }
                case .copyToFiles(let urls):
                    DocumentPickerExporter(urls: urls) {
                        urls.forEach { fileActionService.cleanup(url: $0) }
                        activeSheet = nil
                    }
                }
            }
            .alert("Action Failed", isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )) {
                Button("OK") { actionError = nil }
            } message: {
                Text(actionError ?? "")
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
            .overlay(alignment: .bottomTrailing) {
                if !viewModel.isSelectionMode {
                    uploadFAB
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
            .overlay(alignment: .bottom) {
                if isDownloadingForAction {
                    downloadingOverlay
                }
            }

            if viewModel.isSelectionMode {
                SelectionActionBar(
                    selectedCount: viewModel.selectedItems.count,
                    canSaveToPhotos: viewModel.canSaveSelectedToPhotos,
                    onShare: { handleBulkAction(.share) },
                    onOpenIn: { handleBulkAction(.openIn) },
                    onSaveToPhotos: { handleBulkAction(.saveToPhotos) },
                    onCopyToFiles: { handleBulkAction(.copyToFiles) }
                )
            }
        }
    }

    private var downloadingOverlay: some View {
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

    @ViewBuilder
    private var uploadFAB: some View {
        if viewModel.isCheckingWriteAccess {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 56, height: 56)
                ProgressView()
            }
            .shadow(radius: 4)
        } else if let hasWrite = viewModel.currentBucketHasWriteAccess {
            Button {
                if hasWrite, let state = viewModel.currentState {
                    activeSheet = .upload(state)
                }
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(hasWrite ? .blue : .secondary)
                        .symbolRenderingMode(.hierarchical)
                    if !hasWrite {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                            .background(Circle().fill(.secondary).padding(-3))
                            .offset(x: 2, y: 2)
                    }
                }
            }
            .disabled(!hasWrite)
            .shadow(radius: 4)
            .accessibilityLabel(hasWrite ? "Upload file" : "Read only bucket")
            .accessibilityIdentifier(hasWrite ? "Upload file" : "Read only bucket")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewMode {
        case .list:
            BrowserListView(
                items: viewModel.sortedItems,
                viewModel: viewModel,
                onSelectItem: { handleSelection($0) },
                onAction: { handleAction($1, items: [$0]) }
            )
        case .grid:
            BrowserGridView(
                items: viewModel.sortedItems,
                s3Service: viewModel.s3Service,
                viewModel: viewModel,
                onSelectItem: { handleSelection($0) },
                onAction: { handleAction($1, items: [$0]) }
            )
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
                if viewModel.isSelectionMode {
                    Button("Done") {
                        viewModel.exitSelectionMode()
                    }
                    .accessibilityIdentifier("Done")
                } else {
                    Button("Select") {
                        viewModel.enterSelectionMode()
                    }
                    .accessibilityIdentifier("Select")
                    SortMenuButton(sortOption: $viewModel.sortOption)
                    ViewModeToggle(mode: $viewMode)
                }
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
            activeSheet = .viewer(fileItem)
        }
    }

    // MARK: - File Actions

    private func handleAction(_ action: FileAction, items: [S3FileItem]) {
        Task {
            guard !items.isEmpty else { return }
            isDownloadingForAction = true
            defer { isDownloadingForAction = false }

            var localURLs: [URL] = []
            for item in items {
                do {
                    let presigned = try await viewModel.s3Service.presignedURL(for: item, ttl: 900)
                    let local = try await fileActionService.download(
                        presignedURL: presigned,
                        fileName: item.name
                    )
                    localURLs.append(local)
                } catch {
                    localURLs.forEach { fileActionService.cleanup(url: $0) }
                    actionError = error.localizedDescription
                    return
                }
            }

            switch action {
            case .share, .openIn:
                activeSheet = .share(localURLs)
            case .saveToPhotos:
                for (url, item) in zip(localURLs, items) {
                    do {
                        try await fileActionService.saveToPhotos(
                            localURL: url,
                            category: FileTypeDetector.category(for: item)
                        )
                    } catch {
                        actionError = error.localizedDescription
                    }
                    fileActionService.cleanup(url: url)
                }
                viewModel.exitSelectionMode()
            case .copyToFiles:
                activeSheet = .copyToFiles(localURLs)
            }
        }
    }

    private func handleBulkAction(_ action: FileAction) {
        let items = Array(viewModel.selectedItems)
        viewModel.exitSelectionMode()
        handleAction(action, items: items)
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
