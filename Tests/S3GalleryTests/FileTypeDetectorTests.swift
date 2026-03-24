import Testing
@testable import S3Gallery

@Suite("FileTypeDetector")
struct FileTypeDetectorTests {

    // MARK: - Images

    @Test("jpg is image", arguments: ["jpg", "jpeg", "JPG", "JPEG"])
    func jpegIsImage(ext: String) {
        #expect(FileTypeDetector.category(for: ext) == .image)
    }

    @Test("png is image")
    func pngIsImage() {
        #expect(FileTypeDetector.category(for: "png") == .image)
    }

    @Test("heic is image")
    func heicIsImage() {
        #expect(FileTypeDetector.category(for: "heic") == .image)
    }

    @Test("gif is image")
    func gifIsImage() {
        #expect(FileTypeDetector.category(for: "gif") == .image)
    }

    @Test("webp is image")
    func webpIsImage() {
        #expect(FileTypeDetector.category(for: "webp") == .image)
    }

    @Test("tiff is image", arguments: ["tiff", "tif"])
    func tiffIsImage(ext: String) {
        #expect(FileTypeDetector.category(for: ext) == .image)
    }

    // MARK: - Videos

    @Test("mp4 is video")
    func mp4IsVideo() {
        #expect(FileTypeDetector.category(for: "mp4") == .video)
    }

    @Test("mov is video")
    func movIsVideo() {
        #expect(FileTypeDetector.category(for: "mov") == .video)
    }

    @Test("m4v is video")
    func m4vIsVideo() {
        #expect(FileTypeDetector.category(for: "m4v") == .video)
    }

    // MARK: - Audio

    @Test("mp3 is audio")
    func mp3IsAudio() {
        #expect(FileTypeDetector.category(for: "mp3") == .audio)
    }

    @Test("aac is audio")
    func aacIsAudio() {
        #expect(FileTypeDetector.category(for: "aac") == .audio)
    }

    @Test("m4a is audio")
    func m4aIsAudio() {
        #expect(FileTypeDetector.category(for: "m4a") == .audio)
    }

    @Test("flac is audio")
    func flacIsAudio() {
        #expect(FileTypeDetector.category(for: "flac") == .audio)
    }

    @Test("wav is audio")
    func wavIsAudio() {
        #expect(FileTypeDetector.category(for: "wav") == .audio)
    }

    // MARK: - PDF

    @Test("pdf is pdf")
    func pdfIsPDF() {
        #expect(FileTypeDetector.category(for: "pdf") == .pdf)
    }

    // MARK: - Other

    @Test("zip is other")
    func zipIsOther() {
        #expect(FileTypeDetector.category(for: "zip") == .other)
    }

    @Test("txt is other")
    func txtIsOther() {
        #expect(FileTypeDetector.category(for: "txt") == .other)
    }

    @Test("unknown extension is other")
    func unknownIsOther() {
        #expect(FileTypeDetector.category(for: "xyzabc") == .other)
    }

    @Test("empty extension is other")
    func emptyIsOther() {
        #expect(FileTypeDetector.category(for: "") == .other)
    }
}
