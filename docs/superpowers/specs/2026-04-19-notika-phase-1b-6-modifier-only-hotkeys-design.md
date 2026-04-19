# Notika — Phase 1b-6 Design: Modifier-only Hotkeys + Trigger-Mode-UI

**Stand:** 2026-04-19
**Vorgänger:** Phase 1b-3 (Dictionary, abgeschlossen + gemerged)
**Folge-Phasen (noch offen):**
- Phase 1b-5 — Sparkle Auto-Update
- Phase 2 — Medizin

**Zusammenführung:** Dieses Spec erledigt gleichzeitig **Phase 1b-4** (Toggle-Trigger-UI), weil der neue Konfigurations-Flow sowieso PTT vs. Toggle pro Modus exponiert.

## 1. Ziel & Scope

User möchte Notika wie **Wispr Flow** auslösen können: nur **Fn halten**, oder **rechte Cmd-Taste halten** — ohne klassische Tastenkombi. Die `sindresorhus/KeyboardShortcuts`-Library erlaubt das nicht. Daher: zweiter Trigger-Pfad auf CGEventTap-Basis, **parallel** zum bestehenden HotkeyManager.

**User-Entscheidungen (aus Brainstorming 2026-04-19):**
- **B:** Unterstützt werden **Fn**, **Right-Command**, **Right-Option** (drei Modifier)
- **C:** PTT und Toggle pro Modus konfigurierbar — löst 1b-4 mit
- **A:** Modifier-only **ergänzt** die klassischen Shortcuts (beides aktiv gleichzeitig)

**Nicht-Ziele (v1):**
- Linke Modifier-Varianten (Left-Cmd/Left-Option) — zu viele System-Konflikte
- Konfigurierbare Hold-Schwelle (auf 100 ms Default festgelegt)
- Double-Tap-Gesten (Wispr-Flow-Style) — zu komplex für v1
- Onboarding-Step für Modifier-only — nur Settings-Tab erreichbar

## 2. Architektur

Zwei parallele Trigger-Pfade liefern Events in **denselben** `AsyncStream<HotkeyEvent>`:

```
┌─ Pfad A: Bestehend (unverändert) ────────────┐
│  sindresorhus/KeyboardShortcuts              │
│  → HotkeyManager.onKeyDown/onKeyUp           │
│  → yield .pressed(mode) / .released(mode)    │
└──────────────────────────────────────────────┘
                      ↓
                AsyncStream<HotkeyEvent>
                      ↑
┌─ Pfad B: NEU ────────────────────────────────┐
│  CGEventTap auf .flagsChanged + .keyDown     │
│  → ModifierHotkeyTap.evaluate(flags, keyCode)│
│  → yield .pressed(mode) / .released(mode)    │
└──────────────────────────────────────────────┘
```

`DictationCoordinator` konsumiert den Stream wie bisher — **keine Änderung** am Konsument-Code.

## 3. Datenmodell

### ModifierTrigger (neu, in NotikaMacOS)

```swift
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
```

### TriggerMode (bestehend, in HotkeyManager) — wird gehoben nach NotikaCore

```swift
public enum TriggerMode: String, Codable, CaseIterable, Sendable {
    case pushToTalk = "pushToTalk"
    case toggle     = "toggle"

    public var displayName: String {
        switch self {
        case .pushToTalk: return "Halten (Push-to-Talk)"
        case .toggle:     return "Antippen (Toggle)"
        }
    }
}
```

### ModeHotkeyConfig (neu, in NotikaCore)

```swift
public struct ModeHotkeyConfig: Codable, Sendable, Equatable {
    public var modifierTrigger: ModifierTrigger = .none
    public var triggerMode: TriggerMode         = .pushToTalk
    // Der classicShortcut wird weiter von KeyboardShortcuts.Name
    // in UserDefaults verwaltet — nicht hier dupliziert.
}
```

### SettingsStore-Erweiterung

```swift
@Observable
public final class SettingsStore {
    // ... bestehend ...

    public var hotkeyConfigLiteral: ModeHotkeyConfig = .init()
    public var hotkeyConfigSocial:  ModeHotkeyConfig = .init()
    public var hotkeyConfigFormal:  ModeHotkeyConfig = .init()
}
```

Persistierung: JSON-encoded in UserDefaults unter `notika.hotkey.config.<mode>`.

## 4. UI — Kurzbefehle-Tab neu

Pro Modus eine Zeile mit drei nebeneinander liegenden Controls:

```
┌── Kurzbefehle ──────────────────────────────────────────────────────────────┐
│                                                                             │
│  Modus          Tastenkombi       Modifier-Trigger       Auslöser           │
│  ──────         ───────────       ─────────────────      ────────           │
│  📝 Literal     [⌘⌥1] ×           [Fn-Taste      ▼]     [Halten       ▼]   │
│  💬 Social      [⌘⌥2] ×           [Keiner        ▼]     [Halten       ▼]   │
│  ✉️ Formal      [⌘⌥3] ×           [Rechte ⌘-Taste ▼]    [Antippen     ▼]   │
│                                                                             │
│  ℹ️ Halten = drücken und sprechen, loslassen stoppt.                        │
│     Antippen = einmal drücken zum Start, nochmal zum Beenden.               │
│                                                                             │
│  ℹ️ Hinweis: Tastenkombi und Modifier-Trigger sind beide aktiv.             │
│     Setze den Modifier-Trigger auf „Keiner", um nur die Tastenkombi zu      │
│     nutzen. Achte auf Konflikte mit System-Shortcuts!                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

- Spalte „Modifier-Trigger": Picker mit den 4 `ModifierTrigger`-Werten
- Spalte „Auslöser": Picker mit den 2 `TriggerMode`-Werten
- Spalte „Tastenkombi": bestehender `KeyboardShortcuts.Recorder` — unverändert

**Mutter-Test-konform:** Die Mutter versteht „Halten" und „Antippen". Tech-Begriffe wie „PTT" nur in Tooltips oder Hilfetext.

## 5. CGEventTap-Logik

### Event-Maske
Tap lauscht auf:
- `CGEventType.flagsChanged` — Modifier-Statuswechsel
- `CGEventType.keyDown` — zur Cancel-Erkennung (andere Taste gedrückt)

### Right-vs-Left-Diskrimination

| Trigger | Erkennungsmerkmal |
|---|---|
| Fn | `NSEvent.ModifierFlags.function` im flags-Set |
| Right-Command | keyCode **54** + `.command`-Flag |
| Right-Option | keyCode **61** + `.option`-Flag |

Left-Varianten (keyCode 55 für Left-Cmd, 58 für Left-Option) werden **ignoriert**.

### State-Machine pro konfiguriertem Modifier-Trigger

```
IDLE ──(flagsChanged: nur konfigurierter Modifier aktiv, Timer starten)──► ARMING
ARMING ──(keyDown: andere Taste)──► CANCELED ──(flagsChanged: Modifier weg)──► IDLE
ARMING ──(flagsChanged: Modifier weg vor Timer)──► IDLE
ARMING ──(Timer 100 ms)──► TRIGGERED ──► yield .pressed(mode)
TRIGGERED ──(flagsChanged: Modifier weg)──► yield .released(mode) ──► IDLE
TRIGGERED ──(keyDown: andere Taste)──► yield .released(mode) ──► IDLE (Cancel)
```

**Kernregel:** `.pressed` wird erst nach 100 ms Hold gefeuert, damit versehentliches Streifen der Taste ignoriert wird. Bei PTT heißt das: User muss bewusst halten — kein Nachteil. Bei Toggle heißt das: ein harter Tap (>100 ms Hold) löst aus, ein Wimpernschlag nicht.

**Exklusivitäts-Regel:** Trigger feuert NUR, wenn die Modifier-Flags **genau** den konfigurierten Modifier plus keine anderen Key-States enthalten. Beispiel: „Fn allein" triggert, „Fn+A" triggert nicht.

### Mapping Trigger → DictationMode

Mapping: Jeder der 3 Modi (Literal/Social/Formal) kann **genau einen** Modifier-Trigger haben. Der `ModifierHotkeyTap` hält eine Map `[ModifierTrigger: DictationMode]` aus der Settings-Config.

**Kollisionen:** Wenn User denselben Modifier zwei Modi zuweist — die Config-Schicht verhindert das via Picker-Logik (ein Modifier, der in einem Modus gesetzt ist, wird in den anderen Pickern gegraut).

## 6. Accessibility-Permission

- Bereits vorhanden (wird für TextInserter benötigt)
- `ModifierHotkeyTap.start()` prüft `AXIsProcessTrusted()` → falls `false`, **kein Crash**, stattdessen State `.permissionMissing` und Log-Warnung
- UI-Fallback: Kurzbefehle-Tab zeigt Warnbanner „Bedienungshilfen aktivieren, damit Modifier-Trigger funktionieren" mit Button zu System-Settings
- Pfad A (klassische Shortcuts) funktioniert ohne Accessibility weiter

## 7. Integration in HotkeyManager

`HotkeyManager` bekommt einen zweiten Eingabepfad:

```swift
public final class HotkeyManager {
    private let classicTap: ClassicShortcutsSource   // wrapt KeyboardShortcuts
    private let modifierTap: ModifierHotkeyTap       // neu

    public func start(configs: [DictationMode: ModeHotkeyConfig]) {
        classicTap.start()
        modifierTap.start(configs: configs)
    }

    public func updateConfigs(_ configs: [DictationMode: ModeHotkeyConfig]) {
        modifierTap.reconfigure(configs: configs)
    }

    public var events: AsyncStream<HotkeyEvent> { … }  // gemergt aus beiden
}
```

- `modifierTap.reconfigure(...)` wird von der Settings-UI getriggert, wenn User Picker ändert → Tap ohne Restart neu verdrahten
- Toggle-Logik (`handleToggle` Zeile 100-107 im bestehenden Code) wird aus `DictationCoordinator` zu `HotkeyManager` gehoben oder bleibt im Coordinator, aber dann beachtet er die `TriggerMode` aus der Config statt globaler Variable

## 8. Persistierung

### UserDefaults-Keys

```
notika.hotkey.config.literal  → JSON-encoded ModeHotkeyConfig
notika.hotkey.config.social   → JSON-encoded ModeHotkeyConfig
notika.hotkey.config.formal   → JSON-encoded ModeHotkeyConfig
```

Klassische Shortcuts bleiben wie bisher unter `KeyboardShortcuts.Name.*` — **kein Schema-Change**.

### Migration

Kein Migrationsbedarf — neue Keys kommen hinzu, alte bleiben unberührt. Beim ersten Start: Defaults aus dem Code (`ModifierTrigger.none`, `TriggerMode.pushToTalk`).

## 9. Testing

### Unit-Tests (Swift Testing oder XCTest, konsistent zum Projekt-Standard)

`ModifierHotkeyTapTests`:
- Table-driven Tests für `evaluate(flags:keyCode:state:)` mit mindestens 12 Szenarien:
  1. Fn allein → ARMING
  2. Fn + A (keyCode A im flags) → kein ARMING
  3. Fn gehalten 100 ms → TRIGGERED
  4. Fn <100 ms losgelassen → kein TRIGGERED
  5. Right-Cmd (keyCode 54) allein → ARMING
  6. Left-Cmd (keyCode 55) allein → NICHT ARMING
  7. Right-Option (keyCode 61) allein → ARMING
  8. Right-Cmd + Right-Option (beide) → kein ARMING (nur einer erlaubt)
  9. Fn → ARMING → keyDown(S) → CANCELED
  10. Fn → TRIGGERED → Fn loslassen → RELEASED
  11. Fn → TRIGGERED → keyDown(S) → RELEASED (Cancel während Triggered)
  12. Modifier-Trigger = .none → nie ARMING

`HotkeyManagerTests`:
- Reconfigure ohne Restart ändert Mapping
- Events aus beiden Pfaden landen im gleichen Stream in richtiger Reihenfolge

### Manueller Smoketest (dokumentiert in `docs/PHASE_1B_6_SMOKETEST.md`)

6 Hauptszenarien:
1. Fn halten → Literal-Diktat startet, Loslassen stoppt
2. Right-Cmd antippen (Toggle) → Formal-Diktat startet, nochmal antippen → stoppt
3. Klassischer Shortcut ⌘⌥1 **plus** konfigurierter Fn-Modifier funktionieren gleichzeitig
4. Fn + A drücken → KEIN Diktat-Start (Cancel)
5. Accessibility-Permission widerrufen → Warnbanner im Settings-Tab, Pfad A läuft weiter
6. Modifier-Config live ändern (Picker wechseln) ohne App-Neustart → neuer Trigger funktioniert sofort

## 10. Betroffene Dateien & Module

**Neue Dateien:**
- `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/ModifierHotkeyTap.swift`
- `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/ModifierHotkeyTapState.swift` (State-Machine, pure, testbar)
- `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/ModeHotkeyConfig.swift`
- `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/ModifierTrigger.swift`
- `Packages/NotikaCore/Sources/NotikaCore/Hotkeys/TriggerMode.swift` (Enum hier anlegen, vom HotkeyManager referenziert)
- `Packages/NotikaMacOSTests/Tests/ModifierHotkeyTapStateTests.swift`
- `docs/PHASE_1B_6_SMOKETEST.md`

**Geänderte Dateien:**
- `Packages/NotikaMacOS/Sources/NotikaMacOS/Hotkeys/HotkeyManager.swift` — Integration beider Pfade
- `Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift` — 3 neue Properties + Persist/Load
- `Notika/Settings/SettingsView.swift` — HotkeysTab neu mit 3 Spalten pro Modus
- `Notika/DictationCoordinator.swift` — optional: Toggle-Logik aus Config lesen
- `Packages/NotikaCore/Package.swift` — ggf. neuer Source-Ordner
- `README.md` — Hotkeys-Abschnitt aktualisieren

## 11. Risiken & Entschärfungen

| Risiko | Wahrscheinlichkeit | Entschärfung |
|---|---|---|
| CGEventTap wird von System beendet (Permission-Verlust) | mittel | Tap-Disable-Callback → UI-Banner, auto-reconnect alle 10 s versuchen |
| Fn-Taste erzeugt auf externen Tastaturen keine `.function`-Flags | mittel | Doku-Hinweis im Tab („auf eingebauter Apple-Tastatur getestet"), Keyboard-Event-Mask als Backup |
| False Positives durch andere System-Events (z.B. Caps-Lock-Toggle sendet auch flagsChanged) | niedrig | Exklusivitäts-Check schließt zusätzliche Flags aus |
| Tap blockiert UI-Thread | niedrig | Tap läuft auf eigener RunLoop (separater `CFRunLoopSourceRef`) |
| Rechte Modifier auf Nicht-US-Tastaturen haben andere KeyCodes | niedrig | Apple-Keys 54/61 sind hardware-fest, nicht Layout-abhängig |

## 12. Umsetzungsaufwand

Geschätzt 2-3 h:
- ModifierHotkeyTap + State-Machine: 45 Min
- Unit-Tests (12 Szenarien): 30 Min
- SettingsStore-Erweiterung + Persistierung: 20 Min
- UI-Tab-Refactor mit 3 Spalten: 40 Min
- HotkeyManager-Merge beider Pfade: 20 Min
- Smoketest-Doku + manuelles Polishing: 15 Min
