# Phase 1b-6 Smoketest — Modifier-only Hotkeys + Trigger-Mode

**Voraussetzung:** App auf aktuellem `main`-Build, Accessibility-Permission aktiv.

## Setup

1. Öffne Notika → Einstellungen → **Kurzbefehle**-Tab
2. Konfiguriere testweise:
   - **Literal:** Modifier-Trigger = "Fn-Taste", Auslöser = "Halten"
   - **Social:** Modifier-Trigger = "Rechte ⌘-Taste", Auslöser = "Antippen"
   - **Formal:** Modifier-Trigger = "Rechte ⌥-Taste", Auslöser = "Halten"
3. Settings-Fenster bleibt offen — Änderungen wirken sofort (NotificationCenter).

## Szenarien

### 1. Fn halten (Literal, PTT)
- Fokus auf ein beliebiges Textfeld (z. B. TextEdit)
- Fn-Taste drücken und **halten** → Overlay "Aufnahme Literal" erscheint
- Sprich ein paar Wörter
- Fn loslassen → Transkript erscheint im Textfeld
- ✅ **Erwartet:** Diktat funktioniert

### 2. Right-⌘ antippen (Social, Toggle)
- Rechte ⌘-Taste **einmal kurz** drücken (>100 ms) → Aufnahme startet
- Sprich ein paar Wörter
- Rechte ⌘-Taste **nochmal kurz** drücken → Transkript erscheint
- ✅ **Erwartet:** Toggle funktioniert

### 3. Right-⌥ halten (Formal, PTT)
- Rechte ⌥-Taste drücken und halten, sprechen, loslassen
- ✅ **Erwartet:** Formal-Post-Processing angewandt

### 4. Klassischer Shortcut funktioniert parallel
- Drücke den Tastenkombi-Shortcut für Literal (z. B. ⌘⌥1)
- ✅ **Erwartet:** Aufnahme startet wie immer — beide Wege funktionieren

### 5. Fn + A (Cancel-Regel)
- Fn drücken und halten
- Innerhalb von <100 ms eine andere Taste (z. B. A) dazu drücken
- ✅ **Erwartet:** Kein Overlay, keine Aufnahme (Cancel durch Co-Key)

### 6. Hold-Schwelle (100 ms)
- Fn sehr kurz antippen (<100 ms)
- ✅ **Erwartet:** Keine Aufnahme (unter Schwelle)
- Fn länger halten (>150 ms) → Aufnahme startet

### 7. Accessibility-Permission widerrufen
- Notika beenden
- System-Einstellungen → Datenschutz → Bedienungshilfen → Notika deaktivieren
- Notika neu starten → Kurzbefehle-Tab öffnen
- ✅ **Erwartet:** Warnbanner sichtbar, klassische Shortcuts (⌘⌥1/2/3) funktionieren weiter, Modifier-Trigger **nicht**
- Permission wieder aktivieren, App neu starten → Modifier-Trigger funktionieren wieder

### 8. Live-Config-Wechsel
- Im Kurzbefehle-Tab: Literal-Modifier von "Fn" auf "Keiner" setzen
- Fn halten → ✅ **Erwartet:** keine Aufnahme mehr (Config wirkt sofort via Notification)
- Literal-Modifier zurück auf "Fn"
- Fn halten → ✅ **Erwartet:** Aufnahme startet wieder

## Bekannte Einschränkungen v1

- Hold-Schwelle fix auf 100 ms (nicht UI-konfigurierbar)
- Linke Cmd/Option werden bewusst ignoriert (System-Konflikte)
- Fn-Erkennung ist auf eingebauten Apple-Tastaturen getestet — bei externen kann `.function`-Flag fehlen
- Persistierung in UserDefaults unter `notika.hotkey.config.<mode>` (JSON)

## Unit-Test-Abdeckung

- `ModifierTriggerTests` (3 Tests): Enum-Vollständigkeit + Codable-Roundtrip
- `ModeHotkeyConfigTests` (3 Tests): Defaults, Codable, Equatable
- `SettingsStoreHotkeyConfigTests` (3 Tests): Persist über Instanzen, Kanal-Separation
- `ModifierHotkeyTapStateTests` (13 Tests): State-Machine für alle Modifier + Cancel-Regeln

**Gesamt 22 neue Unit-Tests für Phase 1b-6** — alle grün im `swift test`.
