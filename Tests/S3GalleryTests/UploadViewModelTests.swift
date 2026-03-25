import Testing
import Foundation
@testable import S3Gallery

@Suite("UploadViewModel")
struct UploadViewModelTests {

    private func makeVM(
        bucket: String = "test-bucket",
        prefix: String = "",
        mock: MockS3Service = MockS3Service()
    ) -> (UploadViewModel, MockS3Service) {
        (UploadViewModel(bucket: bucket, prefix: prefix, s3Service: mock), mock)
    }

    // MARK: - Initial state

    @Test("phase starts as idle")
    func initialPhaseIsIdle() {
        let (vm, _) = makeVM()
        if case .idle = vm.phase { } else {
            Issue.record("Expected .idle initial phase")
        }
    }

    // MARK: - Single-file backward compat: upload(data:filename:contentType:)

    @Test("upload(data:filename:contentType:) success sets phase to .complete with succeeded task")
    func uploadDataSuccess() async {
        let (vm, mock) = makeVM(bucket: "my-bucket", prefix: "photos/")
        mock.uploadObjectResult = .success(())

        let data = Data("hello".utf8)
        await vm.upload(data: data, filename: "test.jpg", contentType: "image/jpeg")

        guard case .complete(let tasks) = vm.phase,
              let task = tasks.first,
              case .success(let item) = task.state else {
            Issue.record("Expected .complete phase with a succeeded task")
            return
        }
        #expect(item.bucket == "my-bucket")
        #expect(item.key == "photos/test.jpg")
        #expect(item.size == Int64(data.count))
    }

    @Test("upload(data:filename:contentType:) failure sets phase to .complete with failed task")
    func uploadDataFailure() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "upload failed" }
        }
        let (vm, mock) = makeVM()
        mock.uploadObjectResult = .failure(FakeError())

        await vm.upload(data: Data("x".utf8), filename: "file.txt", contentType: "text/plain")

        guard case .complete(let tasks) = vm.phase,
              let task = tasks.first,
              case .failure = task.state else {
            Issue.record("Expected .complete phase with a failed task")
            return
        }
        _ = task
    }

    // MARK: - Key construction

    @Test("key is constructed as prefix + filename")
    func keyConstruction() async {
        let (vm, mock) = makeVM(bucket: "b", prefix: "folder/sub/")
        mock.uploadObjectResult = .success(())

        await vm.upload(data: Data("x".utf8), filename: "img.png", contentType: "image/png")

        guard case .complete(let tasks) = vm.phase,
              case .success(let item) = tasks.first?.state else {
            Issue.record("Expected success")
            return
        }
        #expect(item.key == "folder/sub/img.png")
    }

    @Test("key has no prefix when prefix is empty")
    func keyNoPrefix() async {
        let (vm, mock) = makeVM(bucket: "b", prefix: "")
        mock.uploadObjectResult = .success(())

        await vm.upload(data: Data("x".utf8), filename: "root.txt", contentType: "text/plain")

        guard case .complete(let tasks) = vm.phase,
              case .success(let item) = tasks.first?.state else {
            Issue.record("Expected success")
            return
        }
        #expect(item.key == "root.txt")
    }

    // MARK: - Service call arguments

    @Test("uploadObject is called with correct bucket, key, and contentType")
    func uploadObjectArguments() async {
        let (vm, mock) = makeVM(bucket: "my-bucket", prefix: "docs/")
        mock.uploadObjectResult = .success(())

        await vm.upload(data: Data("pdf".utf8), filename: "report.pdf", contentType: "application/pdf")

        #expect(mock.uploadObjectCalls.count == 1)
        #expect(mock.uploadObjectCalls[0].bucket == "my-bucket")
        #expect(mock.uploadObjectCalls[0].key == "docs/report.pdf")
        #expect(mock.uploadObjectCalls[0].contentType == "application/pdf")
    }

    // MARK: - Staging

    @Test("stageFiles transitions phase to .staging")
    func stagingTransition() {
        let (vm, _) = makeVM()
        let task = UploadTask(filename: "a.jpg", data: Data("x".utf8), contentType: "image/jpeg")
        vm.stageFiles([task])
        if case .staging(let tasks) = vm.phase {
            #expect(tasks.count == 1)
        } else {
            Issue.record("Expected .staging phase")
        }
    }

    @Test("stageFiles appends when already staging")
    func stagingAppends() {
        let (vm, _) = makeVM()
        vm.stageFiles([UploadTask(filename: "a.jpg", data: Data("x".utf8), contentType: "image/jpeg")])
        vm.stageFiles([UploadTask(filename: "b.png", data: Data("y".utf8), contentType: "image/png")])
        if case .staging(let tasks) = vm.phase {
            #expect(tasks.count == 2)
        } else {
            Issue.record("Expected .staging with 2 tasks")
        }
    }

    @Test("removeStaged removes a task by id")
    func stagingRemove() {
        let (vm, _) = makeVM()
        let t1 = UploadTask(filename: "a.jpg", data: Data("x".utf8), contentType: "image/jpeg")
        let t2 = UploadTask(filename: "b.png", data: Data("y".utf8), contentType: "image/png")
        vm.stageFiles([t1, t2])
        vm.removeStaged(id: t1.id)
        if case .staging(let tasks) = vm.phase {
            #expect(tasks.count == 1)
            #expect(tasks[0].id == t2.id)
        } else {
            Issue.record("Expected .staging with 1 task")
        }
    }

    @Test("removeStaged returns to idle when last task is removed")
    func stagingRemoveAll() {
        let (vm, _) = makeVM()
        let task = UploadTask(filename: "a.jpg", data: Data("x".utf8), contentType: "image/jpeg")
        vm.stageFiles([task])
        vm.removeStaged(id: task.id)
        if case .idle = vm.phase { } else {
            Issue.record("Expected .idle after removing all staged tasks")
        }
    }

    // MARK: - Multi-upload: all success

    @Test("startUpload with multiple files all succeed sets .complete with all successes")
    func multiUploadAllSuccess() async {
        let (vm, mock) = makeVM(bucket: "b", prefix: "")
        mock.uploadObjectResult = .success(())

        let tasks = [
            UploadTask(filename: "a.jpg", data: Data("a".utf8), contentType: "image/jpeg"),
            UploadTask(filename: "b.png", data: Data("b".utf8), contentType: "image/png"),
            UploadTask(filename: "c.pdf", data: Data("c".utf8), contentType: "application/pdf"),
        ]
        vm.stageFiles(tasks)
        await vm.startUpload()

        guard case .complete(let result) = vm.phase else {
            Issue.record("Expected .complete phase")
            return
        }
        #expect(result.count == 3)
        #expect(mock.uploadObjectCalls.count == 3)
        let successCount = result.filter { if case .success = $0.state { return true }; return false }.count
        #expect(successCount == 3)
    }

    // MARK: - Multi-upload: partial failure

    @Test("startUpload with partial failures sets correct task states")
    func multiUploadPartialFailure() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "fail" }
        }
        let (vm, mock) = makeVM(bucket: "b", prefix: "")
        mock.uploadObjectResults = [
            .success(()),
            .failure(FakeError()),
            .success(()),
        ]

        let tasks = [
            UploadTask(filename: "a.jpg", data: Data("a".utf8), contentType: "image/jpeg"),
            UploadTask(filename: "b.png", data: Data("b".utf8), contentType: "image/png"),
            UploadTask(filename: "c.pdf", data: Data("c".utf8), contentType: "application/pdf"),
        ]
        vm.stageFiles(tasks)
        await vm.startUpload()

        guard case .complete(let result) = vm.phase else {
            Issue.record("Expected .complete phase")
            return
        }
        #expect(result.count == 3)
        let successCount = result.filter { if case .success = $0.state { return true }; return false }.count
        let failCount = result.filter { if case .failure = $0.state { return true }; return false }.count
        #expect(successCount == 2)
        #expect(failCount == 1)
    }

    // MARK: - Multi-upload: all fail

    @Test("startUpload with all failures sets all tasks to .failure")
    func multiUploadAllFailure() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "fail" }
        }
        let (vm, mock) = makeVM()
        mock.uploadObjectResult = .failure(FakeError())

        let tasks = [
            UploadTask(filename: "a.jpg", data: Data("a".utf8), contentType: "image/jpeg"),
            UploadTask(filename: "b.png", data: Data("b".utf8), contentType: "image/png"),
        ]
        vm.stageFiles(tasks)
        await vm.startUpload()

        guard case .complete(let result) = vm.phase else {
            Issue.record("Expected .complete phase")
            return
        }
        let failCount = result.filter { if case .failure = $0.state { return true }; return false }.count
        #expect(failCount == 2)
    }
}

// MARK: - AdaptiveThrottle Tests

@Suite("AdaptiveThrottle")
struct AdaptiveThrottleTests {

    @Test("initial capacity is respected")
    func initialCapacity() async {
        let throttle = AdaptiveThrottle(initial: 2, min: 1, max: 4)
        let cap = await throttle.currentCapacity
        #expect(cap == 2)
    }

    @Test("capacity increases after 3 consecutive successes")
    func capacityIncreasesOnSuccesses() async {
        let throttle = AdaptiveThrottle(initial: 2, min: 1, max: 4)
        await throttle.reportSuccess()
        await throttle.reportSuccess()
        await throttle.reportSuccess()
        let cap = await throttle.currentCapacity
        #expect(cap == 3)
    }

    @Test("capacity decreases after 2 consecutive failures")
    func capacityDecreasesOnFailures() async {
        let throttle = AdaptiveThrottle(initial: 3, min: 1, max: 6)
        await throttle.reportFailure()
        await throttle.reportFailure()
        let cap = await throttle.currentCapacity
        #expect(cap == 2)
    }

    @Test("capacity does not exceed maximum")
    func capacityMaxCap() async {
        let throttle = AdaptiveThrottle(initial: 3, min: 1, max: 3)
        for _ in 0..<9 {
            await throttle.reportSuccess()
        }
        let cap = await throttle.currentCapacity
        #expect(cap == 3)
    }

    @Test("capacity does not go below minimum")
    func capacityMinCap() async {
        let throttle = AdaptiveThrottle(initial: 1, min: 1, max: 4)
        await throttle.reportFailure()
        await throttle.reportFailure()
        let cap = await throttle.currentCapacity
        #expect(cap == 1)
    }

    @Test("failure resets consecutive success counter")
    func failureResetsSuccessCounter() async {
        let throttle = AdaptiveThrottle(initial: 2, min: 1, max: 4)
        await throttle.reportSuccess()
        await throttle.reportSuccess()
        await throttle.reportFailure() // resets successes
        await throttle.reportSuccess()
        await throttle.reportSuccess()
        // Only 2 consecutive successes after reset — should NOT increase yet
        let cap = await throttle.currentCapacity
        #expect(cap == 2)
    }

    @Test("acquire and release manages slots correctly")
    func acquireRelease() async {
        let throttle = AdaptiveThrottle(initial: 2, min: 1, max: 4)
        await throttle.acquire()
        await throttle.acquire()
        // Now at capacity=2, current=2. Release one.
        await throttle.release()
        // Should be able to acquire again immediately.
        await throttle.acquire()
        // No hang means the test passes.
    }
}

// Helper to share mutable state across async contexts in tests
private actor ActorBox<T> {
    var value: T
    init(_ value: T) { self.value = value }
    func set(_ value: T) { self.value = value }
}
