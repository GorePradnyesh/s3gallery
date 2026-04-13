import Foundation
import Observation

enum AuthState: Equatable {
    case idle
    case validating
    case loading
    case success
    case failure(String)
}

@Observable
final class AuthViewModel {
    var accessKeyId: String = ""
    var secretAccessKey: String = ""
    var region: String = "us-east-1"
    var authState: AuthState = .validating
    var isAuthenticated: Bool = false

    private(set) var activeService: (any S3ServiceProtocol)?
    private(set) var credentials: Credentials?

    private let credentialsService: any CredentialsServiceProtocol
    private var serviceFactory: (Credentials) async throws -> any S3ServiceProtocol

    init(
        credentialsService: any CredentialsServiceProtocol = CredentialsService(),
        serviceFactory: @escaping (Credentials) async throws -> any S3ServiceProtocol = { creds in
            try await S3Service(credentials: creds)
        }
    ) {
        self.credentialsService = credentialsService
        self.serviceFactory = serviceFactory
    }

    // MARK: - App launch

    func checkExistingCredentials() async {
        authState = .validating
        guard let creds = try? credentialsService.load() else {
            authState = .idle
            return
        }
        do {
            let service = try await serviceFactory(creds)
            _ = try await service.listBuckets()
            activeService = service
            credentials = creds
            isAuthenticated = true
            authState = .success
        } catch {
            // Stored credentials are no longer valid — clear them
            try? credentialsService.delete()
            authState = .idle
        }
    }

    // MARK: - Login

    func login() async {
        let trimmedKeyId = accessKeyId.trimmingCharacters(in: .whitespaces)
        let trimmedRegion = region.trimmingCharacters(in: .whitespaces)

        guard !trimmedKeyId.isEmpty, !secretAccessKey.isEmpty, !trimmedRegion.isEmpty else {
            authState = .failure("All fields are required.")
            return
        }

        authState = .loading

        let creds = Credentials(
            accessKeyId: trimmedKeyId,
            secretAccessKey: secretAccessKey,
            region: trimmedRegion
        )

        do {
            let service = try await serviceFactory(creds)
            _ = try await service.listBuckets()
            try credentialsService.save(creds)
            activeService = service
            credentials = creds
            authState = .success
            isAuthenticated = true
        } catch {
            authState = .failure(error.localizedDescription)
        }
    }

    // MARK: - UI test injection

#if DEBUG
    /// Replaces the service factory so subsequent login attempts use the provided mock.
    /// Called by `S3GalleryApp` when launched with `--mock-s3-success` or `--mock-s3-failure`.
    func overrideServiceFactory(_ factory: @escaping (Credentials) async throws -> any S3ServiceProtocol) {
        serviceFactory = factory
    }

    /// Bypasses the normal login flow for UI tests launched with `--skip-login`.
    /// Sets the view model into an authenticated state with mock credentials and service
    /// without touching the Keychain or making any network calls.
    func injectMockAuthentication(service: any S3ServiceProtocol) {
        activeService = service
        credentials = Credentials(accessKeyId: "AKIA-UITEST",
                                  secretAccessKey: "uitest-secret",
                                  region: "us-east-1")
        isAuthenticated = true
        authState = .idle
    }
#endif

    // MARK: - Logout

    func logout() {
        try? credentialsService.delete()
        Task { await CacheService.shared.clearAll() }
        activeService = nil
        credentials = nil
        isAuthenticated = false
        authState = .idle
        accessKeyId = ""
        secretAccessKey = ""
        region = "us-east-1"
    }
}
