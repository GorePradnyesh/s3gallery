Plan to implement                                                                                                                                                                       
                                                                                                                                                                                        
S3Gallery iOS App — Project Plan                                                                                                                                                        
                                                                                                                                                                                        
Context                                                                                                                                                                                 
                                                                                                                                                                                        
The user wants a personal iOS app to browse and view private S3 content (photos, videos, PDFs, audio, and other files) directly from iPhone and iPad. Marketplace apps are distrusted   
due to credential leak risk, so this is a custom-built app sideloaded via Xcode for personal use. The project is also a learning exercise in using Claude Code for rapid iteration      
toward production quality.                                                                                                                                                              
                                                                                                                                                                                        
First execution step: Copy this plan to Documentation/S3galleryProjectPlan.md in the project repo.                                                                                      
                                                                                                                                                                                        
---                                                                                                                                                                                     
Confirmed Requirements                                                                                                                                                                  
                                                                                                                                                                                        
┌────────────────────┬──────────────────────────────────────────────────────────────────────────────────────────────────────────┐                                                       
│     Dimension      │                                                 Decision                                                 │                                                       
├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────┤                                                       
│ Platform           │ iPhone + iPad, iOS 17+, personal use (Xcode sideload)                                                    │                                                       
├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────┤                                                       
│ UI Framework       │ SwiftUI                                                                                                  │                                                       
├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────┤                                                       
│ AWS Auth           │ IAM Access Key ID + Secret Access Key                                                                    │                                                       
├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────┤                                                       
│ Accounts           │ Single account at a time                                                                                 │                                                       
├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────┤                                                       
│ Access             │ Read-only S3                                                                                             │                                                       
├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────┤                                                       
│ AWS Regions        │ Single region, user-configurable on login                                                                │                                                       
├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────┤                                                       
│ File Types         │ Photos, Videos (native), PDFs (PDFKit), Audio (AVFoundation), all other files (QuickLook + generic icon) │                                                       
├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────┤                                                       
│ Cache              │ Thumbnails only, configurable max size, cleared on logout                                                │                                                       
├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────┤                                                       
│ Credential Storage │ iOS Keychain (this-device-only)                                                                          │                                                       
├────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────────────┤                                                       
│ Distribution       │ Xcode direct install (no App Store)                                                                      │                                                       
└────────────────────┴──────────────────────────────────────────────────────────────────────────────────────────────────────────┘                                                       
                                                                                                                                                                                        
---                                                                                                                                                                                     
Architecture                                                                                                                                                                            
                                                                                                                                                                                        
Tech Stack                                                                                                                                                                              
                                                                                                                                                                                        
- Language: Swift 5.9+                                                                                                                                                                  
- UI: SwiftUI                                                                                                                                                                           
- AWS SDK: aws-sdk-swift via Swift Package Manager                                                                                                                                      
- Credential storage: iOS Keychain via Security framework                                                                                                                               
- Media playback: AVKit, AVFoundation                                                                                                                                                   
- PDF viewing: PDFKit                                                                                                                                                                   
- Generic file preview: QuickLook (QLPreviewController)                                                                                                                                 
- Thumbnail cache: URLCache (disk) + NSCache (in-memory)                                                                                                                                
                                                                                                                                                                                        
Project Structure                                                                                                                                                                       
                                                                                                                                                                                        
s3gallery/                                                                                                                                                                              
├── Documentation/                                                                                                                                                                      
│   └── S3galleryProjectPlan.md       ← This document (source of truth)                                                                                                                 
└── S3Gallery/                        ← Xcode project root                                                                                                                              
    ├── S3GalleryApp.swift                                                                                                                                                              
    ├── Models/                                                                                                                                                                         
    │   ├── Credentials.swift         ← Value type: accessKeyId, secretAccessKey, region                                                                                                
    │   ├── S3Item.swift              ← Enum: .folder / .file with metadata                                                                                                             
    │   └── BrowseState.swift         ← Current bucket + prefix path                                                                                                                    
    ├── Services/                                                                                                                                                                       
    │   ├── S3ServiceProtocol.swift   ← Protocol enabling mocking in tests                                                                                                              
    │   ├── S3Service.swift           ← aws-sdk-swift implementation                                                                                                                    
    │   ├── CredentialsService.swift  ← Keychain read/write/delete                                                                                                                      
    │   └── CacheService.swift        ← Thumbnail disk cache management                                                                                                                 
    ├── Views/                                                                                                                                                                          
    │   ├── Auth/                                                                                                                                                                       
    │   │   └── LoginView.swift                                                                                                                                                         
    │   ├── Browser/                                                                                                                                                                    
    │   │   ├── BrowserView.swift     ← NavigationStack + toolbar                                                                                                                       
    │   │   ├── BrowserListView.swift                                                                                                                                                   
    │   │   ├── BrowserGridView.swift ← LazyVGrid thumbnails                                                                                                                            
    │   │   ├── BrowserToolbar.swift  ← View mode, sort, breadcrumb                                                                                                                     
    │   │   └── S3ItemRow.swift       ← Shared row/cell component                                                                                                                       
    │   ├── Viewer/                                                                                                                                                                     
    │   │   ├── PhotoViewer.swift     ← Full-screen + pinch zoom                                                                                                                        
    │   │   ├── VideoPlayerView.swift ← AVKit VideoPlayer                                                                                                                               
    │   │   ├── PDFViewerView.swift   ← PDFKit UIViewRepresentable                                                                                                                      
    │   │   ├── AudioPlayerView.swift ← AVFoundation custom UI                                                                                                                          
    │   │   └── GenericFileView.swift ← QuickLook fallback                                                                                                                              
    │   └── Settings/                                                                                                                                                                   
    │       └── SettingsView.swift                                                                                                                                                      
    ├── ViewModels/                                                                                                                                                                     
    │   ├── AuthViewModel.swift                                                                                                                                                         
    │   ├── BrowserViewModel.swift                                                                                                                                                      
    │   └── ViewerViewModel.swift                                                                                                                                                       
    └── Utilities/                                                                                                                                                                      
        └── FileTypeDetector.swift    ← UTType/extension → viewer routing                                                                                                               
                                                                                                                                                                                        
---                                                                                                                                                                                     
Feature Breakdown                                                                                                                                                                       
                                                                                                                                                                                        
1. Authentication                                                                                                                                                                       
                                                                                                                                                                                        
- Login screen: Fields for AWS Access Key ID, Secret Access Key, and AWS Region (e.g. us-east-1).                                                                                       
- On submit: call S3Service.listBuckets() to validate credentials. Show inline error if invalid.                                                                                        
- On success: store credentials in Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly.                                                                                          
- App launch: check Keychain for existing credentials → skip login if found.                                                                                                            
- Logout: delete credentials from Keychain, clear thumbnail disk cache, navigate to login.                                                                                              
                                                                                                                                                                                        
2. S3 File Browser                                                                                                                                                                      
                                                                                                                                                                                        
- Bucket list: ListBuckets → display accessible buckets as top-level folder items.                                                                                                      
- Folder navigation: ListObjectsV2 with Delimiter: "/" and Prefix to simulate folders.                                                                                                  
  - Common prefixes → folder items.                                                                                                                                                     
  - Object keys → file items.                                                                                                                                                           
- Breadcrumb bar: bucket / folder / subfolder, tappable segments to navigate up.                                                                                                        
- View modes (toolbar toggle):                                                                                                                                                          
  - List: name, type icon, size, last-modified date.                                                                                                                                    
  - Grid: thumbnail (or type icon), filename caption.                                                                                                                                   
- Sorting: by name (A–Z, Z–A) and by date (newest/oldest first).                                                                                                                        
- Pull-to-refresh on folder contents.                                                                                                                                                   
                                                                                                                                                                                        
3. File Viewing                                                                                                                                                                         
                                                                                                                                                                                        
┌──────────────────────────────────────────┬────────────────────┬─────────────────────────────────────────────────────────────────┐                                                     
│                File Type                 │     Detection      │                             Viewer                              │                                                     
├──────────────────────────────────────────┼────────────────────┼─────────────────────────────────────────────────────────────────┤                                                     
│ Image (JPEG, PNG, HEIC, GIF, WebP, TIFF) │ UTType / extension │ PhotoViewer — streaming via presigned URL, pinch-to-zoom        │                                                     
├──────────────────────────────────────────┼────────────────────┼─────────────────────────────────────────────────────────────────┤                                                     
│ Video (MP4, MOV, M4V)                    │ UTType / extension │ VideoPlayerView — AVKit VideoPlayer with presigned URL          │                                                     
├──────────────────────────────────────────┼────────────────────┼─────────────────────────────────────────────────────────────────┤                                                     
│ PDF                                      │ .pdf extension     │ PDFViewerView — PDFView wrapped in UIViewRepresentable          │                                                     
├──────────────────────────────────────────┼────────────────────┼─────────────────────────────────────────────────────────────────┤                                                     
│ Audio (MP3, AAC, FLAC, WAV, M4A)         │ UTType / extension │ AudioPlayerView — AVAudioPlayer with play/pause/scrub UI        │                                                     
├──────────────────────────────────────────┼────────────────────┼─────────────────────────────────────────────────────────────────┤                                                     
│ Other                                    │ fallback           │ GenericFileView — QLPreviewController with downloaded temp file │                                                     
└──────────────────────────────────────────┴────────────────────┴─────────────────────────────────────────────────────────────────┘                                                     
                                                                                                                                                                                        
- Media playback uses presigned URLs (15-minute TTL) generated client-side. No data proxy.                                                                                              
                                                                                                                                                                                        
4. Thumbnail Cache                                                                                                                                                                      
                                                                                                                                                                                        
- Thumbnails generated at display time from image data or a placeholder icon.                                                                                                           
- Stored on disk in URLCache keyed by bucket/objectKey?thumb.                                                                                                                           
- In-memory NSCache layer for fast scroll performance.                                                                                                                                  
- Configurable max disk size (default 200 MB, adjustable in Settings).                                                                                                                  
- Eviction: LRU — oldest entries removed when limit is approached.                                                                                                                      
- Logout clears the entire cache directory.                                                                                                                                             
                                                                                                                                                                                        
5. Settings Screen                                                                                                                                                                      
                                                                                                                                                                                        
- Displays current account (Key ID prefix, region).                                                                                                                                     
- Cache usage indicator (e.g. "43 MB / 200 MB").                                                                                                                                        
- Slider/stepper to adjust max cache size.                                                                                                                                              
- "Clear Cache" button.                                                                                                                                                                 
- "Logout" button (clears cache + credentials + navigates to login).                                                                                                                    
                                                                                                                                                                                        
---                                                                                                                                                                                     
Security Notes                                                                                                                                                                          
                                                                                                                                                                                        
- Credentials stored in Keychain only; never in UserDefaults, files, or logs.                                                                                                           
- No analytics, no telemetry, no third-party SDKs beyond aws-sdk-swift.                                                                                                                 
- Read-only access enforced at AWS IAM policy level.                                                                                                                                    
- Presigned URLs have short TTL (15 min) and are never persisted.                                                                                                                       
- Cache stores thumbnails only — no full file content retained.                                                                                                                         
                                                                                                                                                                                        
---                                                                                                                                                                                     
Testing Strategy                                                                                                                                                                        
                                                                                                                                                                                        
Framework Choices                                                                                                                                                                       
                                                                                                                                                                                        
┌──────────────────────┬─────────────────────────────────┬──────────────────────────────────────────────────────────────────────────────────────────────────┐                           
│        Layer         │            Framework            │                                            Rationale                                             │                           
├──────────────────────┼─────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────┤                           
│ Unit tests           │ Swift Testing                   │ Modern macro-based framework, parallel by default, excellent error messages. iOS 17+ compatible. │                           
├──────────────────────┼─────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────┤                           
│ Integration tests    │ Swift Testing (separate target) │ Same framework, separate target run on-demand with real AWS credentials.                         │                           
├──────────────────────┼─────────────────────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────────┤                           
│ UI / simulator tests │ XCUITest                        │ Ships with Xcode, no extra dependencies. Architected for future Maestro expansion.               │                           
└──────────────────────┴─────────────────────────────────┴──────────────────────────────────────────────────────────────────────────────────────────────────┘                           
                                                                                                                                                                                        
---                                                                                                                                                                                     
Test Targets                                                                                                                                                                            
                                                                                                                                                                                        
S3GalleryTests (Unit — runs always, offline)                                                                                                                                            
                                                                                                                                                                                        
Uses protocol-based mocking. S3Service conforms to S3ServiceProtocol; tests inject MockS3Service.                                                                                       
                                                                                                                                                                                        
┌─────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────┐                                                            
│       Test Suite        │                                         What It Covers                                         │                                                            
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤                                                            
│ AuthViewModelTests      │ Login state machine: idle → loading → success/failure; credential validation rules             │                                                            
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤                                                            
│ CredentialsServiceTests │ Keychain write, read, delete (using a mock Keychain wrapper)                                   │                                                            
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤                                                            
│ S3ServiceMockTests      │ BrowserViewModel + ViewerViewModel behavior against MockS3Service responses                    │                                                            
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤                                                            
│ CacheServiceTests       │ Thumbnail insert, retrieval, eviction when size limit exceeded, logout clear                   │                                                            
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤                                                            
│ BrowserViewModelTests   │ Navigation (enter bucket, enter folder, breadcrumb pop), sort ordering, folder/file separation │                                                            
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤                                                            
│ ViewerViewModelTests    │ Presign URL construction, file type routing logic                                              │                                                            
├─────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤                                                            
│ FileTypeDetectorTests   │ Extension/UTType → viewer category mapping for all supported + unsupported types               │                                                            
└─────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────┘                                                            
                                                                                                                                                                                        
S3GalleryIntegrationTests (Real AWS — on-demand)                                                                                                                                        
                                                                                                                                                                                        
Run with xcodebuild -scheme S3GalleryIntegration -destination .... Credentials loaded from environment variables AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION (never committed).
 Requires a dedicated read-only test bucket with fixture files.                                                                                                                         
                                                                                                                                                                                        
┌───────────────────────────┬─────────────────────────────────────────────────────────────┐                                                                                             
│        Test Suite         │                       What It Covers                        │                                                                                             
├───────────────────────────┼─────────────────────────────────────────────────────────────┤                                                                                             
│ S3ServiceIntegrationTests │ Real listBuckets, listObjects, presignedURL against live S3 │                                                                                             
└───────────────────────────┴─────────────────────────────────────────────────────────────┘                                                                                             
                                                                                                                                                                                        
S3GalleryUITests (XCUITest — simulator)                                                                                                                                                 
                                                                                                                                                                                        
Run against the app in a "test mode" where MockS3Service is injected via a launch argument. No real AWS credentials needed.                                                             
                                                                                                                                                                                        
┌─────────────────┬──────────────────────────────────────────────────────────────────────────────────┐                                                                                  
│    Test Flow    │                                  What It Covers                                  │                                                                                  
├─────────────────┼──────────────────────────────────────────────────────────────────────────────────┤                                                                                  
│ LoginFlowTests  │ Enter credentials → success navigates to browser; invalid credentials show error │                                                                                  
├─────────────────┼──────────────────────────────────────────────────────────────────────────────────┤                                                                                  
│ BrowseFlowTests │ Tap bucket → enter folder → navigate breadcrumb back; switch list/grid views     │                                                                                  
├─────────────────┼──────────────────────────────────────────────────────────────────────────────────┤                                                                                  
│ ViewerFlowTests │ Tap image item → photo viewer opens; tap back → returns to browser               │                                                                                  
├─────────────────┼──────────────────────────────────────────────────────────────────────────────────┤                                                                                  
│ LogoutFlowTests │ Logout → navigates to login; re-launch without credentials shows login           │                                                                                  
└─────────────────┴──────────────────────────────────────────────────────────────────────────────────┘                                                                                  
                                                                                                                                                                                        
iOS-Specific Implementation Rules (must be applied to every new screen)

The following rules are derived from bugs found during development. Treat them as mandatory
checklist items when implementing or reviewing any SwiftUI screen.

┌────────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────┐
│                     Rule                       │                                            Rationale                                          │
├────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Every mutable property shown in the UI on an   │ Plain `var` on an ObservableObject does not trigger SwiftUI re-render. Bug: cache size slider  │
│ ObservableObject must be @Published.           │ updated the value silently but the label never refreshed until the view was dismissed/reopened. │
├────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ObservableObject references held by a view     │ @State is for value types only. Using @State with a reference type stores the pointer but does │
│ must use @ObservedObject (or @StateObject),    │ NOT subscribe to objectWillChange. Bug: @Published on CacheService fired correctly, but the    │
│ never @State.                                  │ view using @State never re-rendered because it never observed the publisher.                    │
├────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ For every @Published property that drives a    │ Unit-test the publisher: subscribe to objectWillChange, mutate the property, assert the sink   │
│ slider or live-updating label, write a unit    │ fired once per write. This catches missing @Published annotations before they reach the device. │
│ test asserting objectWillChange fires.         │                                                                                                │
├────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Image display in grids/lists must use          │ .scaledToFill() crops to fill the frame and distorts non-square images. Use .scaledToFit()     │
│ .scaledToFit(), not .scaledToFill().           │ with a semantic background color to letterbox/pillarbox and preserve the original aspect ratio. │
├────────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────┤
│ Thumbnail rendering must preserve aspect ratio │ UIGraphicsImageRenderer.draw(in: fixedSquareRect) stretches the image. Compute the aspect-fit  │
│ — compute aspect-fit size before rendering.   │ CGSize first (min scale in each dimension) and render into that, not the target square.         │
└────────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────┘

---

Maestro (Future Extensibility)                                                                                                                                                          
                                                                                                                                                                                        
Maestro YAML flows can be added at Tests/MaestroFlows/. The folder will be created in Phase 0 as a placeholder. Maestro runs against a real simulator build and can be integrated with  
an MCP server for Claude-driven test execution in future sessions.                                                                                                                      
                                                                                                                                                                                        
Tests/                                                                                                                                                                                  
├── MaestroFlows/           ← Placeholder, ready for Maestro YAML flows                                                                                                                 
│   └── README.md           ← Setup instructions for Maestro CLI                                                                                                                        
└── IntegrationConfig/                                                                                                                                                                  
    └── .env.example        ← Template for integration test credentials                                                                                                                 
                                                                                                                                                                                        
---                                                                                                                                                                                     
Phase Gates (must pass before proceeding to next phase)                                                                                                                                 
                                                                                                                                                                                        
Each phase is gated by:                                                                                                                                                                 
1. All unit tests for new code pass (run swift test or Xcode Test navigator).                                                                                                           
2. Manual smoke test in iOS Simulator per the checklist below.                                                                                                                          
                                                                                                                                                                                        
┌─────────────┬──────────────────────────────────────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────┐          
│    Phase    │                  Unit Test Gate                  │                                             Manual Smoke Test                                             │          
├─────────────┼──────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────┤          
│ 0 — Setup   │ Project builds with no warnings                  │ App launches in simulator, shows a placeholder screen                                                     │          
├─────────────┼──────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────┤          
│ 1 — Auth    │ AuthViewModelTests, CredentialsServiceTests pass │ Login with real IAM credentials succeeds; re-launch skips login; logout returns to login                  │          
├─────────────┼──────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────┤          
│ 2 — Browser │ BrowserViewModelTests, S3ServiceMockTests pass   │ Real S3 bucket browses; list and grid views render; breadcrumb navigates correctly                        │          
├─────────────┼──────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────┤          
│ 3 — Viewers │ ViewerViewModelTests, FileTypeDetectorTests pass │ Open a real photo, video, PDF, audio file, and an unknown file type in correct viewers                    │          
├─────────────┼──────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────┤          
│ 4 — Cache   │ CacheServiceTests pass (incl. @Published         │ Grid thumbnails load from cache on second visit; logout clears cache (verify size drops to 0 in Settings); │
│             │ reactivity + UserDefaults persistence tests)     │ dragging the cache size slider live-updates the "Max Cache Size: X MB" label while dragging              │          
├─────────────┼──────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────┤          
│ 5 — Polish  │ All test suites green                            │ iPad layout uses split view; dark mode correct; error states display properly                             │          
└─────────────┴──────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────┘          
                                                                                                                                                                                        
---                                                                                                                                                                                     
Implementation Phases                                                                                                                                                                   
                                                                                                                                                                                        
Phase 0 — Xcode Project Setup                                                                                                                                                           
                                                                                                                                                                                        
- Create Xcode project (S3Gallery, SwiftUI, iOS 17+).                                                                                                                                   
- Add aws-sdk-swift via Swift Package Manager (S3 module only).                                                                                                                         
- Create S3GalleryTests, S3GalleryIntegrationTests, S3GalleryUITests targets.                                                                                                           
- Create Tests/MaestroFlows/ and Tests/IntegrationConfig/.env.example.                                                                                                                  
- Set up folder structure as per architecture diagram above.                                                                                                                            
                                                                                                                                                                                        
Phase 1 — Authentication                                                                                                                                                                
                                                                                                                                                                                        
- Credentials model + CredentialsService (Keychain CRUD).                                                                                                                               
- S3ServiceProtocol + S3Service skeleton with listBuckets() for validation.                                                                                                             
- MockS3Service for unit tests.                                                                                                                                                         
- AuthViewModel + LoginView.                                                                                                                                                            
- App root: S3GalleryApp.swift shows LoginView or BrowserView based on Keychain state.                                                                                                  
- Unit tests: AuthViewModelTests, CredentialsServiceTests.                                                                                                                              
                                                                                                                                                                                        
Phase 2 — S3 File Browser                                                                                                                                                               
                                                                                                                                                                                        
- S3Item model + BrowseState.                                                                                                                                                           
- S3Service: listBuckets(), listObjects(bucket:prefix:), presignedURL(for:ttl:).                                                                                                        
- BrowserViewModel: loading state, navigation stack, sorting.                                                                                                                           
- BrowserView, BrowserListView, BrowserGridView, BrowserToolbar, S3ItemRow.                                                                                                             
- Unit tests: BrowserViewModelTests, S3ServiceMockTests.                                                                                                                                
- UI tests: LoginFlowTests, BrowseFlowTests.                                                                                                                                            
                                                                                                                                                                                        
Phase 3 — File Viewing                                                                                                                                                                  
                                                                                                                                                                                        
- FileTypeDetector utility.                                                                                                                                                             
- ViewerViewModel: presign + download logic.                                                                                                                                            
- PhotoViewer, VideoPlayerView, PDFViewerView, AudioPlayerView, GenericFileView.                                                                                                        
- Viewer routing from BrowserView on item tap.                                                                                                                                          
- Unit tests: ViewerViewModelTests, FileTypeDetectorTests.                                                                                                                              
- UI tests: ViewerFlowTests.                                                                                                                                                            
                                                                                                                                                                                        
Phase 4 — Thumbnail Cache                                                                                                                                                               
                                                                                                                                                                                        
- CacheService: URLCache-backed disk cache, NSCache in-memory layer, LRU eviction.                                                                                                      
- Async thumbnail loading in BrowserGridView cells.                                                                                                                                     
- Cache size enforcement and logout clearing.                                                                                                                                           
- Unit tests: CacheServiceTests.                                                                                                                                                        
                                                                                                                                                                                        
Phase 5 — Settings & Polish                                                                                                                                                             
                                                                                                                                                                                        
- SettingsView: cache usage, size control, logout.                                                                                                                                      
- iPad layout (NavigationSplitView — sidebar for buckets, detail for contents).                                                                                                         
- Accessibility (Dynamic Type, VoiceOver labels on all interactive elements).                                                                                                           
- Dark mode (automatic via SwiftUI semantic colors + SF Symbols).                                                                                                                       
- Loading skeletons / shimmer placeholder states.                                                                                                                                       
- Error states: invalid credentials, no network, access denied, empty bucket.                                                                                                           
- UI tests: LogoutFlowTests.                                                                                                                                                            
- Integration test run (S3GalleryIntegrationTests) as final validation.                                                                                                                 
                                                                                                                                                                                        
---                                                                                                                                                                                     
Key Files                                                                                                                                                                               
                                                                                                                                                                                        
┌────────────────────────────────────────────────┬──────────────────────────────────────────┐                                                                                           
│                      File                      │                 Purpose                  │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/Models/Credentials.swift             │ accessKeyId, secretAccessKey, region     │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/Models/S3Item.swift                  │ .folder / .file enum with metadata       │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/Services/S3ServiceProtocol.swift     │ Protocol for testability                 │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/Services/S3Service.swift             │ aws-sdk-swift S3Client wrapper           │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/Services/CredentialsService.swift    │ Keychain CRUD                            │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/Services/CacheService.swift          │ URLCache + NSCache thumbnail management  │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/Views/Auth/LoginView.swift           │ Login form                               │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/Views/Browser/BrowserView.swift      │ NavigationStack + toolbar + routing      │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/ViewModels/AuthViewModel.swift       │ Login state, validation, Keychain writes │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/ViewModels/BrowserViewModel.swift    │ S3 listing, navigation, sort             │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/ViewModels/ViewerViewModel.swift     │ Presign, download, file type routing     │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ S3Gallery/Utilities/FileTypeDetector.swift     │ Extension/UTType → viewer category       │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ Tests/S3GalleryTests/Mocks/MockS3Service.swift │ In-memory mock for unit tests            │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ Tests/IntegrationConfig/.env.example           │ Template for real AWS credentials        │                                                                                           
├────────────────────────────────────────────────┼──────────────────────────────────────────┤                                                                                           
│ Tests/MaestroFlows/README.md                   │ Maestro setup instructions               │                                                                                           
└────────────────────────────────────────────────┴──────────────────────────────────────────┘                                                                                           
                                                                                                                                                                                        
---                                                                                                                                                                                     
Subagent Handoff Notes                                                                                                                                                                  
                                                                                                                                                                                        
- Product Manager: Requirements are locked. MVP = Phases 0–3 (full browsing + viewing). Phases 4–5 add cache and polish. Phase gate = unit tests green + manual simulator smoke test.   
- Designer: Use SwiftUI semantic colors (Color.primary, .secondary, .background) for automatic dark/light. All icons from SF Symbols. Toolbar follows NavigationStack conventions. Grid:
 3 columns on iPhone, 4–5 on iPad. Viewers use .fullScreenCover. Minimal chrome — content first.                                                                                        
- iOS Developer: Add aws-sdk-swift via SPM, import AWSS3. Use S3Client with StaticCredentialsProvider(credentials:). Presigned URLs via S3Presigner. Define S3ServiceProtocol before
implementing S3Service to keep unit tests offline. Minimum deployment target: iOS 17.0, Xcode 15+.

---

Feature Request #3 — Multi-File Upload

Extends the single-file upload flow to allow selecting and uploading multiple files in one operation, with adaptive parallel throttling and a local preview for failed uploads.

UX Flow

  Idle → [Photo Library / Files picker (multi-select)]
       → Staging screen (file list, remove per-row, "Upload N Files" CTA)
       → Progress screen (per-file status icons, overall ProgressView)
       → Completion screen ("X of Y uploaded", failed section with QuickLook preview)

New Types

  UploadTask (S3Gallery/Models/UploadTask.swift)
    - id: UUID, filename: String, data: Data, contentType: String, state: UploadTaskState
    - UploadTaskState: .pending / .uploading / .success(S3FileItem) / .failure(Error)

  AdaptiveThrottle actor (inside UploadViewModel.swift)
    - Continuation-based semaphore, no polling
    - Starts at concurrency=3, min=1, max=6
    - Increases capacity after 3 consecutive successes; decreases after 2 consecutive failures
    - Wakes parked waiters immediately when capacity increases

UploadViewModel.phase (replaces .state)
  .idle / .staging([UploadTask]) / .uploading([UploadTask]) / .complete([UploadTask])

Files Modified

  S3Gallery/Models/UploadTask.swift               — new
  S3Gallery/ViewModels/UploadViewModel.swift       — UploadPhase + AdaptiveThrottle + startUpload()
  S3Gallery/Views/Browser/UploadSheet.swift        — staging/progress/completion sub-views + QuickLook
  S3Gallery/Testing/UITestSupport.swift            — --auto-stage, --mock-partial-failure flags
  Tests/S3GalleryTests/Mocks/MockS3Service.swift   — per-call results queue + uploadObjectDelay
  Tests/S3GalleryTests/UploadViewModelTests.swift  — multi-upload + AdaptiveThrottle unit tests
  Tests/S3GalleryUITests/UploadFlowTests.swift     — staging + completion UI tests

Test Gate

  Unit: swift test --filter UploadViewModelTests,AdaptiveThrottleTests — all pass
  UI:   S3GalleryUITests/UploadFlowTests — all pass in simulator

---

Feature Request #4 — File Sharing & Open In

Adds share, open-in, save-to-photos, and copy-to-files actions accessible via long-press context menu (single file), selection mode action bar (multi-file), and a share button inside all file viewers.

User Decisions
  - Triggers: Long press context menu (single file) + Select button → selection mode (multi-file) + viewer toolbar button
  - Actions: Share (system sheet), Open In, Save to Photos, Copy to Files
  - File delivery: Download full file to temp dir first, show progress, then present action

New Files
  S3Gallery/Services/FileActionService.swift          — download-to-temp, saveToPhotos; injectable URLSession
  S3Gallery/Views/Shared/ActivityViewController.swift — UIViewControllerRepresentable for UIActivityViewController
  S3Gallery/Views/Shared/DocumentPickerExporter.swift — UIViewControllerRepresentable for UIDocumentPickerViewController (export)
  S3Gallery/Views/Browser/SelectionActionBar.swift    — bottom action bar in selection mode
  Tests/S3GalleryTests/FileActionServiceTests.swift          — unit: download, cleanup, mock URLProtocol
  Tests/S3GalleryTests/BrowserViewModelSelectionTests.swift  — unit: enter/exit mode, toggle, multi-select
  Tests/S3GalleryUITests/FileActionFlowTests.swift           — UI: context menu, selection mode, share sheet

Modified Files
  S3Gallery/ViewModels/BrowserViewModel.swift         — isSelectionMode, selectedItems: Set<S3FileItem>, enter/exit/toggle
  S3Gallery/Views/Browser/BrowserView.swift           — Select button, BrowserSheet .share/.copyToFiles cases, handleAction() orchestration
  S3Gallery/Views/Browser/BrowserGridView.swift       — .contextMenu on GridCell, selection checkmark overlay
  S3Gallery/Views/Browser/BrowserListView.swift       — .contextMenu on rows, checkmark in selection mode
  S3Gallery/Views/Browser/S3ItemRow.swift             — isSelected: Bool param, checkmark indicator
  S3Gallery/Views/Browser/BrowserToolbar.swift        — Select/Done button, hide Sort/ViewMode in selection mode
  S3Gallery/Views/Viewer/ViewerContainer.swift        — pass onShare closure to each viewer, own download+share logic
  S3Gallery/Views/Viewer/PhotoViewer.swift            — share ToolbarItem
  S3Gallery/Views/Viewer/VideoPlayerView.swift        — share ToolbarItem
  S3Gallery/Views/Viewer/PDFViewerView.swift          — share ToolbarItem
  S3Gallery/Views/Viewer/AudioPlayerView.swift        — share ToolbarItem
  S3Gallery/Views/Viewer/GenericFileView.swift        — share ToolbarItem (reuse existing downloaded URL)
  S3Gallery/Info.plist                                — NSPhotoLibraryAddUsageDescription
  S3Gallery/Testing/UITestSupport.swift               — --mock-file-action launch arg

Key Decisions
  - UIActivityViewController(activityItems: [URL]) covers both Share and Open In — iOS shows compatible apps
    automatically when given a local file URL; UIDocumentInteractionController not needed
  - FileActionService is @Observable @MainActor, owned as @State in BrowserView and ViewerContainer
  - Download uses UUID-prefixed temp subdirs to avoid collisions during bulk selection downloads
  - Cleanup via onDismiss callbacks on share/copy sheets; immediate after saveToPhotos
  - Context menu "Select" pre-selects the long-pressed file and enters selection mode
  - FAB hidden when isSelectionMode is true (overlaps with SelectionActionBar)

Test Gate
  Unit: swift test --filter FileActionServiceTests,BrowserViewModelSelectionTests — all pass
  UI:   S3GalleryUITests/FileActionFlowTests — all pass in simulator (requires --mock-file-action)
  Manual: Select 5+ mixed files, verify adaptive throttle logs, verify QuickLook preview on failed file