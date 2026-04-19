# Phase 1b-6: Modifier-only Hotkeys + Trigger-Mode-UI — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Notika-Diktate per reinem Modifier (Fn / Right-⌘ / Right-⌥) auslösen — parallel zu den bestehenden Tastenkombis — und pro Modus zwischen Push-to-Talk und Toggle umschalten.

**Architecture:** CGEventTap-basierter `ModifierHotkeyTap` läuft parallel zum bestehenden `KeyboardShortcuts`-Pfad. Pure State-Machine (`ModifierHotkeyTapState`) in NotikaMacOS entscheidet über Press/Release/Cancel — testbar ohne CGEvent. Konfiguration pro Modus in `SettingsStore` via `ModeHotkeyConfig`, persistiert als JSON in UserDefaults. UI integriert 3 Spalten (Tastenkombi · Modifier-Trigger · Auslöser) pro Modus in den Kurzbefehle-Tab.

**Tech Stack:** Swift 6, SwiftUI, CoreGraphics (CGEventTap), NotikaCore, NotikaMacOS, `sindresorhus/KeyboardShortcuts` (weiter als Fallback-Pfad).

**Spec:** `docs/superpowers/specs/2026-04-19-notika-phase-1b-6-modifier-only-hotkeys-design.md`

---

## File Structure

**Neue Dateien:**
- `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/TriggerMode.swift` — Enum PTT/Toggle (gehoben aus NotikaMacOS)
- `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/ModifierTrigger.swift` — Enum für Fn/RightCmd/RightOption/None
- `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/ModeHotkeyConfig.swift` — Struct mit triggerMode + modifierTrigger
- `Packages/NotikaCore/Tests/NotikaCoreTests/ModeHotkeyConfigTests.swift` — Codable-Roundtrip
- `Packages/NotikaCore/Tests/NotikaCoreTests/ModifierTriggerTests.swift` — DisplayName-Tests
- `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/ModifierHotkeyTapState.swift` — Pure State-Machine
- `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/ModifierHotkeyTap.swift` — CGEventTap-Wrapper
- `Packages/NotikaMacOS/Tests/NotikaMacOSTests/ModifierHotkeyTapStateTests.swift` — 12+ Szenarien
- `docs/PHASE_1B_6_SMOKETEST.md` — Manueller Smoketest-Guide

**Geänderte Dateien:**
- `Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift` — 3 Config-Properties + Persist/Load
- `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/HotkeyManager.swift` — `TriggerMode` aus NotikaCore importieren, ModifierHotkeyTap integrieren
- `Notika/Settings/SettingsView.swift` — HotkeysTab mit 3 Spalten pro Modus
- `Notika/DictationCoordinator.swift` — TriggerMode pro Modus aus SettingsStore
- `docs/STATUS.md` — Phase-1b-6-Status

---

## Task 1: TriggerMode nach NotikaCore heben

**Files:**
- Create: `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/TriggerMode.swift`
- Modify: `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/HotkeyManager.swift` (Enum entfernen, Typealias)
- Modify: `Notika/DictationCoordinator.swift:31` (Import-Pfad)

- [ ] **Step 1: TriggerMode in NotikaCore anlegen**

Erstelle `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/TriggerMode.swift`:

```swift
import Foundation

public enum TriggerMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case pushToTalk
    case toggle

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pushToTalk: return "Halten (Push-to-Talk)"
        case .toggle:     return "Antippen (Toggle)"
        }
    }
}
```

- [ ] **Step 2: Typealias in NotikaMacOS.HotkeyManager hinterlegen**

In `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/HotkeyManager.swift` die `enum TriggerMode` (Zeilen 13-25) **entfernen** und durch einen Typealias ersetzen, damit bestehende Referenzen wie `HotkeyManager.TriggerMode` nicht brechen:

Alter Code (ersetzen):
```swift
    public enum TriggerMode: String, Codable, Sendable, CaseIterable, Identifiable {
        case pushToTalk
        case toggle

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .pushToTalk: return "Push-to-Talk (halten)"
            case .toggle:     return "Toggle (klick – klick)"
            }
        }
    }
```

Neuer Code (ersetzt den alten Block):
```swift
    public typealias TriggerMode = NotikaCore.TriggerMode
```

- [ ] **Step 3: Build-Check**

Run: `./scripts/build.sh`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Packages/NotikaCore/Sources/NotikaCore/Hotkeys/TriggerMode.swift Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/HotkeyManager.swift
git commit -m "Phase 1b-6 #1: TriggerMode nach NotikaCore gehoben

Typealias HotkeyManager.TriggerMode = NotikaCore.TriggerMode
hält bestehende Referenzen kompatibel. DisplayName auf
Mutter-Klartext umformuliert ('Halten' / 'Antippen')."
```

---

## Task 2: ModifierTrigger-Enum

**Files:**
- Create: `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/ModifierTrigger.swift`
- Create: `Packages/NotikaCore/Tests/NotikaCoreTests/ModifierTriggerTests.swift`

- [ ] **Step 1: Test schreiben (failing)**

Erstelle `Packages/NotikaCore/Tests/NotikaCoreTests/ModifierTriggerTests.swift`:

```swift
import XCTest
@testable import NotikaCore

final class ModifierTriggerTests: XCTestCase {
    func test_allCases_displayName_nonEmpty() {
        for trigger in ModifierTrigger.allCases {
            XCTAssertFalse(trigger.displayName.isEmpty, "\(trigger.rawValue) braucht displayName")
        }
    }

    func test_allCases_count_isFour() {
        XCTAssertEqual(ModifierTrigger.allCases.count, 4, "Erwartet: none, fn, rightCommand, rightOption")
    }

    func test_codable_roundtrip() throws {
        for trigger in ModifierTrigger.allCases {
            let data = try JSONEncoder().encode(trigger)
            let decoded = try JSONDecoder().decode(ModifierTrigger.self, from: data)
            XCTAssertEqual(trigger, decoded)
        }
    }
}
```

- [ ] **Step 2: Test läuft → fehlschlagen**

Run: `cd Packages/NotikaCore && swift test --filter ModifierTriggerTests 2>&1 | tail -15`
Expected: Compile-Fehler „cannot find 'ModifierTrigger' in scope"

- [ ] **Step 3: ModifierTrigger anlegen**

Erstelle `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/ModifierTrigger.swift`:

```swift
import Foundation

public enum ModifierTrigger: String, Codable, CaseIterable, Sendable {
    case none          = "none"
    case fn            = "fn"
    case rightCommand  = "rightCommand"
    case rightOption   = "rightOption"

    public var displayName: String {
        switch self {
        case .none:         return "Keiner"
        case .fn:           return "Fn-Taste"
        case .rightCommand: return "Rechte ⌘-Taste"
        case .rightOption:  return "Rechte ⌥-Taste"
        }
    }
}

extension ModifierTrigger: Identifiable {
    public var id: String { rawValue }
}
```

- [ ] **Step 4: Tests laufen lassen → grün**

Run: `cd Packages/NotikaCore && swift test --filter ModifierTriggerTests 2>&1 | tail -10`
Expected: `Test Suite 'ModifierTriggerTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Packages/NotikaCore/Sources/NotikaCore/Hotkeys/ModifierTrigger.swift Packages/NotikaCore/Tests/NotikaCoreTests/ModifierTriggerTests.swift
git commit -m "Phase 1b-6 #2: ModifierTrigger-Enum (none/fn/rightCommand/rightOption)

Mit displayName für Settings-UI und Codable für Persistierung.
3 Unit-Tests sichern Vollständigkeit + Roundtrip."
```

---

## Task 3: ModeHotkeyConfig-Struct

**Files:**
- Create: `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/ModeHotkeyConfig.swift`
- Create: `Packages/NotikaCore/Tests/NotikaCoreTests/ModeHotkeyConfigTests.swift`

- [ ] **Step 1: Test schreiben (failing)**

Erstelle `Packages/NotikaCore/Tests/NotikaCoreTests/ModeHotkeyConfigTests.swift`:

```swift
import XCTest
@testable import NotikaCore

final class ModeHotkeyConfigTests: XCTestCase {
    func test_defaultInit_noModifier_pushToTalk() {
        let config = ModeHotkeyConfig()
        XCTAssertEqual(config.modifierTrigger, .none)
        XCTAssertEqual(config.triggerMode, .pushToTalk)
    }

    func test_codable_roundtrip() throws {
        let original = ModeHotkeyConfig(modifierTrigger: .fn, triggerMode: .toggle)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ModeHotkeyConfig.self, from: data)
        XCTAssertEqual(decoded.modifierTrigger, .fn)
        XCTAssertEqual(decoded.triggerMode, .toggle)
    }

    func test_equatable() {
        let a = ModeHotkeyConfig(modifierTrigger: .rightOption, triggerMode: .pushToTalk)
        let b = ModeHotkeyConfig(modifierTrigger: .rightOption, triggerMode: .pushToTalk)
        let c = ModeHotkeyConfig(modifierTrigger: .rightCommand, triggerMode: .pushToTalk)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
```

- [ ] **Step 2: Test läuft → fehlschlagen**

Run: `cd Packages/NotikaCore && swift test --filter ModeHotkeyConfigTests 2>&1 | tail -10`
Expected: `cannot find 'ModeHotkeyConfig' in scope`

- [ ] **Step 3: ModeHotkeyConfig implementieren**

Erstelle `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/ModeHotkeyConfig.swift`:

```swift
import Foundation

public struct ModeHotkeyConfig: Codable, Sendable, Equatable {
    public var modifierTrigger: ModifierTrigger
    public var triggerMode: TriggerMode

    public init(
        modifierTrigger: ModifierTrigger = .none,
        triggerMode: TriggerMode = .pushToTalk
    ) {
        self.modifierTrigger = modifierTrigger
        self.triggerMode = triggerMode
    }
}
```

- [ ] **Step 4: Tests laufen lassen → grün**

Run: `cd Packages/NotikaCore && swift test --filter ModeHotkeyConfigTests 2>&1 | tail -10`
Expected: `Test Suite 'ModeHotkeyConfigTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Packages/NotikaCore/Sources/NotikaCore/Hotkeys/ModeHotkeyConfig.swift Packages/NotikaCore/Tests/NotikaCoreTests/ModeHotkeyConfigTests.swift
git commit -m "Phase 1b-6 #3: ModeHotkeyConfig (modifierTrigger + triggerMode)

Default: .none / .pushToTalk. 3 Tests für Defaults, Codable
und Equatable."
```

---

## Task 4: SettingsStore erweitern

**Files:**
- Modify: `Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift`
- Modify: `Packages/NotikaCore/Tests/NotikaCoreTests/SettingsStoreTests.swift` (falls vorhanden — sonst neue Datei)

- [ ] **Step 1: Aktuellen SettingsStore anschauen**

Run: `grep -n "public var\|private let defaults\|private enum Keys" Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift | head -30`

Merke dir: Wo ist `Keys` (enum), wo ist `defaults: UserDefaults`, wo ist das `init()`, welches Pattern wird für Persist/Load genutzt (typischerweise `didSet` auf den Properties)?

- [ ] **Step 2: Neuen Keys-Bereich ergänzen**

Im `enum Keys` (oder `private enum Keys` / `private enum DefaultsKey`) innerhalb von `SettingsStore` 3 neue Konstanten ergänzen:

```swift
static let hotkeyConfigLiteral = "notika.hotkey.config.literal"
static let hotkeyConfigSocial  = "notika.hotkey.config.social"
static let hotkeyConfigFormal  = "notika.hotkey.config.formal"
```

- [ ] **Step 3: Helper-Methoden für Persist/Load ergänzen**

Innerhalb der `SettingsStore`-Klasse, bei den anderen Persist-Helpern, diese Methoden ergänzen:

```swift
private func loadHotkeyConfig(key: String) -> ModeHotkeyConfig {
    guard let data = defaults.data(forKey: key),
          let config = try? JSONDecoder().decode(ModeHotkeyConfig.self, from: data) else {
        return ModeHotkeyConfig()
    }
    return config
}

private func saveHotkeyConfig(_ config: ModeHotkeyConfig, key: String) {
    guard let data = try? JSONEncoder().encode(config) else { return }
    defaults.set(data, forKey: key)
}
```

- [ ] **Step 4: 3 @Observable-Properties ergänzen**

Nach den bestehenden Properties im `SettingsStore` — jeweils mit didSet-Persist — 3 neue Properties ergänzen. Der exakte `@Observable`-Stil hängt vom Projekt ab; schau wie z.B. `sttEngineChoice` gebaut ist und folge demselben Muster. Beispiel-Skeleton:

```swift
public var hotkeyConfigLiteral: ModeHotkeyConfig {
    didSet { saveHotkeyConfig(hotkeyConfigLiteral, key: Keys.hotkeyConfigLiteral) }
}
public var hotkeyConfigSocial: ModeHotkeyConfig {
    didSet { saveHotkeyConfig(hotkeyConfigSocial, key: Keys.hotkeyConfigSocial) }
}
public var hotkeyConfigFormal: ModeHotkeyConfig {
    didSet { saveHotkeyConfig(hotkeyConfigFormal, key: Keys.hotkeyConfigFormal) }
}
```

Im `init()` danach:
```swift
self.hotkeyConfigLiteral = loadHotkeyConfig(key: Keys.hotkeyConfigLiteral)
self.hotkeyConfigSocial  = loadHotkeyConfig(key: Keys.hotkeyConfigSocial)
self.hotkeyConfigFormal  = loadHotkeyConfig(key: Keys.hotkeyConfigFormal)
```

- [ ] **Step 5: Convenience-Lookup per DictationMode**

Ebenfalls in `SettingsStore`:

```swift
public func hotkeyConfig(for mode: DictationMode) -> ModeHotkeyConfig {
    switch mode {
    case .literal: return hotkeyConfigLiteral
    case .social:  return hotkeyConfigSocial
    case .formal:  return hotkeyConfigFormal
    }
}

public func setHotkeyConfig(_ config: ModeHotkeyConfig, for mode: DictationMode) {
    switch mode {
    case .literal: hotkeyConfigLiteral = config
    case .social:  hotkeyConfigSocial  = config
    case .formal:  hotkeyConfigFormal  = config
    }
}
```

- [ ] **Step 6: Test — Persistierung via in-memory UserDefaults**

Erstelle (oder erweitere) `Packages/NotikaCore/Tests/NotikaCoreTests/SettingsStoreHotkeyConfigTests.swift`:

```swift
import XCTest
@testable import NotikaCore

final class SettingsStoreHotkeyConfigTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "notika.tests.hotkey"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func test_defaults_areNoneAndPushToTalk() {
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.hotkeyConfigLiteral.modifierTrigger, .none)
        XCTAssertEqual(store.hotkeyConfigLiteral.triggerMode, .pushToTalk)
    }

    func test_set_persists_acrossInstances() {
        let storeA = SettingsStore(defaults: defaults)
        storeA.setHotkeyConfig(
            ModeHotkeyConfig(modifierTrigger: .fn, triggerMode: .toggle),
            for: .literal
        )
        let storeB = SettingsStore(defaults: defaults)
        XCTAssertEqual(storeB.hotkeyConfigLiteral.modifierTrigger, .fn)
        XCTAssertEqual(storeB.hotkeyConfigLiteral.triggerMode, .toggle)
    }

    func test_modeLookup_correctChannel() {
        let store = SettingsStore(defaults: defaults)
        store.setHotkeyConfig(ModeHotkeyConfig(modifierTrigger: .rightCommand, triggerMode: .pushToTalk), for: .formal)
        XCTAssertEqual(store.hotkeyConfig(for: .formal).modifierTrigger, .rightCommand)
        XCTAssertEqual(store.hotkeyConfig(for: .literal).modifierTrigger, .none)
    }
}
```

**Hinweis:** Wenn `SettingsStore.init()` aktuell kein `defaults`-Parameter hat, mach den Init overloaded: das Haupt-init bleibt wie es ist (nutzt `.standard`), und ein zusätzlicher `init(defaults: UserDefaults)` für Tests. Falls der Store bereits so gebaut ist, ist nichts zu tun.

- [ ] **Step 7: Tests laufen lassen**

Run: `cd Packages/NotikaCore && swift test --filter SettingsStoreHotkeyConfigTests 2>&1 | tail -20`
Expected: alle 3 Tests passed

- [ ] **Step 8: Commit**

```bash
git add Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift Packages/NotikaCore/Tests/NotikaCoreTests/SettingsStoreHotkeyConfigTests.swift
git commit -m "Phase 1b-6 #4: SettingsStore.hotkeyConfig(for:) + Persist in UserDefaults

3 Properties (Literal/Social/Formal) als ModeHotkeyConfig,
JSON-encoded unter notika.hotkey.config.<mode>. Lookup per
DictationMode-Enum. 3 Tests: Defaults, Cross-Instance-Persist,
Kanal-Separation."
```

---

## Task 5: ModifierHotkeyTapState (pure State-Machine) + Tests (TDD)

Das ist das Kernstück. Pure Swift-Logik ohne CoreGraphics-Abhängigkeit, damit sie unit-testbar bleibt.

**Files:**
- Create: `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/ModifierHotkeyTapState.swift`
- Create: `Packages/NotikaMacOS/Tests/NotikaMacOSTests/ModifierHotkeyTapStateTests.swift`

- [ ] **Step 1: State-Types und Event-Types definieren**

Erstelle `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/ModifierHotkeyTapState.swift`:

```swift
import Foundation
import NotikaCore

/// Pure State-Machine für CGEventTap-basierte Modifier-Erkennung.
/// Keine CG-Abhängigkeiten — rein testbar.
public struct ModifierHotkeyTapState: Sendable, Equatable {

    /// Physical-Input-Event aus dem CGEventTap-Callback,
    /// abstrahiert von CGEvent für die Testbarkeit.
    public enum Input: Sendable, Equatable {
        /// Modifier-Flags haben sich geändert. `flags` ist der aktuelle kombinierte Zustand.
        /// `keyCode` identifiziert welcher Modifier geklickt wurde (54=Right-Cmd, 61=Right-Option etc.).
        case flagsChanged(flags: Flags, keyCode: Int)
        /// Eine Nicht-Modifier-Taste wurde gedrückt (Cancel-Signal).
        case keyDown
        /// Hold-Schwelle (z.B. 100 ms) abgelaufen.
        case holdThresholdReached
    }

    /// Effekt, den der Tap nach außen schiebt.
    public enum Effect: Sendable, Equatable {
        case pressed
        case released
        case armingStarted    // Timer starten
        case armingCancelled  // Timer abbrechen
    }

    /// Abstrahierte Modifier-Flags (entsprechen NSEvent.ModifierFlags / CGEventFlags).
    public struct Flags: OptionSet, Sendable, Equatable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        public static let fn       = Flags(rawValue: 1 << 0)
        public static let command  = Flags(rawValue: 1 << 1)
        public static let option   = Flags(rawValue: 1 << 2)
        public static let shift    = Flags(rawValue: 1 << 3)
        public static let control  = Flags(rawValue: 1 << 4)
        public static let capsLock = Flags(rawValue: 1 << 5)
    }

    enum Phase: Sendable, Equatable {
        case idle
        case arming            // Modifier gedrückt, Hold-Schwelle nicht erreicht
        case triggered         // .pressed ausgelöst, Modifier noch gedrückt
    }

    // Konfiguration (immutable nach Init)
    public let configuredTrigger: ModifierTrigger

    // Laufzeit-State
    var phase: Phase = .idle

    public init(configuredTrigger: ModifierTrigger) {
        self.configuredTrigger = configuredTrigger
    }

    /// Verarbeitet ein Input-Event und liefert den resultierenden Effect (oder nil, wenn nichts zu tun ist).
    /// Mutiert den State.
    public mutating func handle(_ input: Input) -> Effect? {
        // Wenn kein Trigger konfiguriert: alles ignorieren
        guard configuredTrigger != .none else { return nil }

        switch (phase, input) {
        case (.idle, .flagsChanged(let flags, let keyCode)):
            if matchesConfiguredTrigger(flags: flags, keyCode: keyCode) {
                phase = .arming
                return .armingStarted
            }
            return nil

        case (.arming, .flagsChanged(let flags, _)):
            // Modifier wieder losgelassen (oder andere Modifier dazu) → Cancel
            if !matchesConfiguredTrigger(flags: flags, keyCode: 0) {
                phase = .idle
                return .armingCancelled
            }
            return nil

        case (.arming, .keyDown):
            // Andere Taste während Arming-Phase → Cancel
            phase = .idle
            return .armingCancelled

        case (.arming, .holdThresholdReached):
            phase = .triggered
            return .pressed

        case (.triggered, .flagsChanged(let flags, _)):
            // Modifier losgelassen → Release
            if !matchesConfiguredTrigger(flags: flags, keyCode: 0) {
                phase = .idle
                return .released
            }
            return nil

        case (.triggered, .keyDown):
            // Andere Taste während aktiver Aufnahme → auch Release (Cancel mid-flight)
            phase = .idle
            return .released

        default:
            return nil
        }
    }

    /// Entscheidet, ob die aktuellen Flags exakt dem konfigurierten Trigger entsprechen
    /// (keine anderen Modifier, und bei Right-Cmd/Right-Option auch der korrekte keyCode).
    private func matchesConfiguredTrigger(flags: Flags, keyCode: Int) -> Bool {
        switch configuredTrigger {
        case .none:
            return false

        case .fn:
            // Nur Fn, nichts anderes
            return flags == .fn

        case .rightCommand:
            // Nur Cmd-Flag, und keyCode=54 (Right-Cmd)
            // Bei .flagsChanged mit Release (keyCode=0): nur prüfen dass Flag nicht gesetzt
            if keyCode == 0 {
                return flags.contains(.command) && flags == .command
            }
            return flags == .command && keyCode == 54

        case .rightOption:
            if keyCode == 0 {
                return flags.contains(.option) && flags == .option
            }
            return flags == .option && keyCode == 61
        }
    }
}
```

- [ ] **Step 2: Tests schreiben**

Erstelle `Packages/NotikaMacOS/Tests/NotikaMacOSTests/ModifierHotkeyTapStateTests.swift`:

```swift
import XCTest
@testable import NotikaMacOS
import NotikaCore

final class ModifierHotkeyTapStateTests: XCTestCase {

    // MARK: - Keine Konfiguration

    func test_noneTrigger_ignoresAllEvents() {
        var state = ModifierHotkeyTapState(configuredTrigger: .none)
        XCTAssertNil(state.handle(.flagsChanged(flags: .fn, keyCode: 63)))
        XCTAssertNil(state.handle(.keyDown))
        XCTAssertNil(state.handle(.holdThresholdReached))
    }

    // MARK: - Fn (keyCode 63)

    func test_fn_alone_triggersArming() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        let effect = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        XCTAssertEqual(effect, .armingStarted)
    }

    func test_fn_plusOtherModifier_noArming() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        let effect = state.handle(.flagsChanged(flags: [.fn, .command], keyCode: 63))
        XCTAssertNil(effect)
    }

    func test_fn_holdThresholdReached_firesPressed() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        let effect = state.handle(.holdThresholdReached)
        XCTAssertEqual(effect, .pressed)
    }

    func test_fn_releasedBeforeThreshold_cancels() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        let effect = state.handle(.flagsChanged(flags: [], keyCode: 63))
        XCTAssertEqual(effect, .armingCancelled)
    }

    func test_fn_triggered_thenReleased_firesReleased() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        _ = state.handle(.holdThresholdReached)
        let effect = state.handle(.flagsChanged(flags: [], keyCode: 63))
        XCTAssertEqual(effect, .released)
    }

    func test_fn_arming_thenKeyDown_cancels() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        let effect = state.handle(.keyDown)
        XCTAssertEqual(effect, .armingCancelled)
    }

    func test_fn_triggered_thenKeyDown_cancelsWithRelease() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        _ = state.handle(.holdThresholdReached)
        let effect = state.handle(.keyDown)
        XCTAssertEqual(effect, .released)
    }

    // MARK: - Right-Command (keyCode 54)

    func test_rightCommand_correctKeyCode_triggersArming() {
        var state = ModifierHotkeyTapState(configuredTrigger: .rightCommand)
        let effect = state.handle(.flagsChanged(flags: .command, keyCode: 54))
        XCTAssertEqual(effect, .armingStarted)
    }

    func test_leftCommand_wrongKeyCode_doesNotArm() {
        var state = ModifierHotkeyTapState(configuredTrigger: .rightCommand)
        // Left-Cmd = keyCode 55
        let effect = state.handle(.flagsChanged(flags: .command, keyCode: 55))
        XCTAssertNil(effect)
    }

    // MARK: - Right-Option (keyCode 61)

    func test_rightOption_correctKeyCode_triggersArming() {
        var state = ModifierHotkeyTapState(configuredTrigger: .rightOption)
        let effect = state.handle(.flagsChanged(flags: .option, keyCode: 61))
        XCTAssertEqual(effect, .armingStarted)
    }

    func test_bothRightCmdAndRightOption_noArming() {
        var state = ModifierHotkeyTapState(configuredTrigger: .rightOption)
        // Beide Flags gesetzt → nicht exklusiv Option
        let effect = state.handle(.flagsChanged(flags: [.command, .option], keyCode: 61))
        XCTAssertNil(effect)
    }

    // MARK: - State-Integrity

    func test_cannotFirePressedTwice_withoutRelease() {
        var state = ModifierHotkeyTapState(configuredTrigger: .fn)
        _ = state.handle(.flagsChanged(flags: .fn, keyCode: 63))
        let first = state.handle(.holdThresholdReached)
        XCTAssertEqual(first, .pressed)
        // Nach Triggered sollte ein weiteres holdThresholdReached nichts mehr tun
        let second = state.handle(.holdThresholdReached)
        XCTAssertNil(second)
    }
}
```

- [ ] **Step 3: Tests laufen**

Run: `cd Packages/NotikaMacOS && swift test --filter ModifierHotkeyTapStateTests 2>&1 | tail -25`
Expected: `Test Suite 'ModifierHotkeyTapStateTests' passed` mit 12 Tests.

Falls Tests fehlschlagen → State-Machine im Code anpassen, erneut laufen lassen, bis alle grün sind.

- [ ] **Step 4: Commit**

```bash
git add Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/ModifierHotkeyTapState.swift Packages/NotikaMacOS/Tests/NotikaMacOSTests/ModifierHotkeyTapStateTests.swift
git commit -m "Phase 1b-6 #5: ModifierHotkeyTapState (pure State-Machine) + 12 Tests

State-Machine ohne CoreGraphics-Abhängigkeit: idle → arming →
triggered. Exklusivitäts-Regel (genau der konfigurierte Modifier)
+ Cancel-Regel (Co-Key bricht ab). Right-vs-Left-Diskrimination
via keyCode (54/55 für Cmd, 61/60 für Option)."
```

---

## Task 6: ModifierHotkeyTap (CGEventTap-Wrapper)

**Files:**
- Create: `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/ModifierHotkeyTap.swift`

Dies ist der Integrationscode — nutzt den State-Machine aus Task 5, aber mit echtem CGEventTap.

- [ ] **Step 1: Datei anlegen**

Erstelle `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/ModifierHotkeyTap.swift`:

```swift
import AppKit
import CoreGraphics
import Foundation
import NotikaCore
import os

/// Wrapper um einen CGEventTap, der pure State-Machine-Logik aus
/// ModifierHotkeyTapState mit CoreGraphics-Events verheiratet.
@MainActor
public final class ModifierHotkeyTap {
    private let logger = Logger(subsystem: "com.notika.mac", category: "ModifierTap")

    /// Millisekunden, die ein Modifier gehalten werden muss, bevor Press feuert.
    public static let holdThresholdMillis: Int = 100

    /// Callback-Closure, die gerufen wird, wenn ein Modifier-Trigger vollständig ausgelöst hat.
    public typealias EventHandler = (DictationMode, ModifierHotkeyTapEvent) -> Void

    public enum StartError: Error {
        case accessibilityPermissionMissing
        case tapCreationFailed
    }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    /// Separate State-Machine pro konfiguriertem Trigger (max 3: Literal/Social/Formal).
    private var stateByMode: [DictationMode: ModifierHotkeyTapState] = [:]
    private var armingTasks: [DictationMode: Task<Void, Never>] = [:]

    private let handler: EventHandler

    public init(handler: @escaping EventHandler) {
        self.handler = handler
    }

    public func configure(configs: [DictationMode: ModeHotkeyConfig]) {
        // Alte Arming-Timer canceln
        for task in armingTasks.values { task.cancel() }
        armingTasks.removeAll()

        stateByMode.removeAll()
        for (mode, cfg) in configs where cfg.modifierTrigger != .none {
            stateByMode[mode] = ModifierHotkeyTapState(configuredTrigger: cfg.modifierTrigger)
        }
        logger.info("ModifierHotkeyTap konfiguriert: \(self.stateByMode.count, privacy: .public) aktive Modi")
    }

    public func start() throws {
        guard AXIsProcessTrusted() else {
            logger.warning("Accessibility-Permission fehlt — ModifierHotkeyTap.start abgebrochen")
            throw StartError.accessibilityPermissionMissing
        }

        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let this = Unmanaged<ModifierHotkeyTap>.fromOpaque(refcon).takeUnretainedValue()
                Task { @MainActor in
                    this.process(type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            throw StartError.tapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        logger.info("ModifierHotkeyTap gestartet")
    }

    public func stop() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
        }
        tap = nil
        runLoopSource = nil
        for task in armingTasks.values { task.cancel() }
        armingTasks.removeAll()
        logger.info("ModifierHotkeyTap gestoppt")
    }

    // MARK: - Event-Processing

    private func process(type: CGEventType, event: CGEvent) {
        let input: ModifierHotkeyTapState.Input
        switch type {
        case .flagsChanged:
            let flags = Self.translateFlags(event.flags)
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            input = .flagsChanged(flags: flags, keyCode: keyCode)
        case .keyDown:
            input = .keyDown
        default:
            return
        }

        // Alle konfigurierten State-Machines füttern (jeder Modifier-Trigger ist unabhängig)
        for mode in stateByMode.keys {
            guard var state = stateByMode[mode] else { continue }
            let effect = state.handle(input)
            stateByMode[mode] = state

            guard let effect else { continue }
            dispatch(effect: effect, for: mode)
        }
    }

    private func dispatch(effect: ModifierHotkeyTapState.Effect, for mode: DictationMode) {
        switch effect {
        case .armingStarted:
            let task = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(Self.holdThresholdMillis))
                if Task.isCancelled { return }
                guard let self else { return }
                guard var state = self.stateByMode[mode] else { return }
                if let nextEffect = state.handle(.holdThresholdReached) {
                    self.stateByMode[mode] = state
                    self.dispatch(effect: nextEffect, for: mode)
                }
            }
            armingTasks[mode] = task

        case .armingCancelled:
            armingTasks[mode]?.cancel()
            armingTasks[mode] = nil

        case .pressed:
            handler(mode, .pressed)

        case .released:
            armingTasks[mode]?.cancel()
            armingTasks[mode] = nil
            handler(mode, .released)
        }
    }

    // MARK: - CGEventFlags → State.Flags

    static func translateFlags(_ cg: CGEventFlags) -> ModifierHotkeyTapState.Flags {
        var result: ModifierHotkeyTapState.Flags = []
        if cg.contains(.maskSecondaryFn) { result.insert(.fn) }
        if cg.contains(.maskCommand)     { result.insert(.command) }
        if cg.contains(.maskAlternate)   { result.insert(.option) }
        if cg.contains(.maskShift)       { result.insert(.shift) }
        if cg.contains(.maskControl)     { result.insert(.control) }
        if cg.contains(.maskAlphaShift)  { result.insert(.capsLock) }
        return result
    }
}

public enum ModifierHotkeyTapEvent: Sendable, Equatable {
    case pressed
    case released
}
```

- [ ] **Step 2: Build-Check**

Run: `./scripts/build.sh 2>&1 | grep -E "error:|BUILD " | tail -5`
Expected: `** BUILD SUCCEEDED **`. Falls Compile-Fehler: lies den Fehler genau, vergleiche die CGEvent-API-Namen auf macOS 26 (sie ändern sich selten, sollte laufen).

- [ ] **Step 3: Commit**

```bash
git add Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/ModifierHotkeyTap.swift
git commit -m "Phase 1b-6 #6: ModifierHotkeyTap (CGEventTap-Wrapper)

Verbindet pure State-Machine mit echtem .cgSessionEventTap auf
.flagsChanged + .keyDown. Hold-Schwelle 100ms, Accessibility-
Permission wird geprüft. Separater Task pro Arming-Timer,
deterministic Cancel beim Released/KeyDown-Cancel-Event."
```

---

## Task 7: HotkeyManager integriert beide Pfade

**Files:**
- Modify: `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/HotkeyManager.swift`

- [ ] **Step 1: HotkeyManager um ModifierHotkeyTap ergänzen**

Ersetze den kompletten Inhalt von `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/HotkeyManager.swift` durch:

```swift
import Foundation
import KeyboardShortcuts
import NotikaCore
import os

public enum HotkeyEvent: Sendable, Equatable {
    case pressed(DictationMode)
    case released(DictationMode)
}

@MainActor
public final class HotkeyManager {
    public typealias TriggerMode = NotikaCore.TriggerMode

    private let logger = Logger(subsystem: "com.notika.mac", category: "Hotkeys")
    private let continuation: AsyncStream<HotkeyEvent>.Continuation
    public let events: AsyncStream<HotkeyEvent>

    private lazy var modifierTap: ModifierHotkeyTap = {
        ModifierHotkeyTap { [weak self] mode, event in
            guard let self else { return }
            switch event {
            case .pressed:  self.continuation.yield(.pressed(mode))
            case .released: self.continuation.yield(.released(mode))
            }
        }
    }()

    public init() {
        var cont: AsyncStream<HotkeyEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    public func start() {
        // Pfad A: KeyboardShortcuts-Library (bestehend)
        for mode in DictationMode.allCases {
            let name = HotkeyBinding.name(for: mode)
            KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
                self?.logger.info("Hotkey pressed: \(mode.shortName, privacy: .public)")
                self?.continuation.yield(.pressed(mode))
            }
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                self?.logger.info("Hotkey released: \(mode.shortName, privacy: .public)")
                self?.continuation.yield(.released(mode))
            }
        }
        logger.info("HotkeyManager gestartet (Pfad A aktiv)")
    }

    /// Konfiguriert den Modifier-Tap (Pfad B) mit den aktuellen Config-Werten und startet ihn.
    /// Kann mehrfach aufgerufen werden, wenn der User die Settings ändert.
    public func applyModifierConfigs(_ configs: [DictationMode: ModeHotkeyConfig]) {
        let anyActive = configs.values.contains { $0.modifierTrigger != .none }
        modifierTap.configure(configs: configs)

        if anyActive {
            do {
                try modifierTap.start()
                logger.info("ModifierHotkeyTap (Pfad B) aktiv")
            } catch ModifierHotkeyTap.StartError.accessibilityPermissionMissing {
                logger.warning("Pfad B inaktiv: Accessibility-Permission fehlt")
            } catch {
                logger.error("Pfad B Start fehlgeschlagen: \(String(describing: error), privacy: .public)")
            }
        } else {
            modifierTap.stop()
        }
    }

    public func stop() {
        for mode in DictationMode.allCases {
            KeyboardShortcuts.disable(HotkeyBinding.name(for: mode))
        }
        modifierTap.stop()
        continuation.finish()
    }
}
```

- [ ] **Step 2: Bestehende Tests prüfen**

Run: `cd Packages/NotikaMacOS && swift test 2>&1 | tail -10`
Expected: Alle bestehenden Tests (`NotikaMacOSTests` + `ModifierHotkeyTapStateTests`) passen.

- [ ] **Step 3: Build-Check**

Run: `./scripts/build.sh 2>&1 | grep -E "error:|BUILD " | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/HotkeyManager.swift
git commit -m "Phase 1b-6 #7: HotkeyManager verbindet beide Trigger-Pfade

applyModifierConfigs(_:) startet/stoppt den ModifierHotkeyTap
je nachdem ob mindestens ein Modus einen Trigger konfiguriert
hat. Events beider Pfade landen im selben AsyncStream."
```

---

## Task 8: UI — HotkeysTab mit 3 Spalten

**Files:**
- Modify: `Notika/Settings/SettingsView.swift` (HotkeysTab-Abschnitt um Zeile 46-72)

- [ ] **Step 1: Aktuellen HotkeysTab-Code lesen**

Run: `sed -n '40,90p' Notika/Settings/SettingsView.swift`

Merke dir die aktuelle Struktur (Form + KeyboardShortcuts.Recorder).

- [ ] **Step 2: HotkeysTab-View ersetzen**

Ersetze im File `Notika/Settings/SettingsView.swift` die gesamte HotkeysTab-View (die `struct HotkeysTab: View` oder der Abschnitt mit `KeyboardShortcuts.Recorder`) durch folgendes Layout. **Hinweis:** Die genauen Typ-Namen für den SettingsStore-Binding-Pattern musst du dir aus dem bestehenden Code ableiten (vermutlich `@Bindable var settings: SettingsStore` oder `@Environment(SettingsStore.self)`):

```swift
struct HotkeysTab: View {
    @Bindable var settings: SettingsStore
    let onConfigChange: () -> Void   // Coordinator soll applyModifierConfigs triggern

    var body: some View {
        Form {
            Section("Kurzbefehle pro Modus") {
                hotkeyRow(for: .literal, label: "📝 Literal")
                hotkeyRow(for: .social,  label: "💬 Social")
                hotkeyRow(for: .formal,  label: "✉️ Formal")
            }

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("**Halten** = drücken und sprechen, loslassen stoppt.")
                        Text("**Antippen** = einmal drücken zum Start, nochmal zum Beenden.")
                        Text("Tastenkombi und Modifier-Trigger sind beide aktiv — setze den Modifier-Trigger auf „Keiner", um nur die Tastenkombi zu nutzen.")
                    }
                    .font(.caption)
                } icon: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func hotkeyRow(for mode: DictationMode, label: String) -> some View {
        let configBinding = Binding<ModeHotkeyConfig>(
            get: { settings.hotkeyConfig(for: mode) },
            set: { newValue in
                settings.setHotkeyConfig(newValue, for: mode)
                onConfigChange()
            }
        )

        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).frame(width: 90, alignment: .leading)

            KeyboardShortcuts.Recorder(for: HotkeyBinding.name(for: mode))
                .frame(width: 180)

            Picker("", selection: Binding(
                get: { configBinding.wrappedValue.modifierTrigger },
                set: { configBinding.wrappedValue.modifierTrigger = $0 }
            )) {
                ForEach(ModifierTrigger.allCases) { trigger in
                    Text(trigger.displayName).tag(trigger)
                }
            }
            .labelsHidden()
            .frame(width: 160)

            Picker("", selection: Binding(
                get: { configBinding.wrappedValue.triggerMode },
                set: { configBinding.wrappedValue.triggerMode = $0 }
            )) {
                ForEach(TriggerMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 180)
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 3: Call-Site des HotkeysTab anpassen**

Im `SettingsView` (der parent) den Tab-Aufruf ergänzen um `onConfigChange`-Callback. Beispiel, wie es aussehen sollte (genaue Integration hängt vom bestehenden Code ab):

```swift
HotkeysTab(
    settings: settings,
    onConfigChange: { coordinator.refreshHotkeyConfigs() }
)
.tabItem { Label("Kurzbefehle", systemImage: "keyboard") }
```

Falls `coordinator` in der View nicht verfügbar ist, nutze NotificationCenter oder erweitere das Binding — schau wie bestehende Dependencies (z.B. WhisperModelStore, CostStore) an die Tabs durchgereicht werden.

- [ ] **Step 4: Build-Check (UI ist jetzt kompilierbar)**

Run: `./scripts/build.sh 2>&1 | grep -E "error:|BUILD " | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Notika/Settings/SettingsView.swift
git commit -m "Phase 1b-6 #8: HotkeysTab-UI mit 3 Spalten pro Modus

Zeile pro Modus: Tastenkombi-Recorder + Modifier-Trigger-Picker
+ Auslöser-Picker. Hilfetext im Mutter-Test-Format. Änderung
triggert via onConfigChange den Coordinator zum Reconfigure."
```

---

## Task 9: DictationCoordinator nutzt Config aus SettingsStore

**Files:**
- Modify: `Notika/DictationCoordinator.swift`

- [ ] **Step 1: Coordinator um `refreshHotkeyConfigs()` erweitern**

In `Notika/DictationCoordinator.swift` innerhalb von `class DictationCoordinator`:

Direkt nach `start()` (nach Zeile 71) einfügen:

```swift
/// Liest die aktuellen Hotkey-Configs aus dem SettingsStore und wendet
/// sie auf den HotkeyManager an. Wird vom HotkeysTab nach Änderungen gerufen.
func refreshHotkeyConfigs() {
    var configs: [DictationMode: ModeHotkeyConfig] = [:]
    for mode in DictationMode.allCases {
        configs[mode] = settings.hotkeyConfig(for: mode)
    }
    hotkeyManager.applyModifierConfigs(configs)
    logger.info("Hotkey-Configs aktualisiert")
}
```

- [ ] **Step 2: `start()` erweitern, damit beim App-Start konfiguriert wird**

Ersetze in `Notika/DictationCoordinator.swift` die bestehende `start()`-Methode durch:

```swift
func start() {
    hotkeyManager.start()
    refreshHotkeyConfigs()   // Pfad B initial konfigurieren
    hotkeyTask = Task { @MainActor [weak self] in
        guard let self else { return }
        for await event in self.hotkeyManager.events {
            self.handle(event)
        }
    }
    logger.info("DictationCoordinator gestartet")
}
```

- [ ] **Step 3: handle() nutzt pro-Modus-TriggerMode statt globaler Variable**

Ersetze die bestehende `handle(_:)`-Methode (ca. Zeile 82-89) durch:

```swift
private func handle(_ event: HotkeyEvent) {
    let mode: DictationMode
    switch event {
    case .pressed(let m), .released(let m): mode = m
    }
    let triggerMode = settings.hotkeyConfig(for: mode).triggerMode

    switch triggerMode {
    case .pushToTalk:
        handlePushToTalk(event)
    case .toggle:
        handleToggle(event)
    }
}
```

Lösche den nicht mehr benötigten Property `private var triggerMode: HotkeyManager.TriggerMode = .pushToTalk` (die Zeile direkt nach `pipelineTask`).

- [ ] **Step 4: Build-Check**

Run: `./scripts/build.sh 2>&1 | grep -E "error:|BUILD " | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Notika/DictationCoordinator.swift
git commit -m "Phase 1b-6 #9: Coordinator nutzt TriggerMode pro Modus aus Settings

refreshHotkeyConfigs() wird beim Start + bei UI-Änderungen
aufgerufen. handle() liest jetzt pro Event den korrekten
TriggerMode aus dem SettingsStore."
```

---

## Task 10: Accessibility-Banner im HotkeysTab

**Files:**
- Modify: `Notika/Settings/SettingsView.swift` (HotkeysTab)

- [ ] **Step 1: Banner-View ergänzen**

Am Anfang der `body`-View von `HotkeysTab`, direkt vor dem ersten Section, einfügen:

```swift
if !AXIsProcessTrusted() {
    Section {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Bedienungshilfen nicht aktiv")
                    .font(.headline)
                Text("Damit Modifier-Trigger (Fn / Right-⌘ / Right-⌥) funktionieren, musst du Notika in den Systemeinstellungen unter **Datenschutz & Sicherheit → Bedienungshilfen** aktivieren. Die klassischen Tastenkombis funktionieren auch ohne.")
                    .font(.caption)
                Button("Systemeinstellungen öffnen") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2: Import sicherstellen**

Im Header von `Notika/Settings/SettingsView.swift` muss `import AppKit` oder `import SwiftUI` mit AppKit-Interop vorhanden sein (AXIsProcessTrusted kommt aus ApplicationServices). Falls der Import fehlt, ergänze:

```swift
import ApplicationServices
```

- [ ] **Step 3: Build-Check**

Run: `./scripts/build.sh 2>&1 | grep -E "error:|BUILD " | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Notika/Settings/SettingsView.swift
git commit -m "Phase 1b-6 #10: Accessibility-Warnbanner im HotkeysTab

Zeigt nur wenn AXIsProcessTrusted() == false. Erklärt dass
nur Modifier-Trigger betroffen sind (klassische Shortcuts
funktionieren weiter). Button öffnet direkten Permission-Pane."
```

---

## Task 11: Smoketest-Dokumentation

**Files:**
- Create: `docs/PHASE_1B_6_SMOKETEST.md`

- [ ] **Step 1: Smoketest-Guide schreiben**

Erstelle `docs/PHASE_1B_6_SMOKETEST.md`:

```markdown
# Phase 1b-6 Smoketest — Modifier-only Hotkeys

**Voraussetzung:** App auf aktuellem `main`-Build, Accessibility-Permission aktiv.

## Setup
1. Öffne Notika → Einstellungen → Kurzbefehle-Tab
2. Konfiguriere:
   - **Literal:** Modifier-Trigger = „Fn-Taste", Auslöser = „Halten"
   - **Social:** Modifier-Trigger = „Rechte ⌘-Taste", Auslöser = „Antippen"
   - **Formal:** Modifier-Trigger = „Rechte ⌥-Taste", Auslöser = „Halten"

## Szenarien

### 1. Fn halten (Literal, PTT)
- Fokus auf ein beliebiges Textfeld
- Fn-Taste drücken und halten → Overlay „Aufnahme Literal"
- Sprich ein paar Wörter
- Fn loslassen → Transkript erscheint im Textfeld
- **Erwartet:** OK

### 2. Right-⌘ antippen (Social, Toggle)
- Right-⌘ einmal kurz drücken → Overlay „Aufnahme Social"
- Sprich ein paar Wörter
- Right-⌘ nochmal kurz drücken → Transkript erscheint
- **Erwartet:** OK

### 3. Right-⌥ halten (Formal, PTT)
- Right-⌥ drücken und halten, sprechen, loslassen
- **Erwartet:** Transkript mit formeller Post-Processing-Variante

### 4. Klassischer Shortcut funktioniert parallel
- Drücke den Tastenkombi-Shortcut für Literal (z.B. ⌘⌥1)
- **Erwartet:** Aufnahme startet wie immer — beide Wege funktionieren

### 5. Fn + A (Cancel-Regel)
- Fn drücken und halten
- Innerhalb von 1 Sekunde die Taste A mit dazu drücken
- **Erwartet:** Kein Overlay, keine Aufnahme (Fn + A = System-Shortcut, nicht unser Trigger)

### 6. Hold-Schwelle (100 ms)
- Fn sehr kurz antippen (<100 ms)
- **Erwartet:** Keine Aufnahme (unter Schwelle)
- Fn länger halten (>150 ms) → Aufnahme startet

### 7. Accessibility-Permission widerrufen
- Notika beenden
- System-Einstellungen → Datenschutz → Bedienungshilfen → Notika deaktivieren
- Notika neu starten → Kurzbefehle-Tab öffnen
- **Erwartet:** Warnbanner sichtbar, klassische Shortcuts (⌘⌥1/2/3) funktionieren weiter, Modifier-Trigger **nicht**
- Permission wieder aktivieren, App neu starten → Modifier-Trigger funktionieren wieder

### 8. Live-Config-Wechsel
- In Kurzbefehle-Tab: Literal-Modifier von „Fn" auf „Keiner" setzen
- Fn halten → **Erwartet:** keine Aufnahme mehr (Config wirkt sofort)
- Literal-Modifier zurück auf „Fn"
- Fn halten → **Erwartet:** Aufnahme startet wieder

## Bekannte Einschränkungen v1
- Hold-Schwelle fix auf 100 ms (nicht konfigurierbar)
- Linke Cmd/Option werden bewusst ignoriert (System-Konflikte)
- Fn-Erkennung ist auf eingebauten Apple-Tastaturen getestet — bei externen kann `.function`-Flag fehlen
```

- [ ] **Step 2: STATUS.md updaten**

In `docs/STATUS.md` die Phase-Status-Zeile für 1b-6 aktualisieren (von „Nächster Schritt" auf „FERTIG, Smoketest offen"). Lies vorher die Datei, um den bestehenden Ton zu treffen.

Run: `cat docs/STATUS.md | head -30`

Dann Edit-Schritte auf der relevanten Zeile.

- [ ] **Step 3: Commit**

```bash
git add docs/PHASE_1B_6_SMOKETEST.md docs/STATUS.md
git commit -m "Phase 1b-6 #11: Smoketest-Doku + STATUS.md-Update

8 Smoketest-Szenarien (3× Modifier × PTT/Toggle, klassischer
Parallelpfad, Cancel-Regel, Hold-Schwelle, Permission-Fallback,
Live-Config-Wechsel)."
```

---

## Task 12: Final Build + End-of-Plan-Checks

**Files:** keine

- [ ] **Step 1: Kompletter Build**

Run: `./scripts/build.sh 2>&1 | tail -8`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Alle Tests**

Run: `cd Packages/NotikaCore && swift test 2>&1 | tail -5`
Run: `cd ../NotikaMacOS && swift test 2>&1 | tail -5`
Run: `cd ../NotikaWhisper && swift test 2>&1 | tail -5`
Run: `cd ../NotikaDictionary && swift test 2>&1 | tail -5`
Run: `cd ../NotikaPostProcessing && swift test 2>&1 | tail -5`

Expected: Alle Test-Suites grün, **mindestens 106 Tests** (94 Baseline + 12 neue aus Task 5 + 3 aus Task 3 + 3 aus Task 2 + 3 aus Task 4).

- [ ] **Step 3: Git-Log-Zusammenfassung**

Run: `git log --oneline 459c9b9..HEAD`
Expected: 11 neue Commits `Phase 1b-6 #1` bis `#11`.

- [ ] **Step 4: README.md kurz erwähnen (optional)**

Wenn README einen Features-Abschnitt hat, in `## Hotkeys` ergänzen:
„- Modifier-only-Trigger (Fn / Right-⌘ / Right-⌥) als Alternative zu klassischen Tastenkombis"

- [ ] **Step 5: Final Commit**

```bash
git add -A
git commit -m "Phase 1b-6 #12: Build + Tests grün, Plan abgeschlossen

Modifier-only Hotkeys + Trigger-Mode-UI fertig implementiert.
Smoketest durch den User steht aus."
```

---

## Completion Criteria

- [ ] Alle 12 Tasks abgeschlossen, jeder mit eigenem Commit
- [ ] Build succeeded ohne Warnings in neuen Files
- [ ] Alle Tests grün (Baseline 94 + 21 neue = mindestens 115)
- [ ] Smoketest-Doku liegt unter `docs/PHASE_1B_6_SMOKETEST.md`
- [ ] User kann den Smoketest am Rechner durchführen

## Risiken während der Implementation

- **SettingsStore-Pattern weicht ab:** Task 4 baut auf Vermutungen über `@Observable`-Stil. Wenn der bestehende Code anders aussieht, Task-4-Code entsprechend anpassen — nicht blind kopieren.
- **CGEventFlags-API-Namen:** Auf macOS 26 Tahoe können `.maskSecondaryFn` etc. andere Namen haben. Falls Compile-Fehler: Apple-Docs für `CGEventFlags` checken.
- **SwiftUI `@Bindable`-Binding in HotkeysTab:** Muss mit bestehendem SettingsStore-Pattern kompatibel sein. Wenn der Store `@Observable` ist, sollte `@Bindable` funktionieren; falls Environment-basiert, `@Environment(SettingsStore.self)` nutzen.
