import XCTest
@testable import NotikaWhisper
import NotikaCore

final class WhisperModelStoreTests: XCTestCase {

    var tempDir: URL!
    var store: WhisperModelStore!

    @MainActor
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("whisper-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = WhisperModelStore(modelsDirectory: tempDir)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    @MainActor
    func test_installedModels_emptyInitially() {
        XCTAssertEqual(store.installedModels(), [])
    }

    @MainActor
    func test_installedModels_findsManuallyCreatedDir() throws {
        let modelDir = tempDir.appendingPathComponent(WhisperModelID.turbo.rawValue)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        try Data("dummy".utf8).write(to: modelDir.appendingPathComponent("model.txt"))
        XCTAssertEqual(store.installedModels(), [.turbo])
    }

    @MainActor
    func test_diskPath_returnsExpectedSubdir() {
        let path = store.diskPath(for: .base)
        XCTAssertTrue(path.path.hasSuffix(WhisperModelID.base.rawValue))
        XCTAssertTrue(path.path.hasPrefix(tempDir.path))
    }

    @MainActor
    func test_deleteModel_removesDirectory() throws {
        let modelDir = tempDir.appendingPathComponent(WhisperModelID.base.rawValue)
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: modelDir.appendingPathComponent("file"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelDir.path))
        try store.deleteModel(.base)
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelDir.path))
    }

    @MainActor
    func test_deleteModel_nonExistent_isNoOp() {
        XCTAssertNoThrow(try store.deleteModel(.largeV3))
    }

    @MainActor
    func test_disk_space_helper_returnsPositiveValue() {
        let available = store.availableDiskSpace()
        XCTAssertGreaterThan(available, 0)
    }
}
