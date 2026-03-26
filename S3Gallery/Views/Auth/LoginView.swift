import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case accessKeyId, secretAccessKey
    }

    private static let awsRegions = [
        "us-east-1", "us-east-2",
        "us-west-1", "us-west-2",
        "af-south-1",
        "ap-east-1", "ap-south-1", "ap-south-2",
        "ap-northeast-1", "ap-northeast-2", "ap-northeast-3",
        "ap-southeast-1", "ap-southeast-2", "ap-southeast-3", "ap-southeast-4",
        "ca-central-1", "ca-west-1",
        "eu-central-1", "eu-central-2",
        "eu-west-1", "eu-west-2", "eu-west-3",
        "eu-north-1", "eu-south-1", "eu-south-2",
        "il-central-1",
        "me-central-1", "me-south-1",
        "sa-east-1",
    ]

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
            .submitLabel(.go)
            .onSubmit {
                focusedField = nil
                Task { await viewModel.login() }
            }

            LabeledRegionPicker(selection: $viewModel.region, regions: Self.awsRegions)
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
        .accessibilityIdentifier("Connect")
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

// MARK: - Helper components

private struct LabeledRegionPicker: View {
    @Binding var selection: String
    let regions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AWS Region")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Menu {
                Picker("AWS Region", selection: $selection) {
                    ForEach(regions, id: \.self) { region in
                        Text(region).tag(region)
                    }
                }
            } label: {
                HStack {
                    Text(selection)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityIdentifier("AWS Region")
        }
    }
}

private struct LabeledTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .never
    /// Accessibility identifier used by XCUITest to locate this field.
    /// Defaults to the placeholder text so tests can reference fields by their hint.
    var identifier: String? = nil

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
            .accessibilityIdentifier(identifier ?? placeholder)
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
