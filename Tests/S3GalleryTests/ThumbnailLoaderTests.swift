import Testing
import Foundation
@testable import S3Gallery

/// Tests for `ThumbnailLoader`, which enforces a per-process cap on simultaneous
/// S3 thumbnail downloads to prevent iOS from killing the app under memory pressure.
@Suite("ThumbnailLoader")
struct ThumbnailLoaderTests {

    // MARK: - Slot acquisition

    /// Verifies that tasks up to `maxConcurrent` acquire slots without suspending.
    ///
    /// Cells in the visible viewport should start downloading immediately. If they had
    /// to wait even when slots are free, the first grid paint would be delayed.
    @Test("acquires up to maxConcurrent slots without waiting")
    func acquiresUpToLimit() async throws {
        let loader = ThumbnailLoader(maxConcurrent: 3)
        try await loader.acquire()
        try await loader.acquire()
        try await loader.acquire()
        await loader.release()
        await loader.release()
        await loader.release()
    }

    /// Verifies that a task beyond `maxConcurrent` suspends until a slot is freed.
    ///
    /// Without the cap, a 20-cell grid would launch 20 concurrent downloads.
    /// Each large JPEG decompresses to tens of MB, exhausting RAM and triggering a kill.
    @Test("task beyond limit suspends until a slot is released")
    func suspendsWhenFull() async throws {
        let loader = ThumbnailLoader(maxConcurrent: 1)
        try await loader.acquire()

        var acquired = false
        let waiter = Task {
            try await loader.acquire()
            acquired = true
            await loader.release()
        }

        // Confirm still waiting while the single slot is occupied
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(!acquired)

        await loader.release() // hand off the slot
        try await waiter.value
        #expect(acquired)
    }

    // MARK: - Cancellation

    /// Verifies that cancelling a queued task removes it and doesn't consume a slot.
    ///
    /// When a cell scrolls off screen SwiftUI cancels its `.task`. A cancelled task left
    /// in the queue would steal a slot from a visible cell when eventually unblocked,
    /// wasting a download on an image the user can no longer see.
    @Test("cancelled waiter is removed; remaining waiters still get slots")
    func cancelledWaiterIsRemoved() async throws {
        let loader = ThumbnailLoader(maxConcurrent: 1)
        try await loader.acquire() // occupy the only slot

        // Enqueue two waiters; cancel the first.
        let first  = Task { try await loader.acquire() }
        let second = Task {
            try await loader.acquire()
            await loader.release()
        }

        try await Task.sleep(nanoseconds: 30_000_000) // let both enqueue
        first.cancel()
        try await Task.sleep(nanoseconds: 30_000_000) // let cancellation propagate

        await loader.release() // slot must flow to `second`, not `first`
        try await second.value // must complete without hanging

        // `first` must have thrown CancellationError, not silently acquired
        do {
            try await first.value
            Issue.record("expected first task to throw CancellationError")
        } catch is CancellationError {
            // expected
        }
    }

    // MARK: - No deadlock

    /// Verifies that a burst of tasks all complete when throttled to maxConcurrent=2.
    ///
    /// Regression guard: if `release()` has an off-by-one in the slot counter some tasks
    /// would hang forever. Five tasks with a cap of 2 must all finish in finite time.
    @Test("all tasks complete without deadlock (5 tasks, maxConcurrent=2)")
    func noDeadlock() async throws {
        let loader = ThumbnailLoader(maxConcurrent: 2)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await loader.acquire()
                    try await Task.sleep(nanoseconds: 1_000_000) // 1 ms simulated work
                    await loader.release()
                }
            }
            try await group.waitForAll()
        }
    }

    // MARK: - Slot count integrity

    /// Verifies that repeated acquire/release cycles leave the loader in a clean state.
    ///
    /// If `activeCount` drifts from the correct value across multiple cycles (e.g. a
    /// double-decrement bug), later acquisitions would either over-admit or permanently
    /// block. Ten sequential rounds with maxConcurrent=1 must all succeed immediately.
    @Test("repeated acquire/release cycles maintain correct slot count")
    func repeatedCycles() async throws {
        let loader = ThumbnailLoader(maxConcurrent: 1)

        for _ in 0..<10 {
            try await loader.acquire()
            await loader.release()
        }

        // Slot must still be available — this must not hang
        try await loader.acquire()
        await loader.release()
    }
}
