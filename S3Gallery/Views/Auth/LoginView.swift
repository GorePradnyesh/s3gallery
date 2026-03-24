import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case accessKeyId, secretAccessKey, region
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    header
                    credentialsForm
                    loginButton
                    if case .failure(let message) = viewModel.authState {
                        errorBanner(message: message)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
            }
            .navigationTitle("S3 Gallery")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            Text("Connect to your S3 bucket")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var credentialsForm: some View {
        VStack(spacing: 16) {
            LabeledTextField(
                label: "Access Key ID",
                placeholder: "AKIAIOSFODNN7EXAMPLE",
                text: $viewModel.accessKeyId,
                autocapitalization: .characters
            )
            .focused($focusedField, equals: .accessKeyId)
            .submitLabel(.next)
            .onSubmit { focusedField = .secretAccessKey }

            LabeledTextField(
                label: "Secret Access Key",
                placeholder: "wJalrXUtnFEMI/K7MDENG...",
                text: $viewModel.secretAccessKey,
                isSecure: true
            )
            .focused($focusedField, equals: .secretAccessKey)
            .submitLabel(.next)
            .onSubmit { focusedField = .region }

            LabeledTextField(
                label: "AWS Region",
                placeholder: "us-east-1",
                text: $viewModel.region,
                autocapitalization: .never
            )
            .focused($focusedField, equals: .region)
            .submitLabel(.go)
            .onSubmit {
                focusedField = nil
                Task { await viewModel.login() }
            }
        }
    }

    private var loginButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.login() }
        } label: {
            Group {
                if viewModel.authState == .loading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Connect")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.authState == .loading)
        .accessibilityLabel("Connect to S3")
    }

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Helper component

private struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled()
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
