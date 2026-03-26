import Testing
import Foundation
@testable import S3Gallery

@Suite("BrowserViewModel")
@MainActor
struct BrowserViewModelTests {

    /// Builds a BrowserViewModel backed by a MockS3Service pre-loaded with the given items.
    ///
    /// The mock always reports three buckets ("alpha", "beta", "gamma") so bucket-list tests
    /// have a predictable, sorted baseline without needing real AWS access.
    private func makeVM(items: [S3Item] = []) -> (BrowserViewModel, MockS3Service) {
        let mock = MockS3Service()
        mock.objectsResult = .success(items)
        mock.bucketsResult = .success(["alpha", "beta", "gamma"])
        return (BrowserViewModel(s3Service: mock), mock)
    }

    // MARK: - Bucket loading

    /// Verifies that `loadBuckets` populates the `buckets` array in alphabetical order.
    ///
    /// The bucket list is the top-level screen the user sees after login. It must reflect what
    /// `listBuckets` returns (sorted for consistent display) and transition `loadState` to
    /// `.loaded` so the UI stops showing a spinner.
    @Test("loadBuckets populates buckets sorted")
    func loadBuckets() async {
        let (vm, _) = makeVM()
        await vm.loadBuckets()

        #expect(vm.buckets == ["alpha", "beta", "gamma"])
        #expect(vm.loadState == .loaded)
    }

    /// Verifies that a network or AWS error during bucket listing is surfaced in `loadState`.
    ///
    /// If `listBuckets` throws (e.g. no network, expired credentials), the view model must
    /// transition to `.error` and include a human-readable message. The UI uses this to render
    /// an error banner with a Retry button instead of an empty list, which would be confusing.
    @Test("loadBuckets sets error state on failure")
    func loadBucketsError() async {
        let mock = MockS3Service()
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "network error" }
        }
        mock.bucketsResult = .failure(FakeError())
        let vm = BrowserViewModel(s3Service: mock)

        await vm.loadBuckets()

        if case .error(let msg) = vm.loadState {
            #expect(msg.contains("network error"))
        } else {
            Issue.record("Expected error state")
        }
    }

    // MARK: - Navigation

    /// Verifies that tapping a bucket initialises the navigation stack and triggers an object listing.
    ///
    /// `enterBucket` is called when the user taps a bucket name on the root screen. It must:
    /// - Push exactly one `BrowseState` onto the stack (the bucket root, prefix = "")
    /// - Trigger `listObjectsV2` so folder contents appear immediately
    /// - Surface those items through `sortedItems` so the grid/list view can render them
    @Test("enterBucket sets navigation stack and loads items")
    func enterBucket() async {
        let folder = S3Item.folder(name: "photos", prefix: "photos/")
        let (vm, _) = makeVM(items: [folder])

        await vm.enterBucket("my-bucket")

        #expect(vm.navigationStack.count == 1)
        #expect(vm.navigationStack[0].bucket == "my-bucket")
        #expect(vm.navigationStack[0].prefix == "")
        #expect(vm.sortedItems.count == 1)
    }

    /// Verifies that navigating into a subfolder appends a new state to the stack.
    ///
    /// Each folder tap must push a new `BrowseState` with the correct prefix so the breadcrumb
    /// bar can reconstruct the full path and the back-navigation can unwind one level at a time.
    /// After entering "my-bucket" then "photos/", the stack depth must be 2 and the top state
    /// must carry the "photos/" prefix.
    @Test("enterFolder appends to navigation stack")
    func enterFolder() async {
        let (vm, _) = makeVM()
        await vm.enterBucket("my-bucket")
        await vm.enterFolder(name: "photos", prefix: "photos/")

        #expect(vm.navigationStack.count == 2)
        #expect(vm.navigationStack[1].prefix == "photos/")
    }

    /// Verifies that tapping a breadcrumb segment pops the stack back to that level.
    ///
    /// The breadcrumb bar allows non-linear navigation — the user can jump two or more levels
    /// up in one tap. `navigate(to:)` must truncate the stack so only states up to and
    /// including the tapped breadcrumb remain. Navigating to the root (index 0) from depth 3
    /// must leave exactly one state on the stack with an empty prefix.
    @Test("navigate pops stack to target state")
    func navigateToBreadcrumb() async {
        let (vm, _) = makeVM()
        await vm.enterBucket("my-bucket")
        await vm.enterFolder(name: "a", prefix: "a/")
        await vm.enterFolder(name: "b", prefix: "a/b/")

        #expect(vm.navigationStack.count == 3)

        let rootState = vm.navigationStack[0]
        await vm.navigate(to: rootState)

        #expect(vm.navigationStack.count == 1)
        #expect(vm.currentState?.prefix == "")
    }

    /// Verifies that `popToRoot` returns the user to the bucket list screen.
    ///
    /// The back-to-buckets button in the toolbar calls `popToRoot`. After it resolves,
    /// `isAtRoot` must be true (so the UI shows the bucket list, not folder contents)
    /// and `items` must be empty (no stale folder contents visible during transition).
    @Test("popToRoot clears navigation stack and items")
    func popToRoot() async {
        let (vm, _) = makeVM()
        await vm.enterBucket("my-bucket")

        await vm.popToRoot()

        #expect(vm.isAtRoot)
        #expect(vm.items.isEmpty)
    }

    // MARK: - Sorting

    /// Verifies that folders always appear before files regardless of their names or order returned by S3.
    ///
    /// S3 `ListObjectsV2` returns objects in UTF-8 byte order, which can interleave folders and files
    /// (e.g. "aaa/" folder after "z.jpg" file). The browser must always group folders at the top so
    /// the user can navigate the hierarchy without hunting for directories buried in a file list.
    @Test("sortedItems puts folders before files")
    func sortFoldersFirst() async {
        let items: [S3Item] = [
            MockS3Service.makeFiles(["z.jpg"])[0],
            MockS3Service.makeFolders(["aaa"])[0],
            MockS3Service.makeFiles(["a.jpg"])[0],
        ]
        let (vm, mock) = makeVM(items: items)
        mock.objectsResult = .success(items)
        await vm.enterBucket("b")

        let sorted = vm.sortedItems
        #expect(sorted[0].isFolder)
    }

    /// Verifies that the `nameDescending` sort option reverses the alphabetical order of files.
    ///
    /// The sort picker in the toolbar lets users flip between A→Z and Z→A. With `.nameDescending`
    /// selected, `sortedItems` must return files in reverse lexicographic order so "c" comes before
    /// "b" which comes before "a". Folders are not checked here as they follow the same logic and
    /// are already covered by `sortFoldersFirst`.
    @Test("sortOption nameDescending reverses file order")
    func sortNameDescending() async {
        let items = MockS3Service.makeFiles(["a.jpg", "c.jpg", "b.jpg"])
        let (vm, _) = makeVM(items: items)
        await vm.enterBucket("b")
        vm.sortOption = .nameDescending

        let names = vm.sortedItems.map { $0.name }
        #expect(names == ["c.jpg", "b.jpg", "a.jpg"])
    }

    // MARK: - Write access

    @Test("checkWriteAccess is called once on enterBucket")
    func checkWriteAccessCalledOnEnterBucket() async {
        let (vm, mock) = makeVM()
        await vm.enterBucket("my-bucket")
        #expect(mock.checkWriteAccessCalls == ["my-bucket"])
    }

    @Test("checkWriteAccess result is cached; second enterBucket on same bucket does not re-check")
    func checkWriteAccessCached() async {
        let (vm, mock) = makeVM()
        await vm.enterBucket("my-bucket")
        await vm.popToRoot()
        await vm.enterBucket("my-bucket")
        #expect(mock.checkWriteAccessCalls.count == 1)
    }

    @Test("currentBucketHasWriteAccess is nil before entering a bucket")
    func currentBucketHasWriteAccessInitiallyNil() async {
        let (vm, _) = makeVM()
        #expect(vm.currentBucketHasWriteAccess == nil)
    }

    @Test("currentBucketHasWriteAccess returns cached value after entering bucket")
    func currentBucketHasWriteAccessAfterEnter() async {
        let (vm, mock) = makeVM()
        mock.checkWriteAccessResult = .success(true)
        await vm.enterBucket("my-bucket")
        #expect(vm.currentBucketHasWriteAccess == true)
    }

    @Test("resetSession clears write access cache and pops to root")
    func resetSessionClearsCache() async {
        let (vm, mock) = makeVM()
        await vm.enterBucket("my-bucket")
        #expect(mock.checkWriteAccessCalls.count == 1)

        await vm.resetSession()
        #expect(vm.isAtRoot)

        // Enter the same bucket again — cache should be gone, so a new check is made
        await vm.enterBucket("my-bucket")
        #expect(mock.checkWriteAccessCalls.count == 2)
    }
}

// MARK: - Grid column count clamping

@Suite("GridColumnCount")
struct GridColumnCountTests {

    @Test("scale 1.0 leaves count unchanged")
    func noChange() {
        #expect(clampedColumnCount(current: 5, scale: 1.0) == 5)
    }

    @Test("pinch in halves column count")
    func pinchInHalves() {
        #expect(clampedColumnCount(current: 10, scale: 2.0) == 5)
    }

    @Test("pinch out doubles column count")
    func pinchOutDoubles() {
        #expect(clampedColumnCount(current: 5, scale: 0.5) == 10)
    }

    @Test("extreme pinch in clamps to minimum 3")
    func pinchInClamps() {
        #expect(clampedColumnCount(current: 5, scale: 10.0) == 3)
    }

    @Test("extreme pinch out clamps to maximum 20")
    func pinchOutClamps() {
        #expect(clampedColumnCount(current: 5, scale: 0.1) == 20)
    }

    @Test("already at min 3, further pinch in stays at 3")
    func minBoundary() {
        #expect(clampedColumnCount(current: 3, scale: 2.0) == 3)
    }

    @Test("already at max 20, further pinch out stays at 20")
    func maxBoundary() {
        #expect(clampedColumnCount(current: 20, scale: 0.5) == 20)
    }
}
