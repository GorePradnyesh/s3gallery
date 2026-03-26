import Testing
import Foundation
@testable import S3Gallery

@Suite("BrowserViewModel – Selection")
@MainActor
struct BrowserViewModelSelectionTests {

    private func makeVM() -> BrowserViewModel {
        BrowserViewModel(s3Service: MockS3Service())
    }

    private func makeFile(key: String = "photo.jpg") -> S3FileItem {
        S3FileItem(key: key, bucket: "test-bucket", size: 1024, lastModified: Date(), eTag: nil)
    }

    // MARK: - Initial State

    @Test("isSelectionMode is false by default")
    func defaultNotInSelectionMode() {
        let vm = makeVM()
        #expect(!vm.isSelectionMode)
    }

    @Test("selectedItems is empty by default")
    func defaultNoSelectedItems() {
        let vm = makeVM()
        #expect(vm.selectedItems.isEmpty)
    }

    // MARK: - Enter / Exit

    @Test("enterSelectionMode sets isSelectionMode to true")
    func enterSelectionMode() {
        let vm = makeVM()
        vm.enterSelectionMode()
        #expect(vm.isSelectionMode)
    }

    @Test("enterSelectionMode clears any prior selection")
    func enterSelectionModeClearsItems() {
        let vm = makeVM()
        vm.enterSelectionMode()
        vm.toggleSelection(makeFile())
        vm.exitSelectionMode()
        vm.enterSelectionMode()
        #expect(vm.selectedItems.isEmpty)
    }

    @Test("exitSelectionMode clears flag and items")
    func exitSelectionMode() {
        let vm = makeVM()
        vm.enterSelectionMode()
        vm.toggleSelection(makeFile())
        vm.exitSelectionMode()
        #expect(!vm.isSelectionMode)
        #expect(vm.selectedItems.isEmpty)
    }

    // MARK: - Toggle

    @Test("toggleSelection adds item when not selected")
    func toggleSelectionAdds() {
        let vm = makeVM()
        let item = makeFile()
        vm.enterSelectionMode()
        vm.toggleSelection(item)
        #expect(vm.selectedItems.count == 1)
        #expect(vm.selectedItems.contains(item))
    }

    @Test("toggleSelection removes item when already selected")
    func toggleSelectionRemoves() {
        let vm = makeVM()
        let item = makeFile()
        vm.enterSelectionMode()
        vm.toggleSelection(item)
        vm.toggleSelection(item)
        #expect(vm.selectedItems.isEmpty)
    }

    @Test("multiple items can be selected simultaneously")
    func multipleSelection() {
        let vm = makeVM()
        let a = makeFile(key: "a.jpg")
        let b = makeFile(key: "b.mp4")
        let c = makeFile(key: "c.pdf")
        vm.enterSelectionMode()
        vm.toggleSelection(a)
        vm.toggleSelection(b)
        vm.toggleSelection(c)
        #expect(vm.selectedItems.count == 3)
    }

    // MARK: - canSaveSelectedToPhotos

    @Test("canSaveSelectedToPhotos is false when nothing selected")
    func canSaveToPhotosEmpty() {
        let vm = makeVM()
        vm.enterSelectionMode()
        #expect(!vm.canSaveSelectedToPhotos)
    }

    @Test("canSaveSelectedToPhotos is true when only images are selected")
    func canSaveToPhotosImages() {
        let vm = makeVM()
        vm.enterSelectionMode()
        vm.toggleSelection(makeFile(key: "photo.jpg"))
        vm.toggleSelection(makeFile(key: "photo2.png"))
        #expect(vm.canSaveSelectedToPhotos)
    }

    @Test("canSaveSelectedToPhotos is false when a non-media file is selected")
    func canSaveToPhotosMixed() {
        let vm = makeVM()
        vm.enterSelectionMode()
        vm.toggleSelection(makeFile(key: "photo.jpg"))
        vm.toggleSelection(makeFile(key: "document.pdf"))
        #expect(!vm.canSaveSelectedToPhotos)
    }

    @Test("canSaveSelectedToPhotos is true for videos")
    func canSaveToPhotosVideos() {
        let vm = makeVM()
        vm.enterSelectionMode()
        vm.toggleSelection(makeFile(key: "clip.mp4"))
        #expect(vm.canSaveSelectedToPhotos)
    }

    // MARK: - Navigation resets selection

    @Test("enterFolder exits selection mode")
    func enterFolderResetsSelection() async {
        let mock = MockS3Service()
        mock.objectsResult = .success([])
        let vm = BrowserViewModel(s3Service: mock)
        vm.enterSelectionMode()
        vm.toggleSelection(makeFile())

        // Simulate being inside a bucket first
        mock.objectsResult = .success([])
        await vm.enterBucket("test-bucket")
        vm.enterSelectionMode()
        vm.toggleSelection(makeFile())
        await vm.enterFolder(name: "photos", prefix: "photos/")

        #expect(!vm.isSelectionMode)
        #expect(vm.selectedItems.isEmpty)
    }
}
