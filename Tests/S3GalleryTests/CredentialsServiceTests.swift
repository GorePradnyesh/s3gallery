import Testing
import Foundation
@testable import S3Gallery

@Suite("CredentialsService (mock)")
struct CredentialsServiceTests {

    @Test("save stores credentials")
    func saveStores() throws {
        let service = MockCredentialsService()
        let creds = Credentials(accessKeyId: "AKIA", secretAccessKey: "secret", region: "us-east-1")

        try service.save(creds)

        #expect(service.stored == creds)
        #expect(service.saveCalled)
    }

    @Test("load returns nil when nothing stored")
    func loadNil() throws {
        let service = MockCredentialsService()
        let result = try service.load()
        #expect(result == nil)
    }

    @Test("load returns stored credentials")
    func loadReturnsStored() throws {
        let service = MockCredentialsService()
        let creds = Credentials(accessKeyId: "AKIA", secretAccessKey: "secret", region: "eu-west-1")
        try service.save(creds)

        let loaded = try service.load()
        #expect(loaded == creds)
    }

    @Test("delete removes credentials")
    func deleteRemoves() throws {
        let service = MockCredentialsService()
        let creds = Credentials(accessKeyId: "AKIA", secretAccessKey: "secret", region: "us-east-1")
        try service.save(creds)

        try service.delete()

        #expect(service.stored == nil)
        #expect(service.deleteCalled)
    }

    @Test("load propagates thrown error")
    func loadPropagatesError() {
        struct FakeError: Error {}
        let service = MockCredentialsService()
        service.loadError = FakeError()

        #expect(throws: FakeError.self) {
            try service.load()
        }
    }

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
