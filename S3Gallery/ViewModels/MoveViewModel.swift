import Foundation
import Observation

struct MoveFailure: Identifiable {
    let id = UUID()
    let fileName: String
    let reason: String
}

@Observable
@MainActor
final class MoveViewModel {

    // MARK: - Picker navigation

    private(set) var navigationStack: [BrowseState] = []
    private(set) var pickerFolders: [S3Item] = []
    private(set) var pickerLoadState: BrowserLoadState = .idle

    // MARK: - Move execution state

    enum Phase {
        case browsing
        case checkingConflicts
        case conflictsFound([String])
        case moving(completed: Int, total: Int, currentFile: String)
        case done([MoveFailure])
    }
    private(set) var phase: Phase = .browsing
    private(set) var loadError: String?

    // MARK: - Inputs

    let filesToMove: [S3FileItem]
    let bucket: String
    let sourcePrefix: String
    private let s3Service: any S3ServiceProtocol

    init(filesToMove: [S3FileItem], bucket: String, sourcePrefix: String, s3Service: any S3ServiceProtocol) {
        self.filesToMove = filesToMove
        self.bucket = bucket
        self.sourcePrefix = sourcePrefix
        self.s3Service = s3Service
    }

    // MARK: - Computed

    var currentPickerState: BrowseState? { navigationStack.last }
    var currentDestPrefix: String { currentPickerState?.prefix ?? "" }

    var currentFolderDisplayName: String {
        guard let state = currentPickerState else { return bucket }
        return state.prefix.isEmpty ? bucket : (state.breadcrumbs.last?.name ?? bucket)
    }

    /// Destination must differ from source to enable the Move Here button.
    var canMoveHere: Bool { currentDestPrefix != sourcePrefix }

    var isCheckingConflicts: Bool {
        if case .checkingConflicts = phase { return true }
        return false
    }

    var isMovingInProgress: Bool {
        if case .moving = phase { return true }
        return false
    }

    // MARK: - Picker navigation

    func loadRoot() async {
        navigationStack = [BrowseState(bucket: bucket, prefix: "")]
        await loadPickerFolders(prefix: "")
    }

    func enterFolder(prefix: String) async {
        navigationStack.append(BrowseState(bucket: bucket, prefix: prefix))
        await loadPickerFolders(prefix: prefix)
    }

    func navigate(to state: BrowseState) async {
        guard let index = navigationStack.firstIndex(of: state) else { return }
        navigationStack = Array(navigationStack.prefix(through: index))
        await loadPickerFolders(prefix: state.prefix)
    }

    func createFolder(named name: String) async throws {
        let folderPrefix = currentDestPrefix + name + "/"
        let exists = try await s3Service.prefixExists(bucket: bucket, prefix: folderPrefix)
        guard !exists else { throw CreateFolderError.alreadyExists }
        try await s3Service.createFolder(bucket: bucket, key: folderPrefix + ".s3gallery-probe")
        await loadPickerFolders(prefix: currentDestPrefix)
    }

    // MARK: - Move

    func requestMove() async {
        phase = .checkingConflicts
        let destPrefix = currentDestPrefix
        do {
            let existing = try await s3Service.listObjects(bucket: bucket, prefix: destPrefix)
            let existingNames = Set(existing.compactMap { item -> String? in
                guard case .file(let f) = item else { return nil }
                return f.name
            })
            let conflicts = filesToMove.compactMap { existingNames.contains($0.name) ? $0.name : nil }
            if conflicts.isEmpty {
                await performMove()
            } else {
                phase = .conflictsFound(conflicts)
            }
        } catch {
            loadError = error.localizedDescription
            phase = .browsing
        }
    }

    func confirmOverwrite() async {
        await performMove()
    }

    func cancelOverwrite() {
        phase = .browsing
    }

    // MARK: - Private

    private func performMove() async {
        let destPrefix = currentDestPrefix
        let total = filesToMove.count
        var failures: [MoveFailure] = []

        for (i, file) in filesToMove.enumerated() {
            phase = .moving(completed: i, total: total, currentFile: file.name)
            let destKey = destPrefix + file.name

            do {
                try await s3Service.copyObject(bucket: bucket, sourceKey: file.key, destKey: destKey)
            } catch {
                failures.append(MoveFailure(
                    fileName: file.name,
                    reason: "Could not copy: \(error.localizedDescription)"
                ))
                continue
            }

            do {
                try await s3Service.deleteObject(bucket: bucket, key: file.key)
            } catch {
                // File was copied successfully — only the source removal failed.
                failures.append(MoveFailure(
                    fileName: file.name,
                    reason: "Copied to destination, but source could not be removed: \(error.localizedDescription)"
                ))
            }
        }

        phase = .done(failures)
    }

    private func loadPickerFolders(prefix: String) async {
        pickerLoadState = .loading
        do {
            let allItems = try await s3Service.listObjects(bucket: bucket, prefix: prefix)
            pickerFolders = allItems.filter { $0.isFolder }
            pickerLoadState = .loaded
        } catch {
            pickerLoadState = .error(error.localizedDescription)
        }
    }
}
