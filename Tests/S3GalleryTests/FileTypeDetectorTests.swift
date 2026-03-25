import Testing
@testable import S3Gallery

/// Tests for `FileTypeDetector`, which maps a file extension string to a `FileCategory`.
///
/// `FileTypeDetector` is the single source of truth for viewer routing: every file the browser
/// opens passes through it. The tests are intentionally exhaustive — each supported extension
/// gets its own case so a future change to the extension set causes a targeted test failure
/// rather than a silent regression.
@Suite("FileTypeDetector")
struct FileTypeDetectorTests {

    // MARK: - Images

    /// Verifies that JPEG files are identified as images regardless of case.
    ///
    /// S3 object keys are case-sensitive, so users may upload files with uppercase extensions
    /// (e.g. camera software that produces `IMG_0001.JPG`). The detector must normalise the
    /// extension to lowercase before matching so these files open in `PhotoViewer` rather than
    /// the QuickLook fallback. Both `jpg` and `jpeg` are tested because both are in common use.
    @Test("jpg is image", arguments: ["jpg", "jpeg", "JPG", "JPEG"])
    func jpegIsImage(ext: String) {
        #expect(FileTypeDetector.category(for: ext) == .image)
    }

    /// Verifies that PNG files are identified as images.
    ///
    /// PNG is the dominant lossless format for screenshots and UI assets stored in S3.
    /// It must open in `PhotoViewer` with zoom support rather than downloading via QuickLook.
    @Test("png is image")
    func pngIsImage() {
        #expect(FileTypeDetector.category(for: "png") == .image)
    }

    /// Verifies that HEIC files are identified as images.
    ///
    /// HEIC is the default photo format on modern iPhones. Users who back up their camera roll
    /// to S3 will have HEIC files; they must open natively in `PhotoViewer` via `AsyncImage`
    /// rather than falling through to QuickLook.
    @Test("heic is image")
    func heicIsImage() {
        #expect(FileTypeDetector.category(for: "heic") == .image)
    }

    /// Verifies that GIF files are identified as images.
    ///
    /// GIFs may be animated, but `AsyncImage` handles them correctly via the system image
    /// pipeline. Routing them to `PhotoViewer` gives the user a full-screen view; the
    /// alternative (QuickLook) would show a static first frame.
    @Test("gif is image")
    func gifIsImage() {
        #expect(FileTypeDetector.category(for: "gif") == .image)
    }

    /// Verifies that WebP files are identified as images.
    ///
    /// WebP is widely used for web-optimised images. iOS 14+ supports WebP natively, so
    /// `AsyncImage` can decode them without any additional dependencies.
    @Test("webp is image")
    func webpIsImage() {
        #expect(FileTypeDetector.category(for: "webp") == .image)
    }

    /// Verifies that both TIFF extension variants are identified as images.
    ///
    /// Professional cameras and design tools (e.g. Photoshop exports) often produce `.tiff`
    /// files. The shorter `.tif` variant is equally common and must be handled identically.
    @Test("tiff is image", arguments: ["tiff", "tif"])
    func tiffIsImage(ext: String) {
        #expect(FileTypeDetector.category(for: ext) == .image)
    }

    // MARK: - Videos

    /// Verifies that MP4 files are identified as videos.
    ///
    /// MP4 is the most common container format for video content stored in S3. It must route
    /// to `VideoPlayerView` so the user gets native AVKit controls (playback rate, AirPlay,
    /// Picture-in-Picture) rather than a full file download via QuickLook.
    @Test("mp4 is video")
    func mp4IsVideo() {
        #expect(FileTypeDetector.category(for: "mp4") == .video)
    }

    /// Verifies that MOV files are identified as videos.
    ///
    /// MOV is the native QuickTime container used by iPhone video recordings and Final Cut Pro
    /// exports. AVKit plays MOV natively, so these files should route to `VideoPlayerView`.
    @Test("mov is video")
    func movIsVideo() {
        #expect(FileTypeDetector.category(for: "mov") == .video)
    }

    /// Verifies that M4V files are identified as videos.
    ///
    /// M4V is Apple's container variant of MP4, used by iTunes purchases and some screen
    /// recordings. AVKit handles it natively; routing to `VideoPlayerView` is correct.
    @Test("m4v is video")
    func m4vIsVideo() {
        #expect(FileTypeDetector.category(for: "m4v") == .video)
    }

    // MARK: - Audio

    /// Verifies that MP3 files are identified as audio.
    ///
    /// MP3 is the most universal audio format. Routing to `AudioPlayerView` gives the user
    /// a purpose-built play/pause/scrub interface instead of QuickLook's minimal transport bar.
    @Test("mp3 is audio")
    func mp3IsAudio() {
        #expect(FileTypeDetector.category(for: "mp3") == .audio)
    }

    /// Verifies that AAC files are identified as audio.
    ///
    /// AAC is Apple's preferred compressed audio format, used in iTunes, podcasts, and
    /// voice memos. `AVAudioPlayer` handles it natively.
    @Test("aac is audio")
    func aacIsAudio() {
        #expect(FileTypeDetector.category(for: "aac") == .audio)
    }

    /// Verifies that M4A files are identified as audio.
    ///
    /// M4A is the MPEG-4 audio-only container, commonly produced by iPhone voice memos
    /// and GarageBand. It uses AAC encoding internally and plays via `AVAudioPlayer`.
    @Test("m4a is audio")
    func m4aIsAudio() {
        #expect(FileTypeDetector.category(for: "m4a") == .audio)
    }

    /// Verifies that FLAC files are identified as audio.
    ///
    /// FLAC is a lossless format popular for high-quality music archives. iOS 11+ supports
    /// FLAC playback natively via AVFoundation, so `AudioPlayerView` can handle it without
    /// any transcoding.
    @Test("flac is audio")
    func flacIsAudio() {
        #expect(FileTypeDetector.category(for: "flac") == .audio)
    }

    /// Verifies that WAV files are identified as audio.
    ///
    /// WAV is an uncompressed PCM format common in professional audio and voice recordings.
    /// `AVAudioPlayer` supports it natively on iOS.
    @Test("wav is audio")
    func wavIsAudio() {
        #expect(FileTypeDetector.category(for: "wav") == .audio)
    }

    // MARK: - PDF

    /// Verifies that PDF files are identified as PDFs and routed to the PDFKit viewer.
    ///
    /// PDF is the only format with its own dedicated category (rather than lumping it with
    /// `.other`) because `PDFKit` provides superior rendering quality, text search, and page
    /// navigation compared to `QLPreviewController`. The category check must be based on the
    /// `.pdf` extension directly, not UTType conformance, to avoid any ambiguity.
    @Test("pdf is pdf")
    func pdfIsPDF() {
        #expect(FileTypeDetector.category(for: "pdf") == .pdf)
    }

    // MARK: - Other / fallback

    /// Verifies that ZIP archives fall through to the QuickLook generic viewer.
    ///
    /// ZIP is not natively playable or previewable with a purpose-built viewer, so it must
    /// map to `.other`. `GenericFileView` will download it to a temp file and hand it to
    /// `QLPreviewController`, which can at least list the archive contents.
    @Test("zip is other")
    func zipIsOther() {
        #expect(FileTypeDetector.category(for: "zip") == .other)
    }

    /// Verifies that plain-text files fall through to the QuickLook generic viewer.
    ///
    /// Text files are common in S3 (READMEs, logs, CSVs) but don't warrant a dedicated viewer.
    /// `QLPreviewController` renders them with syntax highlighting on supported platforms.
    @Test("txt is other")
    func txtIsOther() {
        #expect(FileTypeDetector.category(for: "txt") == .other)
    }

    /// Verifies that a completely unknown extension defaults to `.other`.
    ///
    /// This is the catch-all safety net. Any extension not in the explicit allow-lists and not
    /// recognised by `UTType` conformance checks must produce `.other` so the app never crashes
    /// attempting to instantiate a viewer that can't handle the format.
    @Test("unknown extension is other")
    func unknownIsOther() {
        #expect(FileTypeDetector.category(for: "xyzabc") == .other)
    }

    /// Verifies that a file with no extension (empty string) defaults to `.other`.
    ///
    /// Some S3 objects have no file extension (e.g. objects uploaded programmatically with
    /// keys like `"data/raw/2024-01-01"`). The detector must handle an empty string gracefully
    /// and route to the QuickLook fallback rather than crashing or returning an incorrect category.
    @Test("empty extension is other")
    func emptyIsOther() {
        #expect(FileTypeDetector.category(for: "") == .other)
    }
}
