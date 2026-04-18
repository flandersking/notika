# Notika Phase 1b-2 — Whisper lokale STT Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lokale Speech-to-Text via WhisperKit als Alternative zum Apple SpeechAnalyzer integrieren — mit eigenem Settings-Tab, drei kuratierten Modellen, Download-Progress, Auto-Sprach-Detection und Fallback-Logik.

**Architecture:** WhisperKit als SPM-Dependency in `NotikaWhisper`. Engine-Layer (WhisperKitEngine + ModelStore + AudioResampler) im Package, UI-Bits im App-Target. SettingsStore bekommt `STTEngineChoice` (analog zu LLMChoice aus 1b-1). DictationCoordinator wählt pro Diktat zwischen Apple und Whisper, fällt bei Whisper-Fehlern transparent auf Apple zurück.

**Tech Stack:** Swift 6.3 strict concurrency, WhisperKit 0.x (Argmax), AVAudioConverter (Resampling), SwiftUI + Observation (UI), XCTest.

**Spec:** `docs/superpowers/specs/2026-04-18-notika-phase-1b-2-whisper-design.md`

---

## File Structure

### Erstellt

**NotikaCore (Datenmodell):**
- `Packages/NotikaCore/Sources/NotikaCore/Models/WhisperModelID.swift`
- `Packages/NotikaCore/Sources/NotikaCore/Models/STTEngineChoice.swift`
- `Packages/NotikaCore/Tests/NotikaCoreTests/STTEngineChoiceTests.swift`

**NotikaWhisper (Engine):**
- `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperError.swift`
- `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperModelDownloadProgress.swift`
- `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperModelStore.swift`
- `Packages/NotikaWhisper/Sources/NotikaWhisper/AudioResampler.swift`
- `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift`
- `Packages/NotikaWhisper/Tests/NotikaWhisperTests/WhisperErrorTests.swift`
- `Packages/NotikaWhisper/Tests/NotikaWhisperTests/WhisperModelStoreTests.swift`
- `Packages/NotikaWhisper/Tests/NotikaWhisperTests/AudioResamplerTests.swift`

**App (UI + Integration):**
- `Notika/Settings/TranscriptionTab.swift`
- `Notika/Settings/WhisperModelRow.swift`
- `Notika/Overlay/WhisperDownloadConfirmSheet.swift`
- `docs/PHASE_1B_2_SMOKETEST.md`

### Modifiziert

- `Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift` — `sttEngineChoice` ergänzen
- `Packages/NotikaWhisper/Package.swift` — WhisperKit-Dependency + neues Test-Target
- `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperCppEngine.swift` — löschen (Stub aus Phase 1a, wird durch WhisperKitEngine ersetzt)
- `Notika/Settings/SettingsView.swift` — neuen Tab „Spracherkennung" einfügen
- `Notika/DictationCoordinator.swift` — STT-Wahl + Fallback-Logik
- `Notika/AppDelegate.swift` — `showWhisperDownloadConfirmSheet(for:)`-Helper

---

## Task 1: NotikaCore-Datenmodell + SettingsStore

**Files:**
- Create: `Packages/NotikaCore/Sources/NotikaCore/Models/WhisperModelID.swift`
- Create: `Packages/NotikaCore/Sources/NotikaCore/Models/STTEngineChoice.swift`
- Create: `Packages/NotikaCore/Tests/NotikaCoreTests/STTEngineChoiceTests.swift`
- Modify: `Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift`

- [ ] **Step 1.1: Failing test schreiben**

`Packages/NotikaCore/Tests/NotikaCoreTests/STTEngineChoiceTests.swift`:

```swift
import XCTest
@testable import NotikaCore

final class STTEngineChoiceTests: XCTestCase {
    func test_apple_codable_roundtrip() throws {
        let original: STTEngineChoice = .apple
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(STTEngineChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_whisper_turbo_codable_roundtrip() throws {
        let original: STTEngineChoice = .whisper(.turbo)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(STTEngineChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_displayName_apple() {
        XCTAssertEqual(STTEngineChoice.apple.displayName, "Apple SpeechAnalyzer")
    }

    func test_displayName_whisperTurbo_includesModelName() {
        XCTAssertTrue(STTEngineChoice.whisper(.turbo).displayName.contains("Turbo"))
    }

    func test_whisperModelID_allCases_haveSize() {
        for model in WhisperModelID.allCases {
            XCTAssertGreaterThan(model.approximateBytes, 0, "\(model.rawValue) muss eine Größe haben")
        }
    }

    @MainActor
    func test_settingsStore_sttEngineChoice_defaults_to_apple() {
        let defaults = UserDefaults(suiteName: "test.notika.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.sttEngineChoice, .apple)
    }

    @MainActor
    func test_settingsStore_sttEngineChoice_persists_whisperTurbo() {
        let defaults = UserDefaults(suiteName: "test.notika.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        store.sttEngineChoice = .whisper(.turbo)
        let store2 = SettingsStore(defaults: defaults)
        XCTAssertEqual(store2.sttEngineChoice, .whisper(.turbo))
    }
}
```

- [ ] **Step 1.2: Test schlägt fehl**

```bash
cd Packages/NotikaCore && swift test --filter STTEngineChoiceTests
```
Erwartet: Compile-Error „cannot find 'STTEngineChoice'".

- [ ] **Step 1.3: WhisperModelID.swift erstellen**

`Packages/NotikaCore/Sources/NotikaCore/Models/WhisperModelID.swift`:

```swift
import Foundation

public enum WhisperModelID: String, Codable, CaseIterable, Sendable, Hashable {
    case base    = "openai_whisper-base"
    case turbo   = "openai_whisper-large-v3-turbo"
    case largeV3 = "openai_whisper-large-v3"

    public var displayName: String {
        switch self {
        case .base:    return "Whisper Base (~80 MB, schnell)"
        case .turbo:   return "Whisper Turbo (~800 MB, empfohlen)"
        case .largeV3: return "Whisper Large V3 (~1,5 GB, maximalqualität)"
        }
    }

    public var approximateBytes: Int64 {
        switch self {
        case .base:    return 80  * 1_048_576
        case .turbo:   return 800 * 1_048_576
        case .largeV3: return 1_500 * 1_048_576
        }
    }
}
```

- [ ] **Step 1.4: STTEngineChoice.swift erstellen**

`Packages/NotikaCore/Sources/NotikaCore/Models/STTEngineChoice.swift`:

```swift
import Foundation

public enum STTEngineChoice: Codable, Sendable, Hashable {
    case apple
    case whisper(WhisperModelID)

    public var displayName: String {
        switch self {
        case .apple:           return "Apple SpeechAnalyzer"
        case .whisper(let m):  return m.displayName
        }
    }
}
```

- [ ] **Step 1.5: SettingsStore um sttEngineChoice erweitern**

In `Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift` direkt nach dem `globalLLMChoice`-Block (vor `defaultLanguage` falls vorhanden, sonst am Ende der MARK Sections) einfügen:

```swift
    // MARK: - STT-Engine

    public var sttEngineChoice: STTEngineChoice {
        get {
            guard let data = defaults.data(forKey: "notika.settings.sttEngineChoice"),
                  let value = try? JSONDecoder().decode(STTEngineChoice.self, from: data)
            else {
                return .apple   // Default: Phase-1a-Verhalten beibehalten
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "notika.settings.sttEngineChoice")
            }
        }
    }
```

- [ ] **Step 1.6: Tests laufen, alle 7 grün**

```bash
cd Packages/NotikaCore && swift test --filter STTEngineChoiceTests
```
Erwartet: 7× PASS.

- [ ] **Step 1.7: Commit**

```bash
git add Packages/NotikaCore/Sources/NotikaCore/Models/WhisperModelID.swift Packages/NotikaCore/Sources/NotikaCore/Models/STTEngineChoice.swift Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift Packages/NotikaCore/Tests/NotikaCoreTests/STTEngineChoiceTests.swift
git commit -m "Phase 1b-2 #1: NotikaCore-Datenmodell (WhisperModelID, STTEngineChoice, sttEngineChoice)"
```

---

## Task 2: WhisperKit-Dependency + WhisperError + Stub-Cleanup

**Files:**
- Modify: `Packages/NotikaWhisper/Package.swift`
- Delete: `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperCppEngine.swift`
- Create: `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperError.swift`
- Create: `Packages/NotikaWhisper/Tests/NotikaWhisperTests/WhisperErrorTests.swift`

- [ ] **Step 2.1: Package.swift erweitern**

`Packages/NotikaWhisper/Package.swift` komplett ersetzen:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotikaWhisper",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "NotikaWhisper", targets: ["NotikaWhisper"])
    ],
    dependencies: [
        .package(path: "../NotikaCore"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "NotikaWhisper",
            dependencies: [
                "NotikaCore",
                .product(name: "WhisperKit", package: "WhisperKit")
            ]
        ),
        .testTarget(
            name: "NotikaWhisperTests",
            dependencies: ["NotikaWhisper"]
        )
    ]
)
```

- [ ] **Step 2.2: Stub-Datei löschen**

```bash
rm Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperCppEngine.swift
```

(Wir behalten den Enum-Case `TranscriptionEngineID.whisperCpp` aus historischen Gründen — kein Migrations-Aufwand für User.)

- [ ] **Step 2.3: Failing test für WhisperError schreiben**

`Packages/NotikaWhisper/Tests/NotikaWhisperTests/WhisperErrorTests.swift`:

```swift
import XCTest
@testable import NotikaWhisper
import NotikaCore

final class WhisperErrorTests: XCTestCase {
    func test_modelNotInstalled_userFacingMessage_mentionsLaden() {
        let err = WhisperError.modelNotInstalled(.turbo)
        XCTAssertTrue(err.userFacingMessage.lowercased().contains("modell") ||
                      err.userFacingMessage.lowercased().contains("laden"))
    }

    func test_insufficientDiskSpace_userFacingMessage_mentionsSpeicher() {
        let err = WhisperError.insufficientDiskSpace(required: 1_500_000_000, available: 100_000_000)
        XCTAssertTrue(err.userFacingMessage.lowercased().contains("speicher"))
    }

    func test_description_doesNotLeakReason_for_downloadFailed() {
        let err = WhisperError.downloadFailed(reason: "Sensitive HTML body content xxx")
        XCTAssertFalse(err.description.contains("Sensitive HTML body content"))
        XCTAssertTrue(err.description.contains("downloadFailed"))
    }

    func test_description_doesNotLeakReason_for_transcriptionFailed() {
        let err = WhisperError.transcriptionFailed(reason: "very-long-internal-stack-trace")
        XCTAssertFalse(err.description.contains("very-long-internal-stack-trace"))
    }

    func test_description_for_modelNotInstalled_includesModelID() {
        let err = WhisperError.modelNotInstalled(.turbo)
        XCTAssertTrue(err.description.contains("turbo") || err.description.contains("Turbo"))
    }
}
```

- [ ] **Step 2.4: Test schlägt fehl**

```bash
cd Packages/NotikaWhisper && swift test --filter WhisperErrorTests
```
Erwartet: Compile-Error.

- [ ] **Step 2.5: WhisperError.swift implementieren**

`Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperError.swift`:

```swift
import Foundation
import NotikaCore

public enum WhisperError: Error, Sendable, Equatable, CustomStringConvertible {
    case modelNotInstalled(WhisperModelID)
    case downloadFailed(reason: String)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case downloadCancelled
    case modelLoadFailed(reason: String)
    case audioResamplingFailed
    case transcriptionFailed(reason: String)

    public var userFacingMessage: String {
        switch self {
        case .modelNotInstalled(let m):
            return "Whisper-Modell „\(m.displayName)" ist nicht geladen — bitte erneut laden"
        case .downloadFailed:
            return "Modell-Download fehlgeschlagen — bitte erneut versuchen"
        case .insufficientDiskSpace(let req, _):
            let gb = Double(req) / 1_073_741_824.0
            return String(format: "Nicht genug Speicherplatz frei (Modell braucht %.1f GB)", gb)
        case .downloadCancelled:
            return "Download abgebrochen"
        case .modelLoadFailed:
            return "Whisper-Modell konnte nicht geladen werden"
        case .audioResamplingFailed:
            return "Audio-Konvertierung fehlgeschlagen"
        case .transcriptionFailed:
            return "Transkription fehlgeschlagen — wechsle zu Apple SpeechAnalyzer"
        }
    }

    public var description: String {
        switch self {
        case .modelNotInstalled(let m):           return "modelNotInstalled(\(m.rawValue))"
        case .downloadFailed:                     return "downloadFailed"
        case .insufficientDiskSpace(let r, let a): return "insufficientDiskSpace(required: \(r), available: \(a))"
        case .downloadCancelled:                  return "downloadCancelled"
        case .modelLoadFailed:                    return "modelLoadFailed"
        case .audioResamplingFailed:              return "audioResamplingFailed"
        case .transcriptionFailed:                return "transcriptionFailed"
        }
    }
}
```

- [ ] **Step 2.6: Tests grün + Build**

```bash
cd Packages/NotikaWhisper && swift test --filter WhisperErrorTests
```
Erwartet: 5× PASS.

```bash
./scripts/build.sh 2>&1 | tail -5
```
Erwartet: BUILD SUCCEEDED. WhisperKit wird beim ersten Build aus dem Netz geladen — das kann 1-2 Min dauern.

- [ ] **Step 2.7: Commit**

```bash
git add Packages/NotikaWhisper/Package.swift Packages/NotikaWhisper/Sources/NotikaWhisper/ Packages/NotikaWhisper/Tests/
git commit -m "Phase 1b-2 #2: WhisperKit-Dependency + WhisperError typisiert (mit Body-Leak-Schutz)"
```

---

## Task 3: WhisperModelDownloadProgress (Observable State)

**Files:**
- Create: `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperModelDownloadProgress.swift`

- [ ] **Step 3.1: WhisperModelDownloadProgress.swift erstellen**

`Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperModelDownloadProgress.swift`:

```swift
import Foundation
import Observation
import NotikaCore

@MainActor
@Observable
public final class WhisperModelDownloadProgress {
    public let modelID: WhisperModelID
    public private(set) var state: State = .pending

    public enum State: Sendable, Equatable {
        case pending
        case downloading(bytesDownloaded: Int64, bytesTotal: Int64)
        case completed
        case failed(WhisperError)
        case cancelled
    }

    public init(modelID: WhisperModelID) {
        self.modelID = modelID
    }

    public func update(_ newState: State) {
        state = newState
    }

    public var fractionCompleted: Double {
        if case .downloading(let done, let total) = state, total > 0 {
            return min(1.0, Double(done) / Double(total))
        }
        if case .completed = state { return 1.0 }
        return 0.0
    }
}
```

- [ ] **Step 3.2: Build verifizieren**

```bash
cd Packages/NotikaWhisper && swift build 2>&1 | tail -3
```

- [ ] **Step 3.3: Commit**

```bash
git add Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperModelDownloadProgress.swift
git commit -m "Phase 1b-2 #3: WhisperModelDownloadProgress als @Observable State"
```

---

## Task 4: AudioResampler

**Files:**
- Create: `Packages/NotikaWhisper/Sources/NotikaWhisper/AudioResampler.swift`
- Create: `Packages/NotikaWhisper/Tests/NotikaWhisperTests/AudioResamplerTests.swift`

- [ ] **Step 4.1: Failing test schreiben**

`Packages/NotikaWhisper/Tests/NotikaWhisperTests/AudioResamplerTests.swift`:

```swift
import XCTest
@testable import NotikaWhisper

final class AudioResamplerTests: XCTestCase {

    func test_resample_48kTo16k_outputCount_isOneThird() throws {
        // 1 Sekunde 48 kHz Sinus → erwartet ~16000 Samples bei 16 kHz
        let sampleCount = 48_000
        let frequency: Float = 440  // A4
        let samples = (0..<sampleCount).map { i -> Float in
            sin(2 * .pi * frequency * Float(i) / 48_000.0)
        }
        let resampled = try AudioResampler.resampleTo16kMono(samples, inputSampleRate: 48_000)
        // Erwarteter Output: 16000 ± 100 (kleine Konvertierungs-Schwankung)
        XCTAssertGreaterThan(resampled.count, 15_900)
        XCTAssertLessThan(resampled.count, 16_100)
    }

    func test_resample_16kInput_returnsSimilarCount() throws {
        // Wenn schon 16 kHz reinkommt: Output sollte ungefähr gleich sein
        let samples = Array(repeating: Float(0.5), count: 16_000)
        let resampled = try AudioResampler.resampleTo16kMono(samples, inputSampleRate: 16_000)
        XCTAssertGreaterThan(resampled.count, 15_900)
        XCTAssertLessThan(resampled.count, 16_100)
    }

    func test_resample_preservesEnergyApproximately() throws {
        // RMS-Energie nach Resampling sollte ungefähr gleich bleiben
        let sampleCount = 48_000
        let samples = (0..<sampleCount).map { _ in Float.random(in: -0.5...0.5) }
        let inputRMS = sqrt(samples.reduce(0) { $0 + $1*$1 } / Float(samples.count))
        let resampled = try AudioResampler.resampleTo16kMono(samples, inputSampleRate: 48_000)
        let outputRMS = sqrt(resampled.reduce(0) { $0 + $1*$1 } / Float(resampled.count))
        // RMS-Abweichung max 30% (Resampling glättet hochfrequentes Rauschen)
        XCTAssertLessThan(abs(inputRMS - outputRMS) / inputRMS, 0.3)
    }

    func test_resample_emptyInput_returnsEmpty() throws {
        let resampled = try AudioResampler.resampleTo16kMono([], inputSampleRate: 48_000)
        XCTAssertEqual(resampled.count, 0)
    }
}
```

- [ ] **Step 4.2: Test schlägt fehl**

```bash
cd Packages/NotikaWhisper && swift test --filter AudioResamplerTests
```
Erwartet: Compile-Error „cannot find 'AudioResampler'".

- [ ] **Step 4.3: AudioResampler.swift implementieren**

`Packages/NotikaWhisper/Sources/NotikaWhisper/AudioResampler.swift`:

```swift
import Foundation
import AVFoundation

public enum AudioResampler {

    /// Konvertiert beliebige Sample-Rate (mono Float32) auf 16 kHz mono Float32.
    /// Whisper braucht exakt dieses Format.
    public static func resampleTo16kMono(_ samples: [Float], inputSampleRate: Double) throws -> [Float] {
        guard !samples.isEmpty else { return [] }

        let inputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                        sampleRate: inputSampleRate,
                                        channels: 1,
                                        interleaved: false)!
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: 16_000,
                                         channels: 1,
                                         interleaved: false)!

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw WhisperError.audioResamplingFailed
        }

        // Input-Buffer
        let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat,
                                           frameCapacity: AVAudioFrameCount(samples.count))!
        inputBuffer.frameLength = AVAudioFrameCount(samples.count)
        if let chan = inputBuffer.floatChannelData {
            samples.withUnsafeBufferPointer { src in
                chan[0].update(from: src.baseAddress!, count: samples.count)
            }
        }

        // Output-Buffer (Größe geschätzt: input * outputRate / inputRate, +1024 Sicherheit)
        let outFrames = AVAudioFrameCount(Double(samples.count) * 16_000 / inputSampleRate) + 1024
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                            frameCapacity: outFrames)!

        var fed = false
        var convError: NSError?
        let status = converter.convert(to: outputBuffer, error: &convError) { _, outStatus in
            if fed {
                outStatus.pointee = .endOfStream
                return nil
            }
            fed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        guard status != .error, convError == nil else {
            throw WhisperError.audioResamplingFailed
        }

        // Float-Array aus Output-Buffer extrahieren
        guard let outChan = outputBuffer.floatChannelData else {
            throw WhisperError.audioResamplingFailed
        }
        let outCount = Int(outputBuffer.frameLength)
        return Array(UnsafeBufferPointer(start: outChan[0], count: outCount))
    }
}
```

- [ ] **Step 4.4: Tests grün**

```bash
cd Packages/NotikaWhisper && swift test --filter AudioResamplerTests
```
Erwartet: 4× PASS.

- [ ] **Step 4.5: Commit**

```bash
git add Packages/NotikaWhisper/Sources/NotikaWhisper/AudioResampler.swift Packages/NotikaWhisper/Tests/NotikaWhisperTests/AudioResamplerTests.swift
git commit -m "Phase 1b-2 #4: AudioResampler (48kHz/anything → 16kHz mono float32) mit Tests"
```

---

## Task 5: WhisperModelStore (File-Mgmt + Disk-Check + Download-Orchestrierung)

**Files:**
- Create: `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperModelStore.swift`
- Create: `Packages/NotikaWhisper/Tests/NotikaWhisperTests/WhisperModelStoreTests.swift`

WhisperKit-API (Stand 0.9.x):
- `WhisperKit.download(variant: String, from: String, downloadBase: URL?, useBackgroundSession: Bool, progressCallback: ((Progress) -> Void)?) async throws -> URL`
- Returnt den Pfad zum heruntergeladenen Modell-Verzeichnis.

Wir setzen `downloadBase` auf unseren Storage-Pfad, damit Modelle dort landen statt im Default.

- [ ] **Step 5.1: Failing test schreiben**

`Packages/NotikaWhisper/Tests/NotikaWhisperTests/WhisperModelStoreTests.swift`:

```swift
import XCTest
@testable import NotikaWhisper
import NotikaCore

final class WhisperModelStoreTests: XCTestCase {

    var tempDir: URL!
    var store: WhisperModelStore!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("whisper-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = await WhisperModelStore(modelsDirectory: tempDir)
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
        // Marker-Datei, damit nicht-leeres Verzeichnis erkannt wird
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
        // Wir testen nur, dass available > 0 ist (echter Wert variiert)
        let available = store.availableDiskSpace()
        XCTAssertGreaterThan(available, 0)
    }
}
```

- [ ] **Step 5.2: Test schlägt fehl**

```bash
cd Packages/NotikaWhisper && swift test --filter WhisperModelStoreTests
```
Erwartet: Compile-Error.

- [ ] **Step 5.3: WhisperModelStore.swift implementieren**

`Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperModelStore.swift`:

```swift
import Foundation
import NotikaCore
import os
import WhisperKit

@MainActor
public final class WhisperModelStore {
    public let modelsDirectory: URL
    private let logger = Logger(subsystem: "com.notika.mac", category: "Whisper")
    private var activeProgresses: [WhisperModelID: WhisperModelDownloadProgress] = [:]
    private var activeTasks: [WhisperModelID: Task<Void, Never>] = [:]

    /// Default-Konstruktor: nutzt `~/Library/Application Support/Notika/WhisperModels/`.
    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Notika/WhisperModels")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.modelsDirectory = dir
    }

    /// Test-Konstruktor mit injiziertem Verzeichnis.
    public init(modelsDirectory: URL) {
        self.modelsDirectory = modelsDirectory
    }

    public func diskPath(for model: WhisperModelID) -> URL {
        modelsDirectory.appendingPathComponent(model.rawValue)
    }

    public func installedModels() -> [WhisperModelID] {
        WhisperModelID.allCases.filter { id in
            let path = diskPath(for: id)
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path.path) else {
                return false
            }
            return !contents.isEmpty
        }
    }

    public func availableDiskSpace() -> Int64 {
        let resourceValues = try? modelsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return resourceValues?.volumeAvailableCapacityForImportantUsage ?? 0
    }

    public func deleteModel(_ model: WhisperModelID) throws {
        let path = diskPath(for: model)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
            logger.info("Whisper-Modell gelöscht: \(model.rawValue, privacy: .public)")
        }
        activeProgresses.removeValue(forKey: model)
    }

    public func startDownload(_ model: WhisperModelID) -> WhisperModelDownloadProgress {
        if let existing = activeProgresses[model] {
            return existing
        }
        let progress = WhisperModelDownloadProgress(modelID: model)
        activeProgresses[model] = progress

        let required = Int64(Double(model.approximateBytes) * 1.5)
        let available = availableDiskSpace()
        if available < required {
            progress.update(.failed(.insufficientDiskSpace(required: required, available: available)))
            return progress
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let modelDir = self.diskPath(for: model)
                try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

                let url = try await WhisperKit.download(
                    variant: model.rawValue,
                    from: "argmaxinc/whisperkit-coreml",
                    downloadBase: self.modelsDirectory,
                    useBackgroundSession: false
                ) { [weak progress] foundationProgress in
                    Task { @MainActor in
                        let done = Int64(foundationProgress.completedUnitCount)
                        let total = Int64(foundationProgress.totalUnitCount)
                        progress?.update(.downloading(bytesDownloaded: done, bytesTotal: total))
                    }
                }
                self.logger.info("Whisper-Modell geladen: \(model.rawValue, privacy: .public) → \(url.path, privacy: .public)")
                progress.update(.completed)
            } catch is CancellationError {
                progress.update(.cancelled)
            } catch {
                self.logger.error("Whisper-Download-Fehler: \(error.localizedDescription, privacy: .public)")
                progress.update(.failed(.downloadFailed(reason: error.localizedDescription)))
            }
        }
        activeTasks[model] = task
        return progress
    }

    public func cancelDownload(_ model: WhisperModelID) {
        activeTasks[model]?.cancel()
        activeTasks.removeValue(forKey: model)
        activeProgresses.removeValue(forKey: model)
        // Tempfiles aufräumen
        let path = diskPath(for: model)
        try? FileManager.default.removeItem(at: path)
    }
}
```

> **Hinweis zum WhisperKit-API:** Die exakte Signatur von `WhisperKit.download(...)` kann zwischen 0.9.x-Versionen variieren. Wenn der Implementer-Subagent merkt dass die hier verwendeten Parameter nicht passen, soll er die WhisperKit-Source einlesen (Cache-Pfad: `~/Library/Developer/Xcode/DerivedData/.../SourcePackages/checkouts/WhisperKit/`) und die Aufrufe anpassen — Architektur-Idee bleibt gleich (Progress via Closure, Storage via downloadBase).

- [ ] **Step 5.4: Tests grün**

```bash
cd Packages/NotikaWhisper && swift test --filter WhisperModelStoreTests
```
Erwartet: 6× PASS (Disk-Space-Test ist umgebungsabhängig, sollte aber > 0 sein).

- [ ] **Step 5.5: Commit**

```bash
git add Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperModelStore.swift Packages/NotikaWhisper/Tests/NotikaWhisperTests/WhisperModelStoreTests.swift
git commit -m "Phase 1b-2 #5: WhisperModelStore mit File-Mgmt + Disk-Check + Download-Orchestration"
```

---

## Task 6: WhisperKitEngine (TranscriptionEngine-Implementation)

**Files:**
- Create: `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift`

WhisperKit-API für Transkription (Stand 0.9.x):
- `let pipe = try await WhisperKit(model: variant, modelFolder: path, ...)`
- `let results: [TranscriptionResult] = try await pipe.transcribe(audioPath: url.path, decodeOptions: ...)`
- `result.text`, `result.language`, `result.segments[i].text/start/end`

Wir initialisieren die Pipe lazy beim ersten `transcribe`-Call und cachen sie.

- [ ] **Step 6.1: WhisperKitEngine.swift erstellen**

`Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift`:

```swift
import Foundation
import NotikaCore
import os
import WhisperKit

public final class WhisperKitEngine: TranscriptionEngine, @unchecked Sendable {
    public let id: TranscriptionEngineID = .whisperCpp
    public let supportsStreaming = false

    private let modelID: WhisperModelID
    private let modelStore: WhisperModelStore
    private var whisperKit: WhisperKit?
    private let logger = Logger(subsystem: "com.notika.mac", category: "Whisper")

    public init(modelID: WhisperModelID, modelStore: WhisperModelStore) {
        self.modelID = modelID
        self.modelStore = modelStore
    }

    public func transcribe(audio: AudioSource, language: Language, hints: [String]) async throws -> Transcript {
        let pipe = try await loadPipeIfNeeded()
        let audioURL = try await prepareAudio(audio)

        let initialPrompt = hints.isEmpty ? nil : hints.joined(separator: " ")
        let decodeOptions = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: nil,                        // nil = Auto-Detect (Wahl 5=A)
            temperature: 0,
            sampleLength: 224,
            usePrefillPrompt: initialPrompt != nil,
            promptTokens: nil,
            prefixTokens: nil,
            withoutTimestamps: false,
            wordTimestamps: false
        )

        let started = Date()
        let results: [TranscriptionResult]
        do {
            results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: decodeOptions)
        } catch {
            logger.error("Whisper-Transkription fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            throw WhisperError.transcriptionFailed(reason: error.localizedDescription)
        }
        let elapsed = Date().timeIntervalSince(started)
        logger.info("Whisper OK: \(self.modelID.rawValue, privacy: .public), Dauer=\(String(format: "%.2f", elapsed))s")

        let combinedText = results.map(\.text).joined(separator: " ")
        let detectedLang = results.first?.language.flatMap { Language(whisperCode: $0) }
        let segments: [Transcript.Segment] = results.flatMap { tr -> [Transcript.Segment] in
            tr.segments.map { seg in
                Transcript.Segment(text: seg.text,
                                   start: TimeInterval(seg.start),
                                   end: TimeInterval(seg.end))
            }
        }
        return Transcript(text: combinedText.trimmingCharacters(in: .whitespacesAndNewlines),
                          segments: segments,
                          detectedLanguage: detectedLang)
    }

    private func loadPipeIfNeeded() async throws -> WhisperKit {
        if let pipe = whisperKit { return pipe }
        let modelDir = modelStore.diskPath(for: modelID)
        guard FileManager.default.fileExists(atPath: modelDir.path),
              let _ = try? FileManager.default.contentsOfDirectory(atPath: modelDir.path).first
        else {
            throw WhisperError.modelNotInstalled(modelID)
        }
        do {
            let pipe = try await WhisperKit(modelFolder: modelDir.path)
            whisperKit = pipe
            return pipe
        } catch {
            throw WhisperError.modelLoadFailed(reason: error.localizedDescription)
        }
    }

    private func prepareAudio(_ audio: AudioSource) async throws -> URL {
        switch audio {
        case .file(let url):
            return url
        case .samples(let samples, let rate):
            let resampled = try AudioResampler.resampleTo16kMono(samples, inputSampleRate: rate)
            // In tempFile schreiben, weil WhisperKit aktuell nur file-basiertes API anbietet
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("whisper-\(UUID().uuidString).wav")
            try writeWAV(samples: resampled, to: tempURL)
            return tempURL
        }
    }

    private func writeWAV(samples: [Float], to url: URL) throws {
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: 16_000,
                                   channels: 1,
                                   interleaved: false)!
        let file = try AVAudioFile(forWriting: url,
                                   settings: format.settings,
                                   commonFormat: .pcmFormatFloat32,
                                   interleaved: false)
        let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                       frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let chan = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { src in
                chan[0].update(from: src.baseAddress!, count: samples.count)
            }
        }
        try file.write(from: buffer)
    }
}

import AVFoundation

private extension Language {
    init?(whisperCode: String) {
        switch whisperCode.lowercased() {
        case "de": self = .german
        case "en": self = .english
        default:   return nil
        }
    }
}
```

> **Hinweis WhisperKit-API:** Wenn `DecodingOptions` oder `TranscriptionResult` in der WhisperKit-Version anders heißt: Implementer-Subagent soll Source-Header lesen (`Pods/Caches`-Suche) und anpassen. Architektur-Vertrag (lazy Pipe-Init, Auto-Detect via `language: nil`, optional `initial_prompt` aus hints) bleibt.

- [ ] **Step 6.2: Build verifizieren (Engine ist nicht unit-testbar gegen echtes Modell — manueller Smoketest in Task 10)**

```bash
cd Packages/NotikaWhisper && swift build 2>&1 | tail -3
```
Erwartet: BUILD SUCCEEDED.

- [ ] **Step 6.3: Alle existierenden Tests laufen**

```bash
cd Packages/NotikaWhisper && swift test 2>&1 | tail -3
```
Erwartet: alle bisherigen Tests grün (WhisperError + Resampler + ModelStore = 15 Tests).

- [ ] **Step 6.4: Commit**

```bash
git add Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift
git commit -m "Phase 1b-2 #6: WhisperKitEngine implementiert TranscriptionEngine (lazy-init, auto-detect)"
```

---

## Task 7: TranscriptionTab UI + WhisperModelRow

**Files:**
- Create: `Notika/Settings/TranscriptionTab.swift`
- Create: `Notika/Settings/WhisperModelRow.swift`

- [ ] **Step 7.1: TranscriptionTab.swift erstellen**

`Notika/Settings/TranscriptionTab.swift`:

```swift
import SwiftUI
import NotikaCore
import NotikaWhisper

struct TranscriptionTab: View {
    @State private var settings = SettingsStore()
    @State private var modelStore = WhisperModelStore()
    @State private var installed: [WhisperModelID] = []
    @State private var activeKind: ActiveKind = .apple
    @State private var activeWhisperModel: WhisperModelID = .turbo

    enum ActiveKind: String, CaseIterable, Identifiable {
        case apple, whisper
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .apple:   return "Apple SpeechAnalyzer (on-device, immer verfügbar)"
            case .whisper: return "Whisper (lokal)"
            }
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Aktive Spracherkennung", selection: $activeKind) {
                    ForEach(ActiveKind.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: activeKind) { _, _ in writeChoice() }

                if activeKind == .whisper {
                    Picker("Modell", selection: $activeWhisperModel) {
                        ForEach(installed, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .disabled(installed.isEmpty)
                    .onChange(of: activeWhisperModel) { _, _ in writeChoice() }
                    if installed.isEmpty {
                        Text("Lade unten ein Modell, um Whisper zu aktivieren.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Aktive Spracherkennung")
            }

            Section {
                appleRow
                ForEach(WhisperModelID.allCases, id: \.self) { model in
                    WhisperModelRow(model: model, modelStore: modelStore, isActive: isActive(model)) {
                        reloadInstalled()
                        // Sheet öffnen wenn Modell frisch installiert wurde
                        if installed.contains(model), settings.sttEngineChoice == .apple {
                            AppDelegate.shared?.showWhisperDownloadConfirmSheet(for: model) { activate in
                                if activate {
                                    settings.sttEngineChoice = .whisper(model)
                                    activeKind = .whisper
                                    activeWhisperModel = model
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Modelle")
            }
        }
        .formStyle(.grouped)
        .task { loadFromSettings() }
    }

    @ViewBuilder
    private var appleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple SpeechAnalyzer")
                Text("System · 0 MB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if case .apple = settings.sttEngineChoice {
                Label("aktiv", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }
        }
    }

    private func isActive(_ model: WhisperModelID) -> Bool {
        if case .whisper(let m) = settings.sttEngineChoice, m == model { return true }
        return false
    }

    private func loadFromSettings() {
        installed = modelStore.installedModels()
        switch settings.sttEngineChoice {
        case .apple:
            activeKind = .apple
        case .whisper(let m):
            activeKind = .whisper
            activeWhisperModel = m
        }
    }

    private func reloadInstalled() {
        installed = modelStore.installedModels()
    }

    private func writeChoice() {
        switch activeKind {
        case .apple:
            settings.sttEngineChoice = .apple
        case .whisper:
            if installed.contains(activeWhisperModel) {
                settings.sttEngineChoice = .whisper(activeWhisperModel)
            }
        }
    }
}
```

- [ ] **Step 7.2: WhisperModelRow.swift erstellen**

`Notika/Settings/WhisperModelRow.swift`:

```swift
import SwiftUI
import NotikaCore
import NotikaWhisper

struct WhisperModelRow: View {
    let model: WhisperModelID
    let modelStore: WhisperModelStore
    let isActive: Bool
    let onChange: () -> Void

    @State private var progress: WhisperModelDownloadProgress?
    @State private var installed: Bool = false
    @State private var deleteConfirm: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                    Text(humanReadableSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                trailingControl
            }
            if let progress {
                progressView(progress)
            }
        }
        .padding(.vertical, 4)
        .task { installed = modelStore.installedModels().contains(model) }
        .alert("Modell löschen?", isPresented: $deleteConfirm) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                try? modelStore.deleteModel(model)
                installed = false
                onChange()
            }
        } message: {
            Text("\(model.displayName) wird vom Datenträger entfernt.")
        }
    }

    private var humanReadableSize: String {
        let mb = Double(model.approximateBytes) / 1_048_576.0
        if mb >= 1_000 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    @ViewBuilder
    private var trailingControl: some View {
        if installed {
            HStack(spacing: 8) {
                if isActive {
                    Label("aktiv", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Label("installiert", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Button("Löschen", role: .destructive) {
                    deleteConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } else if let progress, case .downloading = progress.state {
            Button("Abbrechen") {
                modelStore.cancelDownload(model)
                self.progress = nil
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        } else {
            Button("Laden") { startDownload() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private func progressView(_ progress: WhisperModelDownloadProgress) -> some View {
        switch progress.state {
        case .pending, .downloading:
            HStack(spacing: 8) {
                ProgressView(value: progress.fractionCompleted)
                Text("\(Int(progress.fractionCompleted * 100)) %")
                    .font(.caption2)
                    .monospacedDigit()
            }
        case .completed:
            EmptyView()
        case .failed(let err):
            Label(err.userFacingMessage, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red)
                .font(.caption)
        case .cancelled:
            Label("Abgebrochen", systemImage: "xmark.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }

    private func startDownload() {
        let p = modelStore.startDownload(model)
        progress = p
        Task { @MainActor in
            // Polling auf state-Änderung — @Observable triggert Re-Render automatisch,
            // aber wir wollen `installed` aktualisieren wenn fertig
            for _ in 0..<7200 {  // max 1h Schutzlimit
                try? await Task.sleep(for: .seconds(1))
                if case .completed = p.state {
                    installed = true
                    onChange()
                    return
                }
                if case .failed = p.state { return }
                if case .cancelled = p.state { return }
            }
        }
    }
}
```

- [ ] **Step 7.3: Build verifizieren**

```bash
./scripts/build.sh 2>&1 | tail -5
```
Erwartet: BUILD SUCCEEDED.

- [ ] **Step 7.4: Commit**

```bash
git add Notika/Settings/TranscriptionTab.swift Notika/Settings/WhisperModelRow.swift
git commit -m "Phase 1b-2 #7: TranscriptionTab UI + WhisperModelRow mit Download-Progress"
```

---

## Task 8: Confirm-Sheet + AppDelegate-Helper

**Files:**
- Create: `Notika/Overlay/WhisperDownloadConfirmSheet.swift`
- Modify: `Notika/AppDelegate.swift`

- [ ] **Step 8.1: WhisperDownloadConfirmSheet.swift erstellen**

`Notika/Overlay/WhisperDownloadConfirmSheet.swift`:

```swift
import SwiftUI
import NotikaCore

struct WhisperDownloadConfirmSheet: View {
    let model: WhisperModelID
    let onActivate: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("\(model.displayName) ist installiert")
                .font(.title3).bold()
            Text("Als Standard-Spracherkennung verwenden? Du kannst das jederzeit in den Einstellungen ändern.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            HStack {
                Button("Nein, später", action: onLater)
                Spacer()
                Button("Ja, jetzt aktivieren", action: onActivate)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(width: 460)
    }
}
```

- [ ] **Step 8.2: AppDelegate-Methode hinzufügen**

In `Notika/AppDelegate.swift` analog zu `showLLMHintSheet()` (existiert seit Task 12 von Phase 1b-1) eine neue Methode hinzufügen — sie hostet `WhisperDownloadConfirmSheet` in einem floating NSWindow:

```swift
    private var whisperConfirmWindow: NSWindow?

    func showWhisperDownloadConfirmSheet(for model: WhisperModelID, onChoice: @escaping (Bool) -> Void) {
        let view = WhisperDownloadConfirmSheet(
            model: model,
            onActivate: { [weak self] in
                self?.whisperConfirmWindow?.close()
                self?.whisperConfirmWindow = nil
                onChoice(true)
            },
            onLater: { [weak self] in
                self?.whisperConfirmWindow?.close()
                self?.whisperConfirmWindow = nil
                onChoice(false)
            }
        )
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Spracherkennung"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        whisperConfirmWindow = window
    }
```

Falls AppDelegate die `import NotikaCore`-Zeile noch nicht hat, ergänzen.

- [ ] **Step 8.3: Build verifizieren**

```bash
./scripts/build.sh 2>&1 | tail -5
```
Erwartet: BUILD SUCCEEDED.

- [ ] **Step 8.4: Commit**

```bash
git add Notika/Overlay/WhisperDownloadConfirmSheet.swift Notika/AppDelegate.swift
git commit -m "Phase 1b-2 #8: WhisperDownloadConfirmSheet + AppDelegate-Helper"
```

---

## Task 9: SettingsView-Tab + DictationCoordinator-Integration mit Fallback

**Files:**
- Modify: `Notika/Settings/SettingsView.swift`
- Modify: `Notika/DictationCoordinator.swift`

- [ ] **Step 9.1: SettingsView-Tab einfügen**

In `Notika/Settings/SettingsView.swift` einen neuen Tab nach „Engines" und vor „Wörterbuch" einfügen:

```swift
            Tab("Engines", systemImage: "cpu") {
                EnginesTab()
            }
            Tab("Spracherkennung", systemImage: "waveform.badge.mic") {
                TranscriptionTab()
            }
            Tab("Wörterbuch", systemImage: "character.book.closed") {
                DictionaryTab()
            }
```

- [ ] **Step 9.2: DictationCoordinator-Engine-Resolution + Fallback**

In `Notika/DictationCoordinator.swift`:

**(a)** Property unten ergänzen (in der Initialisierungs-Sektion):

```swift
    private let whisperModelStore = WhisperModelStore()
```

**(b)** Den bestehenden Init-Block — der `transcriptionEngine` als `let` hardcoded Apple setzt — umstellen auf eine Resolve-Methode pro Diktat. Die Property von `let` auf private dynamisch:

```swift
    private var transcriptionEngine: TranscriptionEngine
    
    init() {
        // Initial mit Apple — wird pro Diktat in resolveTranscriptionEngine() neu evaluiert
        self.transcriptionEngine = TranscriptionEngineFactory.makeEngine(.appleSpeechAnalyzer)
    }
```

**(c)** Neue private Methode hinzufügen:

```swift
    /// Wählt die TranscriptionEngine für das nächste Diktat basierend auf den Settings.
    /// Bei `.whisper(modelID)` mit fehlendem Modell: Fallback auf Apple + Pill-Hinweis.
    private func resolveTranscriptionEngine() -> TranscriptionEngine {
        switch settings.sttEngineChoice {
        case .apple:
            return TranscriptionEngineFactory.makeEngine(.appleSpeechAnalyzer)
        case .whisper(let modelID):
            if whisperModelStore.installedModels().contains(modelID) {
                return WhisperKitEngine(modelID: modelID, modelStore: whisperModelStore)
            }
            // Fallback: Modell wurde z.B. extern gelöscht
            logger.warning("Whisper-Modell \(modelID.rawValue, privacy: .public) nicht installiert — Fallback auf Apple")
            return TranscriptionEngineFactory.makeEngine(.appleSpeechAnalyzer)
        }
    }
```

**(d)** Im `runPipeline(mode:audioURL:)`-Block, **vor** dem `try await self.transcriptionEngine.transcribe(...)`-Call: Engine resolven und in einen lokalen `let` cachen, dann mit do/catch um Fallback bei Whisper-Fehler:

```swift
            let engine = self.resolveTranscriptionEngine()
            self.overlay.updateState(.transcribing(mode: mode))

            let transcript: Transcript
            do {
                transcript = try await engine.transcribe(
                    audio: .file(audioURL),
                    language: .german,
                    hints: []
                )
            } catch let err as WhisperError {
                self.logger.warning("Whisper-Fehler: \(String(describing: err), privacy: .public) — Fallback auf Apple")
                self.overlay.updateState(.error(message: err.userFacingMessage))
                try? await Task.sleep(for: .seconds(2))
                let appleEngine = TranscriptionEngineFactory.makeEngine(.appleSpeechAnalyzer)
                transcript = try await appleEngine.transcribe(
                    audio: .file(audioURL),
                    language: .german,
                    hints: []
                )
            }
```

(Der Rest der Pipeline — `if transcript.text.isEmpty …`, LLM-Engine, TextInserter, History — bleibt unverändert.)

**Wichtig:** `import NotikaWhisper` in `DictationCoordinator.swift` ergänzen (war Stub-Import, jetzt aktiv genutzt).

- [ ] **Step 9.3: Build verifizieren**

```bash
./scripts/build.sh 2>&1 | tail -5
```
Erwartet: BUILD SUCCEEDED.

- [ ] **Step 9.4: Alle Tests laufen**

```bash
cd Packages/NotikaCore && swift test 2>&1 | tail -3
cd ../NotikaWhisper && swift test 2>&1 | tail -3
cd ../NotikaPostProcessing && swift test 2>&1 | tail -3
```
Erwartet: alle grün (NotikaCore +7 neue, NotikaWhisper 15 neue, NotikaPostProcessing unverändert).

- [ ] **Step 9.5: Commit**

```bash
git add Notika/Settings/SettingsView.swift Notika/DictationCoordinator.swift
git commit -m "Phase 1b-2 #9: SettingsView-Tab + Coordinator-Integration mit Whisper-Fallback"
```

---

## Task 10: Smoketest-Doku + finale Verifikation

**Files:**
- Create: `docs/PHASE_1B_2_SMOKETEST.md`

- [ ] **Step 10.1: Smoketest-Checkliste schreiben**

`docs/PHASE_1B_2_SMOKETEST.md`:

```markdown
# Phase 1b-2 Smoketest — Whisper lokale STT

Manuelle Akzeptanz-Tests vor dem Commit „Phase 1b-2 done".

## Vorbereitung
- macOS 26 Tahoe, Apple Silicon
- Notika frisch installiert oder `defaults delete <bundle-id>` + Neustart
- Internet-Verbindung für Modell-Download

## Settings → Spracherkennung Tab
- [ ] Tab erscheint zwischen „Engines" und „Wörterbuch"
- [ ] Aktive-Picker zeigt zwei Optionen, „Whisper" disabled wenn kein Modell installiert
- [ ] Apple-Zeile zeigt „aktiv" wenn `sttEngineChoice = .apple`
- [ ] Whisper-Zeilen zeigen Größe (~80 MB / ~800 MB / ~1,5 GB) und „Laden"-Button

## Modell-Download
- [ ] „Whisper Base" Laden klicken → Progress-Bar erscheint, läuft hoch
- [ ] Während Download: „Abbrechen"-Button funktioniert, räumt Tempfiles weg
- [ ] Nach erfolgreichem Download: Confirm-Sheet erscheint („Als Standard verwenden?")
- [ ] „Ja, jetzt aktivieren" → `sttEngineChoice` = `.whisper(.base)`, Tab oben aktualisiert
- [ ] „Nein, später" → Modell installiert, aber Apple bleibt aktiv

## Disk-Space
- [ ] Künstlich Disk auf <2 GB füllen, Large-V3-Download starten → Fehler-Meldung „Nicht genug Speicherplatz"

## Diktat mit aktivem Whisper
- [ ] Mode 1 Diktat starten → Pill: Recording → Transcribing (mehrere Sekunden!) → Inserting → Text landet
- [ ] Latenz: Base ~1s, Turbo ~2-3s, Large V3 ~5-7s (auf MacBook M-Serie)
- [ ] Mode 2/3 funktionieren ebenfalls
- [ ] Auto-Detect: deutsches Audio → deutsches Transkript, englisches Audio → englisches Transkript

## Whisper-Fehler-Fallback
- [ ] Aktives Modell extern löschen (`rm -rf ~/Library/Application\ Support/Notika/WhisperModels/openai_whisper-base/`)
- [ ] Diktat starten → Pill „Whisper-Modell nicht geladen" orange → automatisch mit Apple weiter, Text landet trotzdem
- [ ] `sttEngineChoice` bleibt auf `.whisper(.base)` (nicht auto-rückgesetzt)

## Modell-Löschen
- [ ] „Löschen" auf Turbo (aktiv) → Confirm-Dialog → Bestätigen → Modell-Verzeichnis weg
- [ ] Aktive-Picker zeigt jetzt Apple aktiv (Auto-Switch)

## Persistenz
- [ ] App neustarten → letzte STT-Wahl wird wiederhergestellt
- [ ] Installierte Modelle erscheinen wieder als „installiert"

## Sicherheit
- [ ] Console-Logs prüfen (`log stream --predicate 'subsystem == "com.notika.mac" AND category == "Whisper"'`):
  - Modell-IDs, Latenz, Audio-Längen sichtbar
  - Audio-Daten, Transkript-Inhalt NICHT sichtbar
- [ ] Modell-Dateien im Finder sichtbar in `~/Library/Application Support/Notika/WhisperModels/`

## Build
- [ ] Build SUCCEEDED, signiert mit Team P7QK554EET
- [ ] NotikaWhisper-Source enthält keinen `import AppKit` (iOS-Tauglichkeit)

## Tests
- [ ] `cd Packages/NotikaCore && swift test` — alle grün
- [ ] `cd Packages/NotikaWhisper && swift test` — alle grün
- [ ] `cd Packages/NotikaPostProcessing && swift test` — alle grün
```

- [ ] **Step 10.2: iOS-Tauglichkeit prüfen (sanity-grep)**

```bash
grep -rn "import AppKit\|UIKit" Packages/NotikaWhisper/Sources/ || echo "OK: keine AppKit/UIKit-Imports in NotikaWhisper"
```

Erwartet: „OK: keine AppKit/UIKit-Imports in NotikaWhisper". Falls doch welche gefunden → flag in Self-Review.

- [ ] **Step 10.3: STATUS.md updaten**

In `docs/STATUS.md` neue Sektion oben einfügen:

```markdown
## Phase 1b-2 abgeschlossen (2026-04-18)

- WhisperKit als SPM-Dependency in NotikaWhisper
- 3 kuratierte Whisper-Modelle (Base / Turbo / Large V3) downloadbar
- Eigener Settings-Tab „Spracherkennung" mit Engine-Picker + Modell-Liste
- Confirm-Sheet nach Download („Als Standard verwenden?")
- Auto-Sprach-Detection (Deutsch/Englisch)
- Auto-Fallback auf Apple SpeechAnalyzer bei Whisper-Fehler
- 100 % offline nach Modell-Download (DSGVO-Story für Phase 2)
- iOS-tauglich (kein AppKit in NotikaWhisper)
- Build SUCCEEDED, Tests grün

Nächste Sub-Phase: 1b-3 (SwiftData-Dictionary)
```

- [ ] **Step 10.4: Final-Commit**

```bash
git add docs/PHASE_1B_2_SMOKETEST.md docs/STATUS.md
git commit -m "Phase 1b-2 #10: Smoketest-Doku + Status-Update"
```

---

## Subagent-Strategie für Implementation

| Subagent | Tasks |
|---|---|
| Hauptkontext | Tasks 1, 8, 9, 10 (Datenmodell, App-UI-Integration, Smoketest) |
| `impl-whisper-engine` | Tasks 2, 3, 4, 5, 6 (gesamtes NotikaWhisper-Package, sequenziell weil Tasks aufeinander aufbauen) |
| Hauptkontext | Task 7 (TranscriptionTab — touched UI-Layer, cross-cutting mit Settings-Architektur) |

Die Engine-Tasks (2-6) sind **sequenziell** zu erledigen, weil jedes folgende Task auf dem vorigen aufbaut (z.B. WhisperKitEngine braucht ModelStore + AudioResampler). Aber sie können vom selben Subagent in einer Sitzung gemacht werden. UI-Tasks (7, 8, 9) können parallel zu Engine-Tasks laufen, nachdem Task 1 (Datenmodell) gelandet ist.

## Risiken & Bekanntes

- **WhisperKit-API-Drift:** Die im Plan verwendeten Aufruf-Signaturen (`WhisperKit.download(...)`, `WhisperKit(modelFolder:)`, `DecodingOptions`, `TranscriptionResult`) basieren auf 0.9.x-Stand. Der Implementer muss bei Compile-Fehlern die WhisperKit-Source einsehen (`~/Library/Developer/Xcode/DerivedData/.../SourcePackages/checkouts/WhisperKit/Sources/`) und die Aufrufe anpassen. Architektur-Verträge bleiben.
- **Erster Build dauert lang:** WhisperKit ist > 100 MB. Erster `swift build` zieht es aus GitHub und kompiliert.
- **Test-Coverage für Engine selbst:** Wir testen nicht gegen echtes Whisper-Modell (zu langsam, zu groß). Engine wird im Smoketest manuell verifiziert.
