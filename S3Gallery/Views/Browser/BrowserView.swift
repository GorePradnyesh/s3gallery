import SwiftUI

private enum BrowserSheet: Identifiable {
    case viewer(items: [S3FileItem], index: Int)
    case upload(BrowseState, source: UploadSource? = nil)
    case createFolder(BrowseState)
    case share([URL])
    case copyToFiles([URL])

    var id: String {
        switch self {
        case .viewer(let items, let index): return "viewer-\(items[index].id)"
        case .upload(let state, _): return "upload-\(state.bucket)-\(state.prefix)"
        case .createFolder(let state): return "createFolder-\(state.bucket)-\(state.prefix)"
        case .share: return "share"
        case .copyToFiles: return "copyToFiles"
        }
    }
}

struct BrowserView: View {
    @Bindable var viewModel: BrowserViewModel
    let credentials: Credentials
    let onLogout: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var viewMode: ViewMode = .grid
    @State private var gridColumnCount: Int = Self.defaultGridColumnCount()

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
                case .viewer(let items, let index):
                    ViewerCarousel(items: items, initialIndex: index, s3Service: viewModel.s3Service)
                case .upload(let state, let source):
                    UploadSheet(
                        viewModel: UploadViewModel(
                            bucket: state.bucket,
                            prefix: state.prefix,
                            s3Service: viewModel.s3Service
                        ),
                        onSuccess: { await viewModel.refresh() },
                        onDismiss: { activeSheet = nil },
                        initialSource: source
                    )
                case .createFolder(let state):
                    CreateFolderSheet(
                        state: state,
                        viewModel: viewModel,
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
                bucketGrid
            }
        }
    }

    private var bucketGrid: some View {
        ScrollView {
            LazyVGrid(columns: bucketGridColumns, spacing: 12) {
                ForEach(viewModel.buckets, id: \.self) { bucket in
                    BucketTile(name: bucket) {
                        Task { await viewModel.enterBucket(bucket) }
                    }
                }
            }
            .padding(16)
        }
        .refreshable { await viewModel.loadBuckets() }
        .overlay {
            if viewModel.loadState == .loaded && viewModel.buckets.isEmpty {
                ContentUnavailableView("No Buckets", systemImage: "externaldrive", description: Text("No S3 buckets found for this account."))
            }
        }
    }

    private var bucketGridColumns: [GridItem] {
        let isPortrait = horizontalSizeClass == .compact && verticalSizeClass == .regular
        return isPortrait
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
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
                columnCount: $gridColumnCount,
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
                    if horizontalSizeClass == .compact && verticalSizeClass == .regular {
                        Image(systemName: "externaldrive")
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "externaldrive")
                            Text("Buckets")
                        }
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
                    if viewModel.isCheckingWriteAccess {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if viewModel.currentBucketHasWriteAccess == true,
                              let state = viewModel.currentState {
                        Menu {
                            Button {
                                activeSheet = .upload(state, source: .photos)
                            } label: {
                                Label("Photo Library", systemImage: "photo.on.rectangle")
                            }
                            Button {
                                activeSheet = .upload(state, source: .files)
                            } label: {
                                Label("Files", systemImage: "folder")
                            }
                            Divider()
                            Button {
                                activeSheet = .createFolder(state)
                            } label: {
                                Label("New Folder", systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add")
                        .accessibilityIdentifier("Add")
                    }
                    Button {
                        viewModel.enterSelectionMode()
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .accessibilityLabel("Select")
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

    // Target ~130pt per tile: gives 3 columns on all iPhones, ~6 on iPad, ~8 on iPad Pro 13"
    private static func defaultGridColumnCount() -> Int {
        let width = UIScreen.main.bounds.width
        return max(3, min(20, Int((width / 130).rounded())))
    }

    private var navigationTitle: String {
        guard let state = viewModel.currentState else { return "S3 Gallery" }
        if !viewModel.isAtRoot && horizontalSizeClass == .compact && verticalSizeClass == .regular { return "" }
        return state.prefix.isEmpty ? state.bucket : (state.breadcrumbs.last?.name ?? state.bucket)
    }

    private func handleSelection(_ item: S3Item) {
        switch item {
        case .folder(_, let prefix):
            Task { await viewModel.enterFolder(name: item.name, prefix: prefix) }
        case .file(let fileItem):
            if FileTypeDetector.category(for: fileItem) == .image {
                let imageItems = viewModel.sortedItems.compactMap(\.fileItem).filter {
                    FileTypeDetector.category(for: $0) == .image
                }
                let index = imageItems.firstIndex(of: fileItem) ?? 0
                activeSheet = .viewer(items: imageItems, index: index)
            } else {
                activeSheet = .viewer(items: [fileItem], index: 0)
            }
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

// MARK: - Bucket tile

private struct BucketTile: View {
    let name: String
    let onTap: () -> Void

    // 12-pair palette — each pair has a large hue shift (≥0.13) and high saturation
    // so the gradient is clearly visible. Adjacent indices span different hue regions
    // to maximise visual distance for hash-based bucket colour selection.
    private static let gradientPairs: [(Color, Color)] = [
        // 0  cobalt → teal          Δhue ≈ 0.14
        (Color(hue: 0.630, saturation: 0.90, brightness: 0.88), Color(hue: 0.490, saturation: 0.85, brightness: 0.78)),
        // 1  crimson → amber        Δhue ≈ 0.11
        (Color(hue: 0.005, saturation: 0.92, brightness: 0.88), Color(hue: 0.110, saturation: 0.88, brightness: 0.96)),
        // 2  indigo → fuchsia       Δhue ≈ 0.16
        (Color(hue: 0.720, saturation: 0.88, brightness: 0.80), Color(hue: 0.880, saturation: 0.85, brightness: 0.88)),
        // 3  emerald → sky blue     Δhue ≈ 0.16
        (Color(hue: 0.400, saturation: 0.90, brightness: 0.76), Color(hue: 0.560, saturation: 0.82, brightness: 0.90)),
        // 4  purple → hot pink      Δhue ≈ 0.16
        (Color(hue: 0.780, saturation: 0.85, brightness: 0.80), Color(hue: 0.940, saturation: 0.82, brightness: 0.88)),
        // 5  forest green → aqua    Δhue ≈ 0.14
        (Color(hue: 0.370, saturation: 0.88, brightness: 0.72), Color(hue: 0.510, saturation: 0.80, brightness: 0.86)),
        // 6  royal blue → violet    Δhue ≈ 0.13
        (Color(hue: 0.645, saturation: 0.88, brightness: 0.84), Color(hue: 0.760, saturation: 0.84, brightness: 0.78)),
        // 7  orange → magenta       cross-wheel
        (Color(hue: 0.075, saturation: 0.92, brightness: 0.96), Color(hue: 0.870, saturation: 0.85, brightness: 0.84)),
        // 8  teal → lime            Δhue ≈ 0.17
        (Color(hue: 0.500, saturation: 0.88, brightness: 0.80), Color(hue: 0.330, saturation: 0.86, brightness: 0.82)),
        // 9  sky → deep indigo      Δhue ≈ 0.12
        (Color(hue: 0.580, saturation: 0.80, brightness: 0.92), Color(hue: 0.700, saturation: 0.84, brightness: 0.78)),
        // 10 scarlet → gold         Δhue ≈ 0.12
        (Color(hue: 0.025, saturation: 0.90, brightness: 0.90), Color(hue: 0.140, saturation: 0.86, brightness: 0.95)),
        // 11 cyan → deep purple     Δhue ≈ 0.22
        (Color(hue: 0.540, saturation: 0.84, brightness: 0.90), Color(hue: 0.760, saturation: 0.82, brightness: 0.76)),
    ]

    private var gradientColors: (Color, Color) {
        let index = abs(name.hashValue) % Self.gradientPairs.count
        return Self.gradientPairs[index]
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                let (c1, c2) = gradientColors
                LinearGradient(
                    colors: [c1.opacity(0.6), c2.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                HStack(spacing: 10) {
                    Image(systemName: "externaldrive.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                    Text(name)
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
            }
            .aspectRatio(8 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
