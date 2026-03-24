import Foundation
import Observation

enum SortOption: String, CaseIterable, Identifiable {
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case dateNewest = "Date (Newest)"
    case dateOldest = "Date (Oldest)"

    var id: String { rawValue }
}

enum BrowserLoadState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

@Observable
final class BrowserViewModel {
    var navigationStack: [BrowseState] = []
    var items: [S3Item] = []
    var loadState: BrowserLoadState = .idle
    var sortOption: SortOption = .nameAscending
    var buckets: [String] = []

    let s3Service: any S3ServiceProtocol

    init(s3Service: any S3ServiceProtocol) {
        self.s3Service = s3Service
    }

    // MARK: - Navigation

    var currentState: BrowseState? { navigationStack.last }
    var isAtRoot: Bool { navigationStack.isEmpty }

    func loadBuckets() async {
        loadState = .loading
        do {
            let result = try await s3Service.listBuckets()
            buckets = result.sorted()
            loadState = .loaded
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }

    func enterBucket(_ bucket: String) async {
        let state = BrowseState(bucket: bucket, prefix: "")
        navigationStack = [state]
        await loadCurrentFolder()
    }

    func enterFolder(name: String, prefix: String) async {
        guard let current = currentState else { return }
        let state = BrowseState(bucket: current.bucket, prefix: prefix)
        navigationStack.append(state)
        await loadCurrentFolder()
    }

    func navigate(to state: BrowseState) async {
        guard let index = navigationStack.firstIndex(of: state) else { return }
        navigationStack = Array(navigationStack.prefix(through: index))
        await loadCurrentFolder()
    }

    func popToRoot() async {
        navigationStack = []
        items = []
        loadState = .idle
    }

    func refresh() async {
        await loadCurrentFolder()
    }

    // MARK: - Sorted items

    var sortedItems: [S3Item] {
        let folders = items.filter { $0.isFolder }
        let files = items.filter { !$0.isFolder }

        let sortedFolders = folders.sorted { a, b in
            switch sortOption {
            case .nameAscending, .nameDescending:
                let result = a.name.localizedCaseInsensitiveCompare(b.name)
                return sortOption == .nameAscending ? result == .orderedAscending : result == .orderedDescending
            case .dateNewest, .dateOldest:
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }

        let sortedFiles = files.sorted { a, b in
            guard case .file(let af) = a, case .file(let bf) = b else { return false }
            switch sortOption {
            case .nameAscending:
                return af.name.localizedCaseInsensitiveCompare(bf.name) == .orderedAscending
            case .nameDescending:
                return af.name.localizedCaseInsensitiveCompare(bf.name) == .orderedDescending
            case .dateNewest:
                return af.lastModified > bf.lastModified
            case .dateOldest:
                return af.lastModified < bf.lastModified
            }
        }

        return sortedFolders + sortedFiles
    }

    // MARK: - Private

    private func loadCurrentFolder() async {
        guard let state = currentState else { return }
        loadState = .loading
        do {
            items = try await s3Service.listObjects(bucket: state.bucket, prefix: state.prefix)
            loadState = .loaded
        } catch {
            loadState = .error(error.localizedDescription)
        }
    }
}
