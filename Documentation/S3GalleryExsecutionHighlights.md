# S3Gallery — Execution Highlights

## Session summary (2026-03-24)

Starting from a blank repo with only a requirements text file, a complete iOS app was designed, implemented, built, and sideloaded to a physical iPhone 14 Pro in a single session.

---

## What was built

### Project scaffolding
- `project.yml` — xcodegen spec drives the Xcode project; source of truth for targets, schemes, SPM packages, and signing. Regenerating with `xcodegen generate` recreates the `.xcodeproj` from scratch.
- `aws-sdk-swift 1.6.80` resolved via SPM — S3Client, presigned URLs, static credential resolver.
- Four targets: `S3Gallery` (app), `S3GalleryTests` (unit), `S3GalleryIntegrationTests` (on-demand), `S3GalleryUITests` (XCUITest).
- Two schemes: `S3Gallery` (run + UI tests), `S3GalleryUnitTests` (offline unit tests only).

### Application — 25 Swift source files

| Layer | Files |
|---|---|
| App entry point | `S3GalleryApp.swift`, `RootView` |
| Models | `Credentials`, `S3Item`, `S3FileItem`, `BrowseState`, `Breadcrumb` |
| Services | `S3ServiceProtocol`, `S3Service`, `CredentialsService`, `CacheService` |
| ViewModels | `AuthViewModel`, `BrowserViewModel`, `ViewerViewModel` |
| Views — Auth | `LoginView` |
| Views — Browser | `BrowserView`, `BrowserListView`, `BrowserGridView`, `BrowserToolbar`, `S3ItemRow` |
| Views — Viewers | `ViewerContainer`, `PhotoViewer`, `VideoPlayerView`, `PDFViewerView`, `AudioPlayerView`, `GenericFileView` |
| Views — Settings | `SettingsView` |
| Utilities | `FileTypeDetector` |

### Key features implemented
- **Keychain auth** — credentials stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; auto-login on relaunch, full wipe on logout.
- **S3 browser** — bucket list → folder drill-down with `ListObjectsV2` (delimiter `/`), breadcrumb navigation, list/grid toggle, four sort options, pull-to-refresh.
- **File viewers** — pinch-to-zoom photo viewer, AVKit video player, PDFKit PDF viewer, AVFoundation audio player with scrubber, QuickLook fallback for everything else. All stream via 15-minute presigned URLs — no data hits the app server.
- **Thumbnail cache** — two-layer (NSCache + disk), LRU eviction, configurable max size (default 200 MB), logout-triggered wipe. Cache usage visible in Settings.
- **Settings screen** — shows key ID prefix, region, disk usage progress, cache size slider, clear cache, logout.

### Tests — 12 Swift test files

| Target | Count | Framework | Status |
|---|---|---|---|
| `S3GalleryTests` (unit) | 53 tests | Swift Testing | ✅ all passing |
| `S3GalleryIntegrationTests` | 3 tests | Swift Testing | disabled (needs real AWS creds + env vars) |
| `S3GalleryUITests` | 10 tests | XCUITest | scaffolded (needs mock injection wiring) |

All 53 unit tests run offline with `MockS3Service` and `MockCredentialsService` — no AWS account required.

---

## Key engineering decisions

| Decision | Rationale |
|---|---|
| `@Observable` view models (not `ObservableObject`) | Reduces boilerplate, granular dependency tracking in iOS 17+ |
| Protocol-first S3 service (`S3ServiceProtocol`) | Enables full offline unit testing without real AWS |
| xcodegen instead of hand-edited `.xcodeproj` | Project file is readable, diffable, and reproducible |
| Presigned URLs for all media | No credentials or content touch the app process after presigning |
| Swift Testing over XCTest for unit tests | Parallel by default, parameterised tests, better failure messages |

---

## Bugs fixed during build

| Error | Fix |
|---|---|
| `S3ClientConfiguration` deprecated | Updated to `S3Client.S3ClientConfig` |
| `presignGetObject` not found | Corrected to `presignedURLForGetObject(input:expiration:)` returning `URL` directly |
| `obj.size` type mismatch (`Int` vs `Int64`) | Added `Int64(...)` cast |
| Double optional binding on `load()` result | Simplified guard to `guard let creds = try? service.load()` |
| `CacheService.clearAll()` actor isolation | Wrapped synchronous call in `Task { await ... }` |
| Test targets missing Info.plist | Added `GENERATE_INFOPLIST_FILE: YES` to xcodegen settings |
| Unit tests not discovered (0 tests ran) | Added explicit `S3GalleryUnitTests` scheme in `project.yml` |

---

## What's next

- Wire `--uitesting` / `--mock-s3-success` launch arguments into the app so XCUITests can run against a mock (Phase 5 UI test gate).
- Set up personal GitHub SSH key so `git push` works without HTTPS prompting.
- Run integration tests against a real read-only test bucket (`S3_TEST_BUCKET` env var).
- iPad split-view layout (`NavigationSplitView`) for Phase 5 polish.
