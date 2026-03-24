import Testing
import Foundation
@testable import S3Gallery

@Suite("BrowserViewModel")
struct BrowserViewModelTests {

    private func makeVM(items: [S3Item] = []) -> (BrowserViewModel, MockS3Service) {
        let mock = MockS3Service()
        mock.objectsResult = .success(items)
        mock.bucketsResult = .success(["alpha", "beta", "gamma"])
        return (BrowserViewModel(s3Service: mock), mock)
    }

    // MARK: - Bucket loading

    @Test("loadBuckets populates buckets sorted")
    func loadBuckets() async {
        let (vm, _) = makeVM()
        await vm.loadBuckets()

        #expect(vm.buckets == ["alpha", "beta", "gamma"])
        #expect(vm.loadState == .loaded)
    }

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

    @Test("enterFolder appends to navigation stack")
    func enterFolder() async {
        let (vm, _) = makeVM()
        await vm.enterBucket("my-bucket")
        await vm.enterFolder(name: "photos", prefix: "photos/")

        #expect(vm.navigationStack.count == 2)
        #expect(vm.navigationStack[1].prefix == "photos/")
    }

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

    @Test("popToRoot clears navigation stack and items")
    func popToRoot() async {
        let (vm, _) = makeVM()
        await vm.enterBucket("my-bucket")

        await vm.popToRoot()

        #expect(vm.isAtRoot)
        #expect(vm.items.isEmpty)
    }

    // MARK: - Sorting

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

    @Test("sortOption nameDescending reverses file order")
    func sortNameDescending() async {
        let items = MockS3Service.makeFiles(["a.jpg", "c.jpg", "b.jpg"])
        let (vm, _) = makeVM(items: items)
        await vm.enterBucket("b")
        vm.sortOption = .nameDescending

        let names = vm.sortedItems.map { $0.name }
        #expect(names == ["c.jpg", "b.jpg", "a.jpg"])
    }
}
