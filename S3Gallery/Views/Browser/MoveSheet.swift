import SwiftUI

struct MoveSheet: View {
    @State var viewModel: MoveViewModel
    let onComplete: () -> Void
    let onDismiss: () -> Void

    @State private var showCreateFolder = false
    @State private var createFolderError: String?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .browsing, .checkingConflicts, .conflictsFound:
                    pickerContent
                case .moving(let completed, let total, let currentFile):
                    movingContent(completed: completed, total: total, currentFile: currentFile)
                case .done(let failures):
                    doneContent(failures: failures)
                }
            }
            .navigationTitle(viewModel.currentFolderDisplayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .task { await viewModel.loadRoot() }
        .alert("Overwrite Files?", isPresented: conflictAlertBinding) {
            Button("Cancel", role: .cancel) { viewModel.cancelOverwrite() }
            Button("Overwrite", role: .destructive) {
                Task { await viewModel.confirmOverwrite() }
            }
        } message: {
            if case .conflictsFound(let names) = viewModel.phase {
                if names.count == 1 {
                    Text("\"\(names[0])\" already exists here and will be overwritten.")
                } else {
                    Text("\(names.count) files already exist here and will be overwritten.")
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.loadError != nil },
            set: { if !$0 { } }
        )) {
            Button("OK") { }
        } message: {
            Text(viewModel.loadError ?? "")
        }
        .sheet(isPresented: $showCreateFolder, onDismiss: { createFolderError = nil }) {
            MoveCreateFolderSheet(
                error: createFolderError,
                onCreate: { name in
                    Task {
                        do {
                            try await viewModel.createFolder(named: name)
                            showCreateFolder = false
                        } catch CreateFolderError.alreadyExists {
                            createFolderError = "A folder with this name already exists."
                        } catch {
                            createFolderError = error.localizedDescription
                        }
                    }
                },
                onDismiss: {
                    createFolderError = nil
                    showCreateFolder = false
                }
            )
        }
    }

    // MARK: - Picker

    private var pickerContent: some View {
        VStack(spacing: 0) {
            limitationBanner

            if let state = viewModel.currentPickerState {
                BreadcrumbBar(state: state) { targetState in
                    Task { await viewModel.navigate(to: targetState) }
                }
                Divider()
            }

            folderList

            moveHereButton
        }
    }

    private var limitationBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("Moving within \"\(viewModel.bucket)\" only. Cross-bucket moves coming in a future version.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private var folderList: some View {
        switch viewModel.pickerLoadState {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let msg):
            ContentUnavailableView(
                "Failed to Load",
                systemImage: "exclamationmark.triangle",
                description: Text(msg)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            if viewModel.pickerFolders.isEmpty {
                ContentUnavailableView(
                    "No Subfolders",
                    systemImage: "folder",
                    description: Text("You can move files here or create a new folder.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.pickerFolders, id: \.id) { item in
                    if case .folder(let name, let prefix) = item {
                        Button {
                            Task { await viewModel.enterFolder(prefix: prefix) }
                        } label: {
                            Label(name, systemImage: "folder.fill")
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var moveHereButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                Task { await viewModel.requestMove() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isCheckingConflicts {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(moveHereLabel)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canMoveHere || viewModel.isCheckingConflicts)
            .accessibilityIdentifier("move-here-button")
            .padding(16)
            .background(.bar)
        }
    }

    private var moveHereLabel: String {
        let count = viewModel.filesToMove.count
        return "Move \(count) \(count == 1 ? "File" : "Files") Here"
    }

    // MARK: - Moving progress

    private func movingContent(completed: Int, total: Int, currentFile: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView(value: Double(completed), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .padding(.horizontal, 32)
            Text("Moving \(completed + 1) of \(total)")
                .font(.headline)
            Text(currentFile)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Done

    @ViewBuilder
    private func doneContent(failures: [MoveFailure]) -> some View {
        if failures.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Move Complete")
                    .font(.headline)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                onComplete()
                onDismiss()
            }
        } else {
            VStack(spacing: 0) {
                List {
                    Section {
                        ForEach(failures) { failure in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(failure.fileName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(failure.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Label("\(failures.count) file(s) had issues", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                VStack(spacing: 0) {
                    Divider()
                    Button("Done") {
                        onComplete()
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("move-sheet-done-button")
                    .padding(16)
                    .background(.bar)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { onDismiss() }
                .disabled(viewModel.isMovingInProgress)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if case .browsing = viewModel.phase {
                Button {
                    showCreateFolder = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                }
                .accessibilityLabel("New Folder")
            }
        }
    }

    // MARK: - Helpers

    private var conflictAlertBinding: Binding<Bool> {
        Binding(
            get: {
                if case .conflictsFound = viewModel.phase { return true }
                return false
            },
            set: { isPresented in
                if !isPresented { viewModel.cancelOverwrite() }
            }
        )
    }
}

// MARK: - Inline folder creation sheet

private struct MoveCreateFolderSheet: View {
    let error: String?
    let onCreate: (String) -> Void
    let onDismiss: () -> Void

    @State private var folderName = ""

    private var trimmedName: String { folderName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Folder name", text: $folderName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: folderName) { _, new in
                            var sanitised = new.replacingOccurrences(of: "/", with: "")
                            if sanitised.count > 25 { sanitised = String(sanitised.prefix(25)) }
                            if sanitised != new { folderName = sanitised }
                        }
                } footer: {
                    HStack(alignment: .top) {
                        if let error {
                            Text(error).foregroundStyle(.red)
                        }
                        Spacer()
                        Text("\(folderName.count)/25")
                            .foregroundStyle(folderName.count == 25 ? .orange : .secondary)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", role: .cancel) { onDismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { onCreate(trimmedName) }
                        .disabled(trimmedName.isEmpty)
                        .accessibilityIdentifier("create-folder-button")
                }
            }
        }
    }
}
