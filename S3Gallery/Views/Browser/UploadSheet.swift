import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import QuickLook

struct UploadSheet: View {
    @Bindable var viewModel: UploadViewModel
    let onSuccess: () async -> Void
    let onDismiss: () -> Void

    @State private var showPhotosPicker = false
    @State private var showFilePicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var previewURL: URL?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.phase {
                case .idle:
                    idleView
                case .staging(let tasks):
                    stagingView(tasks: tasks)
                case .uploading(let tasks):
                    progressView(tasks: tasks)
                case .complete(let tasks):
                    completionView(tasks: tasks)
                }
            }
            .navigationTitle("Upload")
            .navigationBarTitleDisplayMode(.inline)
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $selectedPhotos,
            maxSelectionCount: 20,
            matching: .any(of: [.images, .videos])
        )
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await stageFileURLs(urls) }
            case .failure:
                break
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await stagePhotoItems(newItems) }
        }
        .quickLookPreview($previewURL)
#if DEBUG
        .task {
            if UITestArgs.autoStage {
                let tasks = [
                    UploadTask(filename: "photo1.jpg", data: Data("img1".utf8), contentType: "image/jpeg"),
                    UploadTask(filename: "document.pdf", data: Data("pdf1".utf8), contentType: "application/pdf"),
                ]
                viewModel.stageFiles(tasks)
            } else if UITestArgs.autoUpload {
                await viewModel.upload(
                    data: Data("ui-test-upload".utf8),
                    filename: "ui-test-file.txt",
                    contentType: "text/plain"
                )
            }
        }
#endif
    }

    // MARK: - Idle view

    private var idleView: some View {
        VStack(spacing: 32) {
            Image(systemName: "arrow.up.to.line.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Choose a source")
                .font(.headline)

            VStack(spacing: 12) {
                Button {
                    showPhotosPicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    showFilePicker = true
                } label: {
                    Label("Files", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)

            Button("Cancel", role: .cancel) { onDismiss() }
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Staging view

    private func stagingView(tasks: [UploadTask]) -> some View {
        VStack(spacing: 0) {
            List {
                Section("Selected (\(tasks.count))") {
                    ForEach(tasks) { task in
                        HStack {
                            Image(systemName: fileIcon(for: task.filename))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.filename)
                                    .lineLimit(1)
                                Text(ByteCountFormatter.string(fromByteCount: Int64(task.data.count), countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                viewModel.removeStaged(id: task.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(task.filename)")
                        }
                    }
                }

                Section {
                    Button {
                        showPhotosPicker = true
                    } label: {
                        Label("Add from Photo Library", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Add from Files", systemImage: "folder")
                    }
                }
            }

            VStack(spacing: 12) {
                Button {
                    Task { await viewModel.startUpload() }
                } label: {
                    Text("Upload \(tasks.count) \(tasks.count == 1 ? "File" : "Files")")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .accessibilityIdentifier("upload-confirm-button")

                Button("Cancel", role: .cancel) { onDismiss() }
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
    }

    // MARK: - Progress view

    private func progressView(tasks: [UploadTask]) -> some View {
        let done = tasks.filter {
            switch $0.state {
            case .success, .failure: return true
            default: return false
            }
        }.count

        return VStack(spacing: 0) {
            List {
                Section {
                    ForEach(tasks) { task in
                        HStack(spacing: 12) {
                            taskStateIcon(task.state)
                                .frame(width: 20)
                            Text(task.filename)
                                .lineLimit(1)
                        }
                    }
                }
            }

            VStack(spacing: 8) {
                ProgressView(value: Double(done), total: Double(tasks.count))
                    .padding(.horizontal)
                Text("\(done) of \(tasks.count) uploaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
    }

    // MARK: - Completion view

    private func completionView(tasks: [UploadTask]) -> some View {
        let succeeded = tasks.filter { if case .success = $0.state { return true }; return false }
        let failed = tasks.filter { if case .failure = $0.state { return true }; return false }
        let allSucceeded = failed.isEmpty

        return VStack(spacing: 0) {
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: allSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(allSucceeded ? .green : .orange)

                            Text(summaryText(succeeded: succeeded.count, total: tasks.count, allSucceeded: allSucceeded))
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 8)
                }

                if !failed.isEmpty {
                    Section("Failed (\(failed.count))") {
                        ForEach(failed) { task in
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.filename)
                                        .lineLimit(1)
                                    if case .failure(let error) = task.state {
                                        Text(error.localizedDescription)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                Button("Preview") {
                                    previewURL = makeTempFile(for: task)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }

            Button {
                if !succeeded.isEmpty {
                    Task { await onSuccess() }
                }
                onDismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .background(.regularMaterial)
        }
    }

    // MARK: - Helpers

    private func stageFileURLs(_ urls: [URL]) async {
        var tasks: [UploadTask] = []
        for url in urls {
            let filename = url.lastPathComponent
            let contentType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }
            tasks.append(UploadTask(filename: filename, data: data, contentType: contentType))
        }
        viewModel.stageFiles(tasks)
    }

    private func stagePhotoItems(_ items: [PhotosPickerItem]) async {
        var tasks: [UploadTask] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "jpg"
            let filename = "\(item.itemIdentifier ?? UUID().uuidString).\(ext)"
            let contentType = item.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
            tasks.append(UploadTask(filename: filename, data: data, contentType: contentType))
        }
        viewModel.stageFiles(tasks)
        selectedPhotos = []
    }

    private func makeTempFile(for task: UploadTask) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(task.filename)
        try? task.data.write(to: url)
        return url
    }

    private func summaryText(succeeded: Int, total: Int, allSucceeded: Bool) -> String {
        if allSucceeded {
            return succeeded == 1 ? "1 file uploaded" : "All \(succeeded) files uploaded"
        }
        return "\(succeeded) of \(total) uploaded"
    }

    @ViewBuilder
    private func taskStateIcon(_ state: UploadTaskState) -> some View {
        switch state {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .uploading:
            ProgressView()
                .scaleEffect(0.7)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func fileIcon(for filename: String) -> String {
        switch (filename as NSString).pathExtension.lowercased() {
        case "jpg", "jpeg", "png", "heic", "gif", "webp": return "photo"
        case "mp4", "mov", "avi", "mkv": return "video"
        case "pdf": return "doc.richtext"
        case "mp3", "aac", "wav", "flac": return "music.note"
        default: return "doc"
        }
    }
}
