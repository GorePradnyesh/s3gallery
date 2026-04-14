import SwiftUI

struct RenameFolderSheet: View {
    @State var viewModel: RenameViewModel
    let onComplete: () -> Void
    let onDismiss: () -> Void

    @State private var newName: String = ""
    @State private var error: String?

    private var trimmedName: String { newName.trimmingCharacters(in: .whitespaces) }
    private var isValid: Bool { !trimmedName.isEmpty && trimmedName != viewModel.folderName }

    var body: some View {
        NavigationStack {
            Group {
                if case .renaming(let completed, let total) = viewModel.phase {
                    renamingContent(completed: completed, total: total)
                } else {
                    formContent
                }
            }
            .navigationTitle("Rename Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .onAppear { newName = viewModel.folderName }
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
            Section {
                TextField("Folder name", text: $newName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: newName) { _, new in
                        var sanitised = new.replacingOccurrences(of: "/", with: "")
                        if sanitised.count > 25 { sanitised = String(sanitised.prefix(25)) }
                        if sanitised != new { newName = sanitised }
                        error = nil
                    }
            } footer: {
                HStack(alignment: .top) {
                    if let error {
                        Text(error).foregroundStyle(.red)
                    }
                    Spacer()
                    Text("\(newName.count)/25")
                        .foregroundStyle(newName.count == 25 ? .orange : .secondary)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Progress

    private func renamingContent(completed: Int, total: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView(value: Double(completed), total: Double(max(total, 1)))
                .progressViewStyle(.linear)
                .padding(.horizontal, 32)
            Text("Renaming \(completed + 1) of \(total)")
                .font(.headline)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel", role: .cancel) { onDismiss() }
                .disabled(viewModel.isRenaming)
        }
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.phase == .checking {
                ProgressView()
            } else {
                Button("Rename") {
                    Task { await performRename() }
                }
                .disabled(!isValid || viewModel.isRenaming)
                .accessibilityIdentifier("rename-folder-button")
            }
        }
    }

    // MARK: - Action

    private func performRename() async {
        error = nil
        do {
            try await viewModel.rename(to: trimmedName)
            onComplete()
            onDismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
