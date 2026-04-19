# Design-Spec: Whisper Pre-Warm beim App-Start

**Datum:** 2026-04-19
**Scope:** Perf-Quick-Win — Cold-Start-Latenz eliminieren
**Aufwand:** ~30 min

## Problem

Das erste Diktat nach App-Start dauert ~5.2 s (gemessen: 3.25 s STT +
1.99 s LLM). Folge-Diktate nur ~1.5 s. Der Unterschied entsteht, weil
`DictationCoordinator.resolveTranscriptionEngine()` erst beim ersten Hotkey
die `WhisperKitEngine` instanziiert und `loadPipeIfNeeded()` die WhisperKit-
Pipe (632 MB Modell + CoreML-Init) synchron vor der ersten Transkription lädt.

## Ziel

Nach `coordinator.start()` soll das aktuell gewählte Whisper-Modell im
Hintergrund geladen werden, damit das erste Diktat ohne Cold-Start läuft
(Ziel: Total ≤ 2 s statt 5 s).

## Nicht-Ziel

- Kein Dummy-Audio-Inferenz-Call. WhisperKit-`prewarm` + Modell-Load
  reichen. Wenn das nicht genügt, wird das in einem zweiten Schritt addiert.
- Kein UI-Indikator für den Pre-Warm-Status. Still im Hintergrund.
- Keine Optimierung für Apple SpeechAnalyzer (kein Cold-Start-Problem).

## Lösung

### Änderung 1: `TranscriptionEngine`-Protokoll um `preWarm()` erweitern

```swift
// Packages/NotikaCore/Sources/NotikaCore/Transcription/TranscriptionEngine.swift
public protocol TranscriptionEngine: Sendable {
    var id: TranscriptionEngineID { get }
    var supportsStreaming: Bool { get }
    func transcribe(audio: AudioSource, language: Language, hints: [String]) async throws -> Transcript
    /// Optionaler Pre-Warm. Default-Implementierung ist no-op.
    func preWarm() async
}

public extension TranscriptionEngine {
    func preWarm() async { }
}
```

### Änderung 2: `WhisperKitEngine.preWarm()` nutzt bestehenden Lazy-Load

```swift
// Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift
public func preWarm() async {
    do {
        _ = try await loadPipeIfNeeded()
        logger.info("Whisper Pre-Warm OK: \(self.modelID.rawValue, privacy: .public)")
    } catch {
        logger.warning("Whisper Pre-Warm fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
    }
}
```

Zusätzlich WhisperKit-Init: `prewarm: true` setzen (aktuell `false`).
Das erzwingt CoreML-Graph-Compile beim Load, bevor die erste echte
Inferenz anläuft.

### Änderung 3: `DictationCoordinator.preWarm()` orchestriert

```swift
// Notika/DictationCoordinator.swift
func preWarm() async {
    let engine = resolveTranscriptionEngine()
    let started = Date()
    await engine.preWarm()
    let elapsed = Date().timeIntervalSince(started)
    logger.info("⏱️ Pre-Warm: \(String(format: "%.2f", elapsed))s")
}
```

### Änderung 4: `AppDelegate` triggert Pre-Warm im Hintergrund

```swift
// Notika/AppDelegate.swift — in applicationDidFinishLaunching, nach coordinator.start()
Task.detached(priority: .utility) { [coordinator] in
    await coordinator.preWarm()
}
```

Hinweis: `Task.detached` mit niedriger Priorität, damit UI-Start und
Permissions-Check nicht verzögert werden.

## Flow

1. App startet → AppDelegate ruft `coordinator.start()` → UI & Hotkeys sofort live.
2. Sekundenbruchteile später: `Task.detached` startet → `coordinator.preWarm()`
   → `resolveTranscriptionEngine()` → Cache befüllt → `WhisperKitEngine.preWarm()`
   → `loadPipeIfNeeded()` → Modell-Load + CoreML-Compile (~2-3 s Hintergrund).
3. User drückt Hotkey → `resolveTranscriptionEngine()` trifft Cache → sofort aufnahmebereit.
4. Nach Recording-Stop: `transcribe()` trifft die bereits warme Pipe → STT ~0.6 s.

## Edge Cases

- **Modell nicht installiert (User hat Apple ausgewählt):** `WhisperKitEngine`
  wird gar nicht erst erzeugt, `resolveTranscriptionEngine()` liefert Apple
  zurück, Apple-`preWarm()` ist no-op. Kein Effekt, kein Fehler.
- **User wechselt Modell direkt nach Start:** Pre-Warm lädt altes Modell,
  dann entsteht beim ersten Diktat ein Mini-Cold-Start für das neue Modell.
  Akzeptiert — Modellwechsel ist selten.
- **Pre-Warm noch nicht fertig beim ersten Diktat:** `loadPipeIfNeeded()`
  ist idempotent (`if let pipe = whisperKit { return pipe }`). Erstes Diktat
  wartet wie bisher, keine Race Condition.
- **Modell-Datei fehlt / korrupt:** `loadPipeIfNeeded()` wirft, `preWarm()`
  fängt und loggt `warning`. App läuft weiter, erstes Diktat scheitert dann
  genauso wie ohne Pre-Warm.

## Betroffene Dateien

- `Packages/NotikaCore/Sources/NotikaCore/Protocols/TranscriptionEngine.swift`
  — Protocol-Erweiterung + Default-Impl
- `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift`
  — `preWarm()` hinzufügen, `prewarm: true` in `WhisperKit()`-Init
- `Notika/DictationCoordinator.swift` — `preWarm()` Methode
- `Notika/AppDelegate.swift` — `Task.detached` in
  `applicationDidFinishLaunching`

## Testing

- **Unit-Test (optional):** `preWarm()`-Default-Impl ist no-op → nicht
  sinnvoll testbar.
- **Manueller Smoketest:**
  1. App neu starten, Console.app → Notika-Logs
  2. Innerhalb 5 s nach Start: Log-Zeile `⏱️ Pre-Warm: X.XXs` muss erscheinen
  3. Direkt danach Hotkey → kurzes Diktat
  4. Log-Zeile `⏱️ Total` muss ≤ 2 s zeigen (vorher 5.2 s)
  5. Zweites Diktat → identische Latenz (~1.5 s). Kein Regress.
- **Performance-Messung:**
  - Vor Change: erste Pipeline ~5 s Total, davon ~3.3 s STT
  - Nach Change: erste Pipeline ≤ 2 s Total, STT ≤ 0.8 s

## Offene Fragen

Keine.
