import Foundation
import Observation

enum AuthState: Equatable {
    case idle
    case loading
    case success
    case failure(String)
}

@Observable
final class AuthViewModel {
    var accessKeyId: String = ""
    var secretAccessKey: String = ""
    var region: String = "us-east-1"
    var authState: AuthState = .idle
    var isAuthenticated: Bool = false

    private(set) var activeService: (any S3ServiceProtocol)?
    private(set) var credentials: Credentials?

    private let credentialsService: any CredentialsServiceProtocol
    private let serviceFactory: (Credentials) async throws -> any S3ServiceProtocol

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
        guard let creds = try? credentialsService.load() else { return }
        do {
            let service = try await serviceFactory(creds)
            _ = try await service.listBuckets()
            activeService = service
            credentials = creds
            isAuthenticated = true
        } catch {
            // Stored credentials are no longer valid — clear them
            try? credentialsService.delete()
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
