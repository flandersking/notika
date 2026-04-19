# Whisper Pre-Warm Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Erstes Diktat nach App-Start liefert in ≤ 2 s Total statt bisher ~5 s, indem das Whisper-Modell beim Launch im Hintergrund geladen und CoreML vorkompiliert wird.

**Architecture:** Opt-in `preWarm()`-Methode im `TranscriptionEngine`-Protokoll (Default no-op). `WhisperKitEngine.preWarm()` triggert den bestehenden Lazy-Load. `DictationCoordinator.preWarm()` setzt den Engine-Cache. `AppDelegate` feuert einen `Task.detached` nach `coordinator.start()`.

**Tech Stack:** Swift 6, WhisperKit 0.18, AppKit, `os.Logger`.

**Spec:** `docs/superpowers/specs/2026-04-19-notika-whisper-prewarm-design.md`

---

## File Structure

**Modify:**
- `Packages/NotikaCore/Sources/NotikaCore/Protocols/TranscriptionEngine.swift` — Protocol-Method + Default-Extension
- `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift` — `preWarm()` implementieren + `prewarm: true` in `WhisperKit()`-Init
- `Notika/DictationCoordinator.swift` — `preWarm()`-Orchestrator-Methode
- `Notika/AppDelegate.swift` — `Task.detached` in `applicationDidFinishLaunching`

**Keine neuen Dateien. Keine neuen Tests** (reiner Side-Effect + WhisperKit-Call, nicht sinnvoll unit-testbar ohne WhisperKit-Mock).

---

### Task 1: TranscriptionEngine-Protokoll um `preWarm()` erweitern

**Files:**
- Modify: `Packages/NotikaCore/Sources/NotikaCore/Protocols/TranscriptionEngine.swift`

- [ ] **Step 1: Datei-Stand prüfen**

Run:
```bash
sed -n '1,30p' Packages/NotikaCore/Sources/NotikaCore/Protocols/TranscriptionEngine.swift
```

Erwartet:
```swift
import Foundation

public enum TranscriptionEngineID: String, Codable, Sendable, CaseIterable {
    case appleSpeechAnalyzer
    case whisperCpp
}

public enum AudioSource: Sendable {
    case file(URL)
    case samples([Float], sampleRate: Double)
}

public protocol TranscriptionEngine: AnyObject, Sendable {
    var id: TranscriptionEngineID { get }
    var supportsStreaming: Bool { get }

    func transcribe(
        audio: AudioSource,
        language: Language,
        hints: [String]
    ) async throws -> Transcript
}
```

- [ ] **Step 2: Protokoll + Default-Extension bearbeiten**

Edit `Packages/NotikaCore/Sources/NotikaCore/Protocols/TranscriptionEngine.swift`:

Alt:
```swift
public protocol TranscriptionEngine: AnyObject, Sendable {
    var id: TranscriptionEngineID { get }
    var supportsStreaming: Bool { get }

    func transcribe(
        audio: AudioSource,
        language: Language,
        hints: [String]
    ) async throws -> Transcript
}
```

Neu:
```swift
public protocol TranscriptionEngine: AnyObject, Sendable {
    var id: TranscriptionEngineID { get }
    var supportsStreaming: Bool { get }

    func transcribe(
        audio: AudioSource,
        language: Language,
        hints: [String]
    ) async throws -> Transcript

    /// Optionaler Pre-Warm: Modell laden / CoreML-Graph kompilieren,
    /// damit das erste echte `transcribe` ohne Cold-Start läuft.
    /// Default-Implementierung ist no-op — Engines ohne Cold-Start (z. B. Apple)
    /// müssen nichts überschreiben.
    func preWarm() async
}

public extension TranscriptionEngine {
    func preWarm() async { }
}
```

- [ ] **Step 3: Tests der NotikaCore-Package laufen lassen**

Run:
```bash
cd Packages/NotikaCore && swift test 2>&1 | tail -10
```

Erwartet: Alle Tests grün (keine Änderung an bestehenden Interfaces, nur Additive).

- [ ] **Step 4: Commit**

```bash
cd ../..
git add Packages/NotikaCore/Sources/NotikaCore/Protocols/TranscriptionEngine.swift
git commit -m "$(cat <<'EOF'
Whisper-PreWarm #1: TranscriptionEngine.preWarm() mit no-op Default

Protocol-Erweiterung für Engines mit Cold-Start. Default-Implementierung ist
no-op, so dass Apple SpeechAnalyzer nichts ändern muss.

Spec: docs/superpowers/specs/2026-04-19-notika-whisper-prewarm-design.md
EOF
)"
```

---

### Task 2: `WhisperKitEngine.preWarm()` + `prewarm: true`

**Files:**
- Modify: `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift`

- [ ] **Step 1: `prewarm: true` im `WhisperKit()`-Init**

Edit `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift`, Methode `loadPipeIfNeeded()`:

Alt:
```swift
            let pipe = try await WhisperKit(
                modelFolder: modelDir.path,
                verbose: false,
                logLevel: .error,
                prewarm: false,
                load: true,
                download: false
            )
```

Neu:
```swift
            let pipe = try await WhisperKit(
                modelFolder: modelDir.path,
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: false
            )
```

- [ ] **Step 2: `preWarm()`-Methode hinzufügen**

Edit `Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift`.
Nach der schließenden `}` von `transcribe(...)` und vor `loadPipeIfNeeded()`:

```swift
    public func preWarm() async {
        do {
            _ = try await loadPipeIfNeeded()
            logger.info("Whisper Pre-Warm OK: \(self.modelID.rawValue, privacy: .public)")
        } catch {
            logger.warning("Whisper Pre-Warm fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }
```

- [ ] **Step 3: Tests laufen lassen**

Run:
```bash
cd Packages/NotikaWhisper && swift test 2>&1 | tail -10
```

Erwartet: alle Tests grün. Falls Tests zu lange laufen (WhisperKit-Modell-Load),
Timeout auf 180 s setzen:

```bash
cd Packages/NotikaWhisper && swift test --parallel 2>&1 | tail -20
```

- [ ] **Step 4: Commit**

```bash
cd ../..
git add Packages/NotikaWhisper/Sources/NotikaWhisper/WhisperKitEngine.swift
git commit -m "$(cat <<'EOF'
Whisper-PreWarm #2: WhisperKitEngine.preWarm() + prewarm:true im Init

preWarm() ruft den bestehenden loadPipeIfNeeded() und erlaubt Caller
(AppDelegate/Coordinator), das Modell im Hintergrund zu laden. Zusätzlich
wird der WhisperKit-Init-Parameter prewarm:false → true gesetzt, damit
beim Load auch CoreML-Graph-Compile passiert.

Spec: docs/superpowers/specs/2026-04-19-notika-whisper-prewarm-design.md
EOF
)"
```

---

### Task 3: `DictationCoordinator.preWarm()` + AppDelegate-Trigger

**Files:**
- Modify: `Notika/DictationCoordinator.swift` (neue Methode `preWarm()`)
- Modify: `Notika/AppDelegate.swift` (Task.detached in `applicationDidFinishLaunching`)

- [ ] **Step 1: `preWarm()` im Coordinator hinzufügen**

Edit `Notika/DictationCoordinator.swift`. Nach der bestehenden `start()`-Methode einfügen:

```swift
    /// Wärmt die aktuell konfigurierte STT-Engine vor, damit das erste
    /// Diktat nach App-Start keinen Cold-Start-Delay hat.
    /// Safe, um im Hintergrund aufgerufen zu werden (Task.detached).
    func preWarm() async {
        let engine = resolveTranscriptionEngine()
        let started = Date()
        await engine.preWarm()
        let elapsed = Date().timeIntervalSince(started)
        logger.info("⏱️ Pre-Warm: \(String(format: "%.2f", elapsed))s")
    }
```

- [ ] **Step 2: AppDelegate triggert Pre-Warm**

Edit `Notika/AppDelegate.swift`. In `applicationDidFinishLaunching(_:)`, direkt nach `coordinator.start()`:

Alt:
```swift
        // Hotkey- und Audio-Orchestrierung starten.
        coordinator.start()

        let hasCompleted = UserDefaults.standard.bool(forKey: "notika.hasCompletedOnboarding")
```

Neu:
```swift
        // Hotkey- und Audio-Orchestrierung starten.
        coordinator.start()

        // Whisper-Modell im Hintergrund vorwärmen, damit das erste Diktat
        // keinen Cold-Start-Delay hat. Läuft mit niedriger Priorität.
        Task.detached(priority: .utility) { [coordinator] in
            await coordinator.preWarm()
        }

        let hasCompleted = UserDefaults.standard.bool(forKey: "notika.hasCompletedOnboarding")
```

- [ ] **Step 3: Build prüfen**

Run:
```bash
xcodebuild -scheme Notika -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10
```

Erwartet: `** BUILD SUCCEEDED **`.

Falls Fehler `Capture of 'coordinator' with non-sendable type 'DictationCoordinator' in a `@Sendable` closure`:
→ `DictationCoordinator` ist `@MainActor`. Alternative: Methoden-Call nicht capturen, sondern MainActor-Hop:

```swift
Task.detached(priority: .utility) {
    await MainActor.run { [weak self] in
        Task { await self?.coordinator.preWarm() }
    }
}
```

Hinweis: Zuerst die einfache Variante versuchen. Nur bei Sendable-Fehler auf die Alternative wechseln.

- [ ] **Step 4: Commit**

```bash
git add Notika/DictationCoordinator.swift Notika/AppDelegate.swift
git commit -m "$(cat <<'EOF'
Whisper-PreWarm #3: Coordinator.preWarm() + AppDelegate-Trigger

coordinator.preWarm() löst resolveTranscriptionEngine() aus (Cache-Befüllung)
und ruft engine.preWarm() (Modell-Load). AppDelegate startet das als
Task.detached mit .utility-Priority direkt nach coordinator.start(), damit
UI-Launch nicht verzögert wird.

Spec: docs/superpowers/specs/2026-04-19-notika-whisper-prewarm-design.md
EOF
)"
```

---

### Task 4: Manueller Smoketest + Messung

**Files:** Keine Code-Änderung.

- [ ] **Step 1: Alte Instanz beenden, neu bauen und starten**

Run:
```bash
pkill -x Notika 2>/dev/null; sleep 1
xcodebuild -scheme Notika -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name Notika.app -path '*/Debug/*' -print -quit)
open "$APP_PATH"
```

- [ ] **Step 2: Log-Zeile für Pre-Warm verifizieren**

Binnen 10 Sekunden nach Start:

```bash
sleep 8 && /usr/bin/log show --last 30s --predicate 'subsystem == "com.notika.mac"' --info --style compact 2>&1 | grep -E "Pre-Warm|⏱️"
```

Erwartet: Eine Zeile mit `⏱️ Pre-Warm: X.XXs` (typisch 1-3 s).
Falls keine Zeile: Pre-Warm wurde nicht ausgelöst → Task.detached-Build
prüfen oder Coordinator-Initialisierung checken.

- [ ] **Step 3: Erstes Diktat nach Start messen**

User-Aktion:
1. Hotkey (Fn / Right-Cmd / Right-Option je nach Konfig) drücken
2. ~5 s Text diktieren, z. B. "Das ist ein Performance-Test für den Pre-Warm"
3. Hotkey loslassen, warten bis Text eingefügt ist

Dann:
```bash
/usr/bin/log show --last 1m --predicate 'subsystem == "com.notika.mac"' --info --style compact 2>&1 | grep -E "⏱️"
```

Erwartet:
- `⏱️ Pre-Warm: X.XXs` (vom Start)
- `⏱️ STT: < 1.0s` (vorher 3.25 s)
- `⏱️ Total: ≤ 2.0s` (vorher 5.16 s)

Falls STT immer noch > 2 s: Pre-Warm lief zu spät oder `prewarm: true` reicht
nicht aus. In dem Fall Dummy-Audio-Inferenz als Task 5 planen.

- [ ] **Step 4: Zweites Diktat — keine Regression**

User diktiert noch einmal. Erwartet: gleiche Latenz wie vorher warm (~1.5 s),
kein Unterschied.

- [ ] **Step 5: Status-Update in der Memory**

Agent editiert `/Users/michaeldymny/.claude/projects/-Users-michaeldymny-Desktop-claude-code-projekte-2604-sag-macos/memory/phase_1b_backlog.md`:

Im Abschnitt „Phase 1b-Perf — Performance-Quick-Wins" einen neuen Bullet ergänzen:

```
- `<sha>` Whisper-Pre-Warm beim App-Start (Cold-Start 3.25s STT → <1.0s)
```

Und in `fortsetzungspunkt.md` den Abschnitt zur Performance aktualisieren.

- [ ] **Step 6: Push auf GitHub (erst nach User-OK)**

Agent fragt User.

Run nach Freigabe:
```bash
git push origin main
```

---

## Self-Review

**1. Spec coverage:**
- Protocol-Erweiterung + Default-Impl → Task 1 ✔
- WhisperKitEngine.preWarm() + prewarm:true → Task 2 ✔
- Coordinator.preWarm() → Task 3 ✔
- AppDelegate-Task.detached → Task 3 Step 2 ✔
- Smoketest + Messung → Task 4 ✔

**2. Placeholder scan:** Keine TBD/TODO. Alle Code-Blöcke vollständig.

**3. Type consistency:**
- `preWarm()`-Signatur identisch in Protocol, Default-Extension, WhisperKitEngine ✔
- `Task.detached` + `[coordinator]` Capture — potentielles Sendable-Problem dokumentiert, Fallback angegeben ✔
- `resolveTranscriptionEngine()` existiert bereits in Coordinator (private), wird von `preWarm()` aufgerufen — ok, `preWarm()` ist im selben File ✔

Plan ist konsistent mit dem Spec.
