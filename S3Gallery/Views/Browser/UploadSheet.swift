import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct UploadSheet: View {
    @Bindable var viewModel: UploadViewModel
    let onSuccess: () async -> Void
    let onDismiss: () -> Void

    @State private var showPhotosPicker = false
    @State private var showFilePicker = false
    @State private var showSourceChooser = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var viewUploadedItem: S3FileItem?

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle:
                    idleView
                case .uploading:
                    uploadingView
                case .success(let item):
                    successView(item: item)
                case .failure(let error):
                    failureView(error: error)
                }
            }
            .navigationTitle("Upload")
            .navigationBarTitleDisplayMode(.inline)
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhoto, matching: .any(of: [.images, .videos]))
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let url):
                Task { await viewModel.upload(url: url) }
            case .failure(let error):
                viewModel.state = .failure(error)
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    let filename = newItem.itemIdentifier.map { "\($0).jpg" } ?? "photo.jpg"
                    let contentType = newItem.supportedContentTypes.first?.preferredMIMEType ?? "image/jpeg"
                    await viewModel.upload(data: data, filename: filename, contentType: contentType)
                }
            }
        }
        .sheet(item: $viewUploadedItem) { item in
            ViewerContainer(item: item, s3Service: viewModel.s3Service)
        }
#if DEBUG
        .task {
            if UITestArgs.autoUpload {
                await viewModel.upload(
                    data: Data("ui-test-upload".utf8),
                    filename: "ui-test-file.txt",
                    contentType: "text/plain"
                )
            }
        }
#endif
    }

    // MARK: - State views

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

    private var uploadingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Uploading…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func successView(item: S3FileItem) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text(item.name)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Upload complete")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("View") {
                    viewUploadedItem = item
                }
                .buttonStyle(.borderedProminent)

                Button("Done") {
                    Task { await onSuccess() }
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func failureView(error: Error) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Upload Failed")
                .font(.headline)

            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            ScrollView {
                Text((error as CustomDebugStringConvertible).debugDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .frame(maxHeight: 120)
            .padding(.horizontal)

            Button("Dismiss") { onDismiss() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
