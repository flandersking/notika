# Notika — Phase 1b-2 Design: Whisper lokale STT (WhisperKit)

**Stand:** 2026-04-18
**Vorgängerphase:** Phase 1b-1 (Multi-LLM-Engines, abgeschlossen + auf main gemerged)
**Folge-Phasen (separate Specs):**
- Phase 1b-3 — SwiftData-Dictionary
- Phase 1b-4 — Toggle-Trigger-Modus
- Phase 1b-5 — Sparkle Auto-Update
- Phase 1b-6 — Modifier-only Hotkeys

## 1. Ziel & Scope

Notika erhält **lokale Speech-to-Text via WhisperKit** als zweite STT-Option neben dem bestehenden Apple SpeechAnalyzer. Drei kuratierte Modelle stehen zum Download bereit. Eigener Settings-Tab „Spracherkennung" mit Modell-Liste, Download-Progress und Engine-Wahl.

Begleitende Features:
- Bestätigungs-Sheet nach Download („Als Standard verwenden?")
- Auto-Sprach-Detection (Deutsch/Englisch)
- Disk-Space-Check vor Download
- Auto-Fallback auf Apple bei Whisper-Fehler
- iOS-portable Architektur (kein AppKit in NotikaWhisper)

**Begründung:** Apple SpeechAnalyzer ist solide, aber Whisper Large-V3-Turbo schlägt Apple in Deutsch deutlich (besonders bei Fachvokabular und Akzenten). 100% offline = DSGVO-Story für Phase-2-Medizin. Ollama hat das schon für LLM gemacht; Whisper rundet das ab.

## 2. Vorgänger-Entscheidungen (aus Brainstorming 2026-04-18)

- **F1 Vendoring:** WhisperKit als SPM-Dependency (nicht xcframework, nicht Submodule)
- **F2 Modelle:** 3 kuratierte (Base / Turbo / Large V3)
- **F3 UI-Lokation:** Eigener Settings-Tab „Spracherkennung"
- **F4 Default nach Download:** Bestätigungs-Sheet
- **F5 Sprache:** Auto-Detect

## 3. Datenmodell

### 3.1 WhisperModelID (NotikaCore)

```swift
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

### 3.2 STTEngineChoice (NotikaCore)

```swift
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

### 3.3 SettingsStore-Erweiterung

```swift
public var sttEngineChoice: STTEngineChoice {
    get { /* JSON-decoded; default .apple */ }
    set { /* JSON-encoded */ }
}
```

Migration: Phase-1a hatte STT hardcoded — kein bestehender UserDefaults-Key zum Migrieren. Default `.apple` greift bei frischer Installation und nach App-Update.

## 4. Architektur

### 4.1 Package-Struktur

```
Packages/NotikaWhisper/
├── Package.swift                          # SPM: WhisperKit-Dependency
└── Sources/NotikaWhisper/
    ├── WhisperKitEngine.swift             # implementiert TranscriptionEngine
    ├── WhisperModelStore.swift            # Download/Install/List/Delete
    ├── WhisperModelDownloadProgress.swift # @Observable State für UI
    ├── WhisperError.swift                 # typisierte Fehler
    └── AudioResampler.swift               # 48kHz → 16kHz mono float32
```

**SPM-Dependency** in `Packages/NotikaWhisper/Package.swift`:
```swift
dependencies: [
    .package(path: "../NotikaCore"),
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
]
```

Genaue Version vor Build pinnen (z.B. `.exact("0.10.x")`). WhisperKit 0.x kann Breaking Changes haben.

### 4.2 TranscriptionEngine-Protokoll (unverändert aus Phase 1a)

```swift
public protocol TranscriptionEngine: AnyObject, Sendable {
    var id: TranscriptionEngineID { get }
    var supportsStreaming: Bool { get }
    func transcribe(audio: AudioSource, language: Language, hints: [String]) async throws -> Transcript
}
```

`TranscriptionEngineID.whisperCpp` ist bereits definiert (Stub aus Phase 1a) — wir benutzen den bestehenden Case (Name historisch, nicht umbenennen — würde Migration nötig machen, kein Mehrwert).

### 4.3 WhisperKitEngine

```swift
public final class WhisperKitEngine: TranscriptionEngine, @unchecked Sendable {
    public let id: TranscriptionEngineID = .whisperCpp
    public let supportsStreaming = false

    private let modelID: WhisperModelID
    private let modelStore: WhisperModelStore
    private var whisperKit: WhisperKit?       // lazy-init

    public init(modelID: WhisperModelID, modelStore: WhisperModelStore)

    public func transcribe(audio: AudioSource, language: Language, hints: [String]) async throws -> Transcript
}
```

**Verhalten:**
- **Lazy-Init:** WhisperKit-Instanz wird beim ersten `transcribe`-Aufruf geladen (Modell-File-Open + CoreML-Compile beim Erst-Use ~1-2 s). Spart App-Start-Zeit.
- **Sprache:** `language`-Parameter wird **ignoriert**. WhisperKit-Auto-Detect (Wahl 5=A). Erkannte Sprache wird (falls vom Transcript-Modell unterstützt) in einem optionalen Feld zurückgegeben — sonst nur als Logging-Datum verwendet, kein API-Break.
- **Hints:** als `initial_prompt` an WhisperKit. Phase 1b-2 übergibt leeren Array; Phase 1b-3 (Dictionary) wird das auf Term-Liste setzen.
- **Audio:** `.file(URL)` → an WhisperKit weiterreichen (lädt selbst), `.samples` → über `AudioResampler` auf 16 kHz/mono/float32 normalisieren.

### 4.4 WhisperModelStore

```swift
@MainActor
public final class WhisperModelStore {
    public init()

    public func installedModels() -> [WhisperModelID]
    public func startDownload(_ model: WhisperModelID) -> WhisperModelDownloadProgress
    public func cancelDownload(_ model: WhisperModelID)
    public func deleteModel(_ model: WhisperModelID) throws
    public func diskPath(for model: WhisperModelID) -> URL

    public static let modelsDirectory: URL  // ~/Library/Application Support/Notika/WhisperModels/
}
```

**Storage-Pfad:** `~/Library/Application Support/Notika/WhisperModels/<rawValue>/` — Standard-macOS-Lokation, vom User über Finder einsehbar, kein iCloud-Sync. Pro Modell ein Sub-Verzeichnis (WhisperKit erwartet das so).

**Disk-Space-Check** vor jedem `startDownload`:
- Frei verfügbar via `URL.resourceValues(.volumeAvailableCapacityForImportantUsageKey)`
- Required = `model.approximateBytes × 1.5` (50 % Sicherheitsmarge für Tempfiles)
- Wenn nicht genug: wirft `.insufficientDiskSpace(required:available:)`

**Download-Logik:**
- WhisperKit hat eingebaute `download`-Funktion gegen HuggingFace `argmaxinc/whisperkit-coreml`-Repo. Wir delegieren.
- Progress kommt als async stream → wir mappen auf `WhisperModelDownloadProgress`.

### 4.5 WhisperModelDownloadProgress

```swift
@MainActor
@Observable
public final class WhisperModelDownloadProgress {
    public let modelID: WhisperModelID
    public private(set) var state: State = .pending

    public enum State {
        case pending
        case downloading(bytesDownloaded: Int64, bytesTotal: Int64)
        case completed
        case failed(WhisperError)
        case cancelled
    }
}
```

UI-Code bindet via `@Observable` an die `state`-Property. Kein NotificationCenter / KVO nötig.

### 4.6 AudioResampler

```swift
public enum AudioResampler {
    public static func resampleTo16kMono(_ samples: [Float], inputSampleRate: Double) throws -> [Float]
}
```

Nutzt `AVAudioConverter` aus AVFoundation (verfügbar auf macOS + iOS). Ein-Funktions-API, statisch, leicht zu testen.

### 4.7 WhisperError

```swift
public enum WhisperError: Error, Sendable, Equatable, CustomStringConvertible {
    case modelNotInstalled(WhisperModelID)
    case downloadFailed(reason: String)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case downloadCancelled
    case modelLoadFailed(reason: String)
    case audioResamplingFailed
    case transcriptionFailed(reason: String)

    public var userFacingMessage: String { ... }
    public var description: String { ... }   // kein Body-Leak in Logs
}
```

Konsistent zum LLMError-Pattern aus Phase 1b-1: `CustomStringConvertible` schützt vor Body-Leaks in Logs.

## 5. UI-Veränderungen

### 5.1 Neuer Settings-Tab „Spracherkennung"

```
══ Aktive Spracherkennung ══════════════════════════
  [⦿] Apple SpeechAnalyzer (on-device, immer verfügbar)
  [○] Whisper (lokal) ▼ Whisper Turbo

══ Modelle ═════════════════════════════════════════
  ┌─ Apple SpeechAnalyzer ─────────────────────────┐
  │  System · 0 MB                       ✓ aktiv   │
  └────────────────────────────────────────────────┘
  ┌─ Whisper Base ─────────────────────────────────┐
  │  ~80 MB · schnell                  [ Laden  ]  │
  └────────────────────────────────────────────────┘
  ┌─ Whisper Turbo ────────────────────────────────┐
  │  ~800 MB · empfohlen           ✓ installiert   │
  │                                  [ Löschen ]   │
  └────────────────────────────────────────────────┘
  ┌─ Whisper Large V3 ─────────────────────────────┐
  │  ~1,5 GB · maximalqualität                     │
  │  Lade … ████████████░░░░░░░░  62 % · 480 MB    │
  │                                  [ Abbrechen ] │
  └────────────────────────────────────────────────┘
```

**Verhalten:**
- Engine-Wahl oben: Radio-Picker zwischen Apple und Whisper. Whisper-Option nur aktiv wenn mindestens ein Whisper-Modell installiert. Bei Whisper: Sub-Picker für installierte Modelle.
- Modell-Karten: pro Modell eine Zelle mit Status. „Laden" startet Download mit Progress-Bar inline. „Abbrechen" stoppt + räumt Tempfiles auf. „Löschen" mit Confirm-Dialog.
- Bei Löschen des aktiven Modells: Auto-Switch auf Apple, kurzes Toast „Apple SpeechAnalyzer aktiviert".

### 5.2 Confirm-Sheet nach Download (Wahl 4=C)

Modal-Sheet (NSWindow oder SwiftUI .sheet):
> **Whisper Turbo ist installiert**
> Als Standard-Spracherkennung verwenden? Du kannst das jederzeit in den Einstellungen ändern.
>
> [ Nein, später ]   [ Ja, jetzt aktivieren ]

Bei „Ja": `sttEngineChoice = .whisper(.turbo)`. Bei „Nein": Setting bleibt unverändert.

### 5.3 Pill-State während Whisper-Transkription

Bestehender `.transcribing(mode:)`-State reicht. Whisper braucht 2-7 s je nach Modell; Pill bleibt sichtbar. Kein Code-Change nötig.

### 5.4 Onboarding

**Kein neuer Step.** User entdeckt Whisper über Settings. Phase-1b-1-Onboarding ist bereits dicht.

## 6. Fehlerbehandlung

`WhisperError` typisiert (siehe 4.7).

**Coordinator-Verhalten** (analog zu Phase-1b-1 LLM-Fallback):
- `transcribe(...)` wirft `WhisperError` → Coordinator fängt ab, **fällt auf Apple SpeechAnalyzer zurück** für diesen einen Call
- Pill zeigt einmalig orange „Whisper-Fehler — wechsle zu Apple"
- `sttEngineChoice` wird **nicht** automatisch zurückgesetzt (Setting respektiert User-Entscheidung)
- Spezial-Fall `.modelNotInstalled` → Pill „Whisper-Modell fehlt — bitte erneut laden" + Auto-Fallback

**Download-Fehler:** rote Inline-Meldung in der Modell-Zelle, „Erneut versuchen"-Button. Tempfiles werden vor Retry geputzt.

## 7. Sicherheit & Privacy

- **100 % offline** nach Modell-Download. Audio verlässt das Gerät nie. Stärkstes Argument für Phase-2-Medizin (DSGVO).
- **Logging-Disziplin** (`os.Logger` Subsystem `com.notika.mac`, Category `Whisper`):
  - Erlaubt: Modell-ID, Audio-Länge in Sekunden, Latenz in ms, Erkennungs-Confidence-Average.
  - Verboten: Audio-Daten, Transkript-Inhalt, User-spezifische Identifier.
- **Modell-Quelle:** WhisperKit lädt von HuggingFace `argmaxinc/whisperkit-coreml` (CoreML-Format, geprüft von Argmax). Kein eigener Download-Code = keine Supply-Chain-Lücke.
- **Modell-Verzeichnis:** Standard macOS-Permissions, kein iCloud-Sync.

## 8. Tests

### 8.1 Unit-Tests (XCTest, neues Test-Target `NotikaWhisperTests`)

- `WhisperModelStore.installedModels()` — listet existierende Modell-Verzeichnisse korrekt (Setup mit Temp-Dir + Inject)
- `WhisperModelStore.deleteModel(...)` — räumt Verzeichnis komplett auf, auch verschachtelt
- `WhisperModelStore.startDownload(...)` mit zu wenig Disk-Space → wirft `.insufficientDiskSpace(required:available:)`
- `AudioResampler.resampleTo16kMono` — 48-kHz-Sinus-Welle in → 16-kHz-Sinus raus, Sample-Anzahl korrekt (1/3 der Input-Anzahl), RMS-Energie ungefähr erhalten (±10%)
- `WhisperModelID` Codable + displayName + Bytes-Mapping (3 Cases × Properties)
- `WhisperError.description` enthält keine Körper-Strings (Privacy-Schutz, analog zu LLMError)

WhisperKit selbst wird **nicht gemockt** — keine Engine-Unit-Tests gegen echte Modelle (würde Tests langsam und fragil machen). Engine wird im Smoketest manuell verifiziert.

### 8.2 Integration-Smoketest (manuell, dokumentiert in `docs/PHASE_1B_2_SMOKETEST.md`)

- Whisper Base download → Sheet erscheint → „Ja" aktivieren → Diktat in Mode 1 → Transkript landet im Programm
- Whisper Turbo download → ✓ installiert → wechsel auf Turbo → Diktat in Mode 2/3 → Transkript korrekt
- Whisper-Modell löschen → Auto-Fallback auf Apple → Diktat klappt weiter
- Während Whisper-Download: weiteres Diktat möglich (mit Apple parallel)
- Mit echten User-Audios in Deutsch + Englisch testen, Auto-Detect-Qualität verifizieren
- Smoketest auf MacBook M-Serie: Latenz pro Modell messen (Base ~1 s, Turbo ~2-3 s, Large V3 ~5-7 s erwartet)
- Disk-Space-Check: künstlich Disk auf < 1 GB füllen, Large-V3-Download starten → Error-Meldung muss erscheinen

## 9. Akzeptanzkriterien

Phase 1b-2 gilt als abgeschlossen, wenn:

- ✅ Settings → „Spracherkennung"-Tab vorhanden mit Engine-Picker + Modell-Liste
- ✅ Alle 3 Whisper-Modelle (Base/Turbo/Large-V3) downloadbar mit Live-Progress-Bar
- ✅ Disk-Space-Check vor Download löst korrekten Fehler aus
- ✅ Confirm-Sheet nach Download fragt nach Aktivierung
- ✅ Diktat mit aktivem Whisper-Modell funktioniert in allen 3 Modi (Literal/Social/Formal)
- ✅ Auto-Detect erkennt Deutsch + Englisch korrekt (Smoketest)
- ✅ Whisper-Fehler → Auto-Fallback auf Apple, Pill-Hinweis orange
- ✅ Modell-Löschen funktioniert + räumt Disk frei + bei aktivem Modell Auto-Switch zurück auf Apple
- ✅ STT-Wahl wird in UserDefaults persistiert + nach App-Restart wiederhergestellt
- ✅ Build SUCCEEDED, signiert mit Team P7QK554EET
- ✅ Alle Unit-Tests grün (Bestandstests + neue NotikaWhisperTests)
- ✅ NotikaWhisper-Package importiert kein AppKit (iOS-Portabilität)
- ✅ Kein Audio/Transkript in Console-Logs

## 10. Out of Scope (explizit ausgeschlossen)

- watchOS-App (Phase 3 Vision)
- Streaming-Transkription während Aufnahme (Phase 1b-3+ oder Phase 2)
- Custom Modell-IDs als Freitextfeld (kuratiertes Picker, analog zu Phase 1b-1 LLM-Picker)
- iCloud-Sync der Modelle (zu groß)
- Modell-Updates-Auto-Check (Sparkle macht App-Updates, Modelle bleiben statisch bis User-Aktion)
- WiFi-only-Toggle für Downloads (macOS hat keinen Cellular-Modus; Phase iOS-Port)
- Onboarding-Step für Whisper (Discovery via Settings reicht)
- Whisper-Models für Medical/spezial-fine-tuned (Phase 2 falls vorhanden)

## 11. Subagent-Strategie für Implementation

| Subagent | Verantwortung | Eingabe |
|---|---|---|
| `impl-whisper-engine` | `WhisperKitEngine` + `WhisperModelStore` + `AudioResampler` + `WhisperError` + Tests | TranscriptionEngine-Protokoll, WhisperKit-API-Doku, AVAudioConverter-Doku |
| Hauptkontext | SettingsStore-Erweiterung (`STTEngineChoice`, `sttEngineChoice`), neuer Settings-Tab UI, Confirm-Sheet, Coordinator-Integration (Engine-Lookup + Fallback) | — |

## 12. Risiken & offene Fragen

- **WhisperKit-API ist 0.x** — Breaking Changes möglich. Pin auf `.exact(...)` falls nötig.
- **HuggingFace-CDN-Verfügbarkeit** — kein Fallback-Mirror. User-sichtbare Fehler-Meldung „Bitte später erneut versuchen". Akzeptabel.
- **CoreML-Compile-Time beim ersten Modell-Use** — ~1-2 s Verzögerung bei erster Transcription nach App-Start. Mitigation: optionales Pre-Warm beim Tab-Verlassen oder beim Settings-Window-Schließen.
- **Modell-Verzeichnis nach App-Update** — wenn User Notika neu installiert, sind die Modelle ggf. weg (App-Bundle gelöscht, aber `~/Library/Application Support/Notika/` bleibt). Sollte gut sein.
- **iOS-Portabilität verifiziert?** — NotikaWhisper darf kein AppKit/macOS-only-API verwenden. Überprüfung in Tests / Build.

## Anhang A — Quellen

- WhisperKit: https://github.com/argmaxinc/WhisperKit
- WhisperKit-Modelle (HuggingFace): https://huggingface.co/argmaxinc/whisperkit-coreml
- AVAudioConverter (Resampling): https://developer.apple.com/documentation/avfaudio/avaudioconverter
