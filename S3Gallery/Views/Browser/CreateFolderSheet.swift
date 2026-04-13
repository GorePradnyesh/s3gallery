import SwiftUI

struct CreateFolderSheet: View {
    let state: BrowseState
    let viewModel: BrowserViewModel
    let onDismiss: () -> Void

    @State private var folderName = ""
    @State private var error: String?
    @State private var isCreating = false

    private var trimmedName: String { folderName.trimmingCharacters(in: .whitespaces) }
    private var isValid: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Folder name", text: $folderName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: folderName) { _, new in
                            var sanitised = new.replacingOccurrences(of: "/", with: "")
                            if sanitised.count > 25 {
                                sanitised = String(sanitised.prefix(25))
                            }
                            if sanitised != new {
                                folderName = sanitised
                            }
                            error = nil
                        }
                } footer: {
                    HStack(alignment: .top) {
                        if let error {
                            Text(error)
                                .foregroundStyle(.red)
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
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            Task { await createFolder() }
                        }
                        .disabled(!isValid)
                        .accessibilityIdentifier("create-folder-button")
                    }
                }
            }
        }
    }

    private func createFolder() async {
        guard isValid else { return }
        isCreating = true
        defer { isCreating = false }
        do {
            try await viewModel.createFolder(named: trimmedName)
            onDismiss()
        } catch CreateFolderError.alreadyExists {
            error = "A folder with this name already exists."
        } catch {
            self.error = error.localizedDescription
        }
    }
}
