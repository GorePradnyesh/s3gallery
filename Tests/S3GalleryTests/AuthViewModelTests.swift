import Testing
import Foundation
@testable import S3Gallery

@Suite("AuthViewModel")
struct AuthViewModelTests {

    private func makeViewModel(
        buckets: [String] = ["my-bucket"],
        failWith error: Error? = nil,
        credentials: Credentials? = nil
    ) -> (AuthViewModel, MockS3Service, MockCredentialsService) {
        let mockService = MockS3Service()
        let mockCreds = MockCredentialsService()
        mockCreds.stored = credentials

        if let error {
            mockService.bucketsResult = .failure(error)
        } else {
            mockService.bucketsResult = .success(buckets)
        }

        let vm = AuthViewModel(
            credentialsService: mockCreds,
            serviceFactory: { _ in mockService }
        )
        return (vm, mockService, mockCreds)
    }

    // MARK: - Login

    @Test("Login transitions from idle -> loading -> success")
    func loginSuccess() async throws {
        let (vm, _, mockCreds) = makeViewModel()
        vm.accessKeyId = "AKIATEST"
        vm.secretAccessKey = "secretkey"
        vm.region = "us-east-1"

        await vm.login()

        #expect(vm.authState == .success)
        #expect(vm.isAuthenticated == true)
        #expect(mockCreds.saveCalled == true)
    }

    @Test("Login fails with empty fields")
    func loginEmptyFields() async {
        let (vm, _, _) = makeViewModel()
        vm.accessKeyId = ""
        vm.secretAccessKey = ""

        await vm.login()

        #expect(vm.authState == .failure("All fields are required."))
        #expect(vm.isAuthenticated == false)
    }

    @Test("Login fails when service returns error")
    func loginServiceError() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "InvalidAccessKeyId" }
        }
        let (vm, _, _) = makeViewModel(failWith: FakeError())
        vm.accessKeyId = "BADKEY"
        vm.secretAccessKey = "badsecret"
        vm.region = "us-east-1"

        await vm.login()

        if case .failure(let msg) = vm.authState {
            #expect(msg.contains("InvalidAccessKeyId"))
        } else {
            Issue.record("Expected failure state")
        }
        #expect(vm.isAuthenticated == false)
    }

    @Test("Login does not save credentials on failure")
    func loginDoesNotSaveOnFailure() async {
        struct FakeError: Error {}
        let (vm, _, mockCreds) = makeViewModel(failWith: FakeError())
        vm.accessKeyId = "AKIATEST"
        vm.secretAccessKey = "secret"
        vm.region = "us-east-1"

        await vm.login()

        #expect(mockCreds.saveCalled == false)
    }

    // MARK: - Logout

    @Test("Logout clears state and credentials")
    func logoutClearsState() async {
        let (vm, _, mockCreds) = makeViewModel()
        vm.accessKeyId = "AKIATEST"
        vm.secretAccessKey = "secret"
        vm.region = "us-east-1"
        await vm.login()
        #expect(vm.isAuthenticated)

        vm.logout()

        #expect(vm.isAuthenticated == false)
        #expect(vm.authState == .idle)
        #expect(mockCreds.deleteCalled == true)
    }

    // MARK: - Check existing credentials

    @Test("checkExistingCredentials authenticates when stored creds are valid")
    func checkExistingCredentialsValid() async {
        let stored = Credentials(accessKeyId: "AKIA", secretAccessKey: "secret", region: "eu-west-1")
        let (vm, _, _) = makeViewModel(credentials: stored)

        await vm.checkExistingCredentials()

        #expect(vm.isAuthenticated == true)
    }

    @Test("checkExistingCredentials does not authenticate when no stored creds")
    func checkExistingCredentialsNone() async {
        let (vm, _, _) = makeViewModel()

        await vm.checkExistingCredentials()

        #expect(vm.isAuthenticated == false)
    }
}
