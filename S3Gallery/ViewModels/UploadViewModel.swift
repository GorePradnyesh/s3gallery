import Foundation
import UniformTypeIdentifiers
import Observation

@Observable final class UploadViewModel {
    enum UploadPhase {
        case idle
        case staging([UploadTask])
        case uploading([UploadTask])
        case complete([UploadTask])
    }

    var phase: UploadPhase = .idle

    let bucket: String
    let prefix: String
    let s3Service: any S3ServiceProtocol

    init(bucket: String, prefix: String, s3Service: any S3ServiceProtocol) {
        self.bucket = bucket
        self.prefix = prefix
        self.s3Service = s3Service
    }

    // MARK: - Staging

    func stageFiles(_ tasks: [UploadTask]) {
        guard !tasks.isEmpty else { return }
        if case .staging(let existing) = phase {
            phase = .staging(existing + tasks)
        } else {
            phase = .staging(tasks)
        }
    }

    func removeStaged(id: UUID) {
        guard case .staging(var tasks) = phase else { return }
        tasks.removeAll { $0.id == id }
        phase = tasks.isEmpty ? .idle : .staging(tasks)
    }

    // MARK: - Upload

    func startUpload() async {
        guard case .staging(let tasks) = phase, !tasks.isEmpty else { return }
        phase = .uploading(tasks)

        let service = s3Service
        let bucket = self.bucket
        let prefix = self.prefix
        let throttle = AdaptiveThrottle(initial: 3, min: 1, max: 6)

        await withTaskGroup(of: Void.self) { group in
            for task in tasks {
                await throttle.acquire()
                let taskID = task.id
                let filename = task.filename
                let data = task.data
                let contentType = task.contentType

                group.addTask {
                    defer { Task { await throttle.release() } }
                    let uploadKey = prefix + filename
                    do {
                        try await service.uploadObject(
                            bucket: bucket,
                            key: uploadKey,
                            data: data,
                            contentType: contentType
                        )
                        let item = S3FileItem(
                            key: uploadKey,
                            bucket: bucket,
                            size: Int64(data.count),
                            lastModified: Date(),
                            eTag: nil
                        )
                        await throttle.reportSuccess()
                        await MainActor.run { [weak self] in
                            self?.updateTask(id: taskID, state: .success(item))
                        }
                    } catch {
                        await throttle.reportFailure()
                        await MainActor.run { [weak self] in
                            self?.updateTask(id: taskID, state: .failure(error))
                        }
                    }
                }
            }
        }

        if case .uploading(let finalTasks) = phase {
            phase = .complete(finalTasks)
        }
    }

    // MARK: - Backward compatibility (single-file)

    func upload(data: Data, filename: String, contentType: String) async {
        let task = UploadTask(filename: filename, data: data, contentType: contentType)
        phase = .staging([task])
        await startUpload()
    }

    func upload(url: URL) async {
        let filename = url.lastPathComponent
        let contentType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

        guard url.startAccessingSecurityScopedResource() else {
            var failedTask = UploadTask(filename: filename, data: Data(), contentType: contentType)
            failedTask.state = .failure(UploadError.fileAccessDenied)
            phase = .complete([failedTask])
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            await upload(data: data, filename: filename, contentType: contentType)
        } catch {
            var failedTask = UploadTask(filename: filename, data: Data(), contentType: contentType)
            failedTask.state = .failure(error)
            phase = .complete([failedTask])
        }
    }

    // MARK: - Private

    private func updateTask(id: UUID, state: UploadTaskState) {
        guard case .uploading(var tasks) = phase else { return }
        if let idx = tasks.firstIndex(where: { $0.id == id }) {
            tasks[idx].state = state
            phase = .uploading(tasks)
        }
    }
}

// MARK: - Adaptive Throttle

actor AdaptiveThrottle {
    private var current = 0
    private var capacity: Int
    private let minimum: Int
    private let maximum: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var consecutiveSuccesses = 0
    private var consecutiveFailures = 0

    init(initial: Int, min minimum: Int, max maximum: Int) {
        self.capacity = initial
        self.minimum = minimum
        self.maximum = maximum
    }

    func acquire() async {
        if current < capacity {
            current += 1
            return
        }
        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }

    func release() {
        if let first = waiters.first {
            waiters.removeFirst()
            first.resume()
        } else {
            current = max(0, current - 1)
        }
    }

    func reportSuccess() {
        consecutiveSuccesses += 1
        consecutiveFailures = 0
        if consecutiveSuccesses >= 3, capacity < maximum {
            capacity += 1
            consecutiveSuccesses = 0
            wakeOneWaiter()
        }
    }

    func reportFailure() {
        consecutiveFailures += 1
        consecutiveSuccesses = 0
        if consecutiveFailures >= 2, capacity > minimum {
            capacity -= 1
            consecutiveFailures = 0
        }
    }

    var currentCapacity: Int { capacity }

    private func wakeOneWaiter() {
        guard !waiters.isEmpty else { return }
        let first = waiters.removeFirst()
        current += 1
        first.resume()
    }
}

// MARK: - Errors

enum UploadError: Error, LocalizedError {
    case fileAccessDenied

    var errorDescription: String? {
        switch self {
        case .fileAccessDenied:
            return "Could not access the selected file."
        }
    }
}
