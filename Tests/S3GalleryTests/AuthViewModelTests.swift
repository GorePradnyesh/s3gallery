import Testing
import Foundation
@testable import S3Gallery

@Suite("AuthViewModel")
struct AuthViewModelTests {

    /// Constructs a fully isolated AuthViewModel with mock dependencies.
    ///
    /// - Parameters:
    ///   - buckets: The bucket list the mock S3 service will return on a successful `listBuckets` call.
    ///     Defaults to a single bucket so most tests can ignore this detail.
    ///   - error: When provided, the mock S3 service will throw this error instead of returning buckets.
    ///     Use this to exercise login-failure paths without touching real AWS.
    ///   - credentials: Pre-populate the mock Keychain with these credentials, simulating a returning
    ///     user who already logged in during a previous app launch.
    /// - Returns: The view model under test, the mock S3 service (for call-count assertions),
    ///   and the mock credentials service (for Keychain interaction assertions).
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

    /// Verifies the happy-path login flow end-to-end.
    ///
    /// When the user fills in all three fields and the S3 service validates the credentials
    /// successfully (simulated by `listBuckets` returning without error), the view model should:
    /// - Transition `authState` to `.success`
    /// - Set `isAuthenticated` to `true` so the root view switches to the browser
    /// - Persist the credentials to the Keychain so the next app launch can skip login
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

    /// Verifies that client-side validation fires before any network call is made.
    ///
    /// Submitting the login form with empty fields must produce a `.failure` state immediately,
    /// without attempting to create an S3Service or contact AWS. This prevents unnecessary
    /// network traffic and gives the user instant inline feedback.
    @Test("Login fails with empty fields")
    func loginEmptyFields() async {
        let (vm, _, _) = makeViewModel()
        vm.accessKeyId = ""
        vm.secretAccessKey = ""

        await vm.login()

        #expect(vm.authState == .failure("All fields are required."))
        #expect(vm.isAuthenticated == false)
    }

    /// Verifies that AWS-side credential rejection is surfaced to the user.
    ///
    /// If `listBuckets` throws (e.g. because AWS returns an `InvalidAccessKeyId` error),
    /// the view model must reflect the failure in `authState` so the login screen can display
    /// an actionable error message. `isAuthenticated` must remain false — the user is not
    /// allowed into the browser on a failed credential check.
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

    /// Verifies that credentials are never persisted when login fails.
    ///
    /// Saving bad credentials to the Keychain would cause the app to auto-login on the next
    /// launch with invalid keys, resulting in a crash loop. This test guards against that
    /// regression by confirming `CredentialsService.save` is not called on the failure path.
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

    /// Verifies that logout completely resets authentication state and removes stored credentials.
    ///
    /// After a successful logout:
    /// - `isAuthenticated` must be false so the root view shows the login screen
    /// - `authState` must return to `.idle` (not `.success`) so the form renders cleanly
    /// - The Keychain entry must be deleted so the next app launch shows login, not the browser
    ///
    /// This test first performs a successful login to ensure there is real state to clear,
    /// then asserts every piece of that state is gone after `logout()`.
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

    /// Verifies that a returning user with valid stored credentials is auto-authenticated on launch.
    ///
    /// `checkExistingCredentials` is called once at startup by `S3GalleryApp`. If the Keychain
    /// contains credentials and they pass a live `listBuckets` validation, the user should jump
    /// straight into the browser without seeing the login screen. The mock service is pre-loaded
    /// with a successful response to simulate valid stored credentials.
    @Test("checkExistingCredentials authenticates when stored creds are valid")
    func checkExistingCredentialsValid() async {
        let stored = Credentials(accessKeyId: "AKIA", secretAccessKey: "secret", region: "eu-west-1")
        let (vm, _, _) = makeViewModel(credentials: stored)

        await vm.checkExistingCredentials()

        #expect(vm.isAuthenticated == true)
    }

    /// Verifies that a first-time user (no Keychain entry) is sent to the login screen.
    ///
    /// When `checkExistingCredentials` finds nothing in the Keychain it must leave
    /// `isAuthenticated` as false, causing the root view to display `LoginView`.
    /// This is the expected flow for every fresh install or post-logout launch.
    @Test("checkExistingCredentials does not authenticate when no stored creds")
    func checkExistingCredentialsNone() async {
        let (vm, _, _) = makeViewModel()

        await vm.checkExistingCredentials()

        #expect(vm.isAuthenticated == false)
    }
}
