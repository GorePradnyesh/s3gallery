import Foundation

/// Limits concurrent thumbnail downloads to prevent memory spikes that kill the app.
///
/// At most `maxConcurrent` downloads run simultaneously; extra callers suspend until
/// a slot is free. Tasks cancelled while waiting are removed from the queue cleanly.
actor ThumbnailLoader {
    static let shared = ThumbnailLoader(maxConcurrent: 3)

    private let maxConcurrent: Int
    private var activeCount = 0
    private var waiters: [(id: UUID, continuation: CheckedContinuation<Void, Error>)] = []

    init(maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
    }

    /// Acquires a download slot. Suspends if all slots are occupied.
    /// Throws `CancellationError` if the calling task is cancelled while waiting.
    func acquire() async throws {
        try Task.checkCancellation()
        guard activeCount >= maxConcurrent else {
            activeCount += 1
            return
        }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append((id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.removeWaiter(id: id) }
        }
        // Reaching here means release() transferred the slot; increment our count.
        activeCount += 1
    }

    /// Releases a slot acquired via `acquire()`. Must be called exactly once per
    /// successful `acquire()`.
    func release() {
        activeCount -= 1
        if !waiters.isEmpty {
            let (_, continuation) = waiters.removeFirst()
            continuation.resume()
        }
    }

    private func removeWaiter(id: UUID) {
        if let index = waiters.firstIndex(where: { $0.id == id }) {
            let (_, continuation) = waiters.remove(at: index)
            continuation.resume(throwing: CancellationError())
        }
    }
}
