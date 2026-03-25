import Testing
import Foundation
@testable import S3Gallery

/// Tests for the `CredentialsServiceProtocol` contract using `MockCredentialsService`.
///
/// These tests validate the expected behaviour of any conforming implementation without
/// touching the real iOS Keychain. Real-Keychain behaviour is covered separately by the
/// integration smoke test (manual, run on device). Using a mock here keeps the unit tests
/// fast, deterministic, and free of entitlement requirements.
@Suite("CredentialsService (mock)")
struct CredentialsServiceTests {

    /// Verifies that `save` persists the credentials and records that it was called.
    ///
    /// After a successful login, `AuthViewModel` calls `save` to write credentials to the
    /// Keychain so the next app launch can skip the login screen. This test confirms the
    /// service's stored value matches the exact credentials passed in — no mutation, no
    /// partial write — and that `saveCalled` is set so call-count assertions in other tests
    /// (like `loginDoesNotSaveOnFailure`) have a reliable baseline to compare against.
    @Test("save stores credentials")
    func saveStores() throws {
        let service = MockCredentialsService()
        let creds = Credentials(accessKeyId: "AKIA", secretAccessKey: "secret", region: "us-east-1")

        try service.save(creds)

        #expect(service.stored == creds)
        #expect(service.saveCalled)
    }

    /// Verifies that `load` returns nil when no credentials have been stored.
    ///
    /// This is the state on a fresh install or immediately after `delete`. `AuthViewModel`
    /// calls `load` during `checkExistingCredentials` at app launch; receiving nil is the
    /// signal to show `LoginView` rather than auto-authenticating. A non-nil return here
    /// would incorrectly skip the login screen for a brand-new user.
    @Test("load returns nil when nothing stored")
    func loadNil() throws {
        let service = MockCredentialsService()
        let result = try service.load()
        #expect(result == nil)
    }

    /// Verifies that `load` returns the exact credentials that were previously saved.
    ///
    /// This round-trip test (save → load) confirms that no data is lost or corrupted during
    /// the serialisation cycle. The real `CredentialsService` uses `JSONEncoder`/`JSONDecoder`
    /// plus Keychain storage; the mock simulates the net effect with an in-memory store.
    /// Both the `accessKeyId` and the `region` must survive the round-trip unchanged.
    @Test("load returns stored credentials")
    func loadReturnsStored() throws {
        let service = MockCredentialsService()
        let creds = Credentials(accessKeyId: "AKIA", secretAccessKey: "secret", region: "eu-west-1")
        try service.save(creds)

        let loaded = try service.load()
        #expect(loaded == creds)
    }

    /// Verifies that `delete` removes stored credentials and records that it was called.
    ///
    /// `AuthViewModel.logout` calls `delete` to remove the Keychain entry so the next launch
    /// shows the login screen. After deletion:
    /// - `stored` must be nil so a subsequent `load` returns nil (tested transitively by `loadNil`)
    /// - `deleteCalled` must be true so `logoutClearsState` can assert the service was exercised
    @Test("delete removes credentials")
    func deleteRemoves() throws {
        let service = MockCredentialsService()
        let creds = Credentials(accessKeyId: "AKIA", secretAccessKey: "secret", region: "us-east-1")
        try service.save(creds)

        try service.delete()

        #expect(service.stored == nil)
        #expect(service.deleteCalled)
    }

    /// Verifies that errors thrown by `load` propagate to the caller.
    ///
    /// The real Keychain can fail with system errors (e.g. the device is locked, or the
    /// entitlement is missing in a test build). `AuthViewModel` must not swallow these errors
    /// silently — they should propagate so the app can handle them gracefully (e.g. show the
    /// login screen rather than crashing). The mock's `loadError` property simulates this.
    @Test("load propagates thrown error")
    func loadPropagatesError() {
        struct FakeError: Error {}
        let service = MockCredentialsService()
        service.loadError = FakeError()

        #expect(throws: FakeError.self) {
            try service.load()
        }
    }

    /// Verifies that errors thrown by `save` propagate to the caller.
    ///
    /// Keychain writes can fail if the device runs out of storage or if the app lacks the
    /// Keychain entitlement. If `save` throws after a successful login, `AuthViewModel` must
    /// surface the error rather than silently completing — otherwise the user would appear
    /// logged in but lose their session on the next launch.
    @Test("save propagates thrown error")
    func savePropagatesError() {
        struct FakeError: Error {}
        let service = MockCredentialsService()
        service.saveError = FakeError()
        let creds = Credentials(accessKeyId: "A", secretAccessKey: "B", region: "C")

        #expect(throws: FakeError.self) {
            try service.save(creds)
        }
    }
}
