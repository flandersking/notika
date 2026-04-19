# UX Dock-Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Notika zeigt während geöffnetem Einstellungsfenster ein Dock-Icon und taucht im Cmd+Tab-Switcher auf; sobald das Fenster geschlossen wird, verschwindet das Dock-Icon wieder.

**Architecture:** `SettingsView` bekommt SwiftUI-Lifecycle-Hooks (`.onAppear` / `.onDisappear`), die `NSApp.setActivationPolicy(.regular | .accessory)` umschalten. Kein neues User-Setting, keine `Info.plist`-Änderung (`LSUIElement=YES` bleibt).

**Tech Stack:** SwiftUI (macOS 26), AppKit (`NSApplication.activationPolicy`).

**Spec:** `docs/superpowers/specs/2026-04-19-notika-ux-dock-icon-design.md`

---

## File Structure

**Modify:**
- `Notika/Settings/SettingsView.swift` — `.onAppear` / `.onDisappear` an den `TabView` anhängen, Policy-Wechsel darin auslösen.

**Keine Änderungen an:**
- `Notika/Resources/Info.plist` (`LSUIElement=YES` bleibt)
- `Notika/NotikaApp.swift` (Scene-Struktur unverändert)
- `Notika/AppDelegate.swift` (falls vorhanden — nicht nötig)

**Testing:** Kein Unit-Test — reiner AppKit-Side-Effect ohne testbare Logik. Manueller Smoketest laut Spec.

---

### Task 1: SettingsView erhält Policy-Wechsel-Hooks

**Files:**
- Modify: `Notika/Settings/SettingsView.swift` (Zeilen 7–34, Root-`TabView`-View)

- [ ] **Step 1: Aktuellen Zustand der Datei prüfen**

Run:
```bash
sed -n '1,35p' Notika/Settings/SettingsView.swift
```

Erwartet (Referenz-Stand):
```swift
import SwiftUI
import KeyboardShortcuts
import NotikaCore
import NotikaMacOS
import ApplicationServices

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("Allgemein", systemImage: "gearshape") {
                GeneralTab()
            }
            Tab("Kurzbefehle", systemImage: "keyboard") {
                HotkeysTab()
            }
            Tab("Modi", systemImage: "text.badge.checkmark") {
                PromptsTab()
            }
            Tab("KI", systemImage: "sparkles") {
                AITab()
            }
            Tab("Wörterbuch", systemImage: "character.book.closed") {
                DictionaryTab()
            }
            Tab("Verlauf", systemImage: "clock.arrow.circlepath") {
                HistoryTab()
            }
            Tab("Über", systemImage: "info.circle") {
                AboutTab()
            }
        }
        .frame(minWidth: 720, minHeight: 440)
    }
}
```

Falls Import `AppKit` fehlt: merken für Step 2.

- [ ] **Step 2: AppKit-Import ergänzen (falls nicht vorhanden)**

`NSApp` / `NSApplication.ActivationPolicy` kommen aus `AppKit`. `SwiftUI` re-exportiert AppKit auf macOS bereits, aber wir importieren es explizit für Klarheit.

Edit `Notika/Settings/SettingsView.swift`:

```swift
// Alt:
import SwiftUI
import KeyboardShortcuts
import NotikaCore
import NotikaMacOS
import ApplicationServices

// Neu:
import SwiftUI
import AppKit
import KeyboardShortcuts
import NotikaCore
import NotikaMacOS
import ApplicationServices
```

Falls `import AppKit` bereits da ist: Step überspringen.

- [ ] **Step 3: `.onAppear` / `.onDisappear` am `TabView` anhängen**

Edit `Notika/Settings/SettingsView.swift`, Zeile mit `.frame(minWidth: 720, minHeight: 440)`:

Alt:
```swift
        }
        .frame(minWidth: 720, minHeight: 440)
    }
}
```

Neu:
```swift
        }
        .frame(minWidth: 720, minHeight: 440)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
```

- [ ] **Step 4: Build prüfen**

Run:
```bash
xcodebuild -scheme Notika -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20
```

Erwartet: `** BUILD SUCCEEDED **` in der Ausgabe.

Falls Fehler `Cannot find 'NSApp' in scope` → `import AppKit` fehlt, Step 2 wiederholen.

- [ ] **Step 5: Commit**

```bash
git add Notika/Settings/SettingsView.swift
git commit -m "$(cat <<'EOF'
UX-Dock-Icon #1: SettingsView wechselt ActivationPolicy bei Öffnen/Schließen

.onAppear → .regular + activate(ignoringOtherApps:) → Dock-Icon erscheint
und das Fenster kommt nach vorn. .onDisappear → .accessory → Dock-Icon
verschwindet, App läuft weiter in der Menüleiste. Keine Info.plist-Änderung.

Spec: docs/superpowers/specs/2026-04-19-notika-ux-dock-icon-design.md
EOF
)"
```

---

### Task 2: Manueller Smoketest

**Files:** Keine.

Dies ist kein Code-Step, sondern User-seitige Verifikation. Der ausführende Agent startet die App, der User klickt durch.

- [ ] **Step 1: App im Release-Mode bauen und starten**

Run:
```bash
xcodebuild -scheme Notika -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5
open -a "$(find ~/Library/Developer/Xcode/DerivedData -name Notika.app -path '*/Debug/*' -print -quit)"
```

Erwartet: App startet, Menüleisten-Icon (waveform.badge.mic) ist sichtbar, **kein Dock-Icon**.

- [ ] **Step 2: Smoketest-Checkliste durchgehen (User-Aktion)**

Der User prüft in dieser Reihenfolge:

1. App läuft, kein Dock-Icon → ✔ oder ✘
2. Menüleiste → **Einstellungen** klicken
   → Dock-Icon erscheint, Fenster im Vordergrund, Notika in Cmd+Tab → ✔ oder ✘
3. Anderes Fenster (Finder, Safari) nach vorn holen
   → Notika bleibt im Dock + Cmd+Tab sichtbar → ✔ oder ✘
4. Cmd+Tab → Notika wählen
   → Settings-Fenster kommt wieder nach vorn → ✔ oder ✘
5. Einstellungsfenster per rotem × schließen
   → Dock-Icon verschwindet, Menüleisten-Icon bleibt → ✔ oder ✘
6. Schritt 2–5 nochmal wiederholen
   → kein „Dock-Leak" (Icon bleibt nicht hängen), Policy sauber → ✔ oder ✘
7. Einstellungen öffnen → diktieren mit konfiguriertem Hotkey während Fenster offen
   → Diktat funktioniert wie gewohnt → ✔ oder ✘

- [ ] **Step 3: Falls ein Punkt ✘ ist — Fallback-Weg**

Wenn `.onAppear` / `.onDisappear` unzuverlässig feuern (z. B. Punkt 2 oder 5 schlägt fehl), Spec-Abschnitt „Fallback" umsetzen:
- `NSWindow.didBecomeKeyNotification` + `NSWindow.willCloseNotification` mit Window-Identifier-Filter.

Das wäre eine neue Task 3 — erst planen, wenn der Smoketest zeigt, dass wir sie brauchen.

- [ ] **Step 4: Memory + STATUS aktualisieren, Commit**

Falls alle 7 Punkte ✔:

Edit `/Users/michaeldymny/.claude/projects/-Users-michaeldymny-Desktop-claude-code-projekte-2604-sag-macos/memory/phase_1b_backlog.md`:

Im Abschnitt „UX-Backlog (gesammelt 2026-04-19, noch offen)" den ersten Bullet (Dock-Icon) als ✅ markieren oder entfernen.

Edit `/Users/michaeldymny/.claude/projects/-Users-michaeldymny-Desktop-claude-code-projekte-2604-sag-macos/memory/fortsetzungspunkt.md`:

Im Abschnitt „Session #N+1: UX-Backlog (Punkt A)" den Dock-Icon-Bullet als erledigt notieren. Close-Button-Punkt ist in der Brainstorming-Session als Nicht-Problem entlarvt worden (war eigentlich ein Fenster-Wiederfinden-Problem, gelöst durch Dock-Icon) → Bullet entfernen oder als „durch Dock-Icon gelöst" markieren.

Run:
```bash
git status
```

Erwartet: Working tree clean (Memory-Dateien liegen außerhalb des Repos).

- [ ] **Step 5: Push auf GitHub (nach User-OK)**

Agent fragt User nach explizitem OK, bevor gepusht wird (Projekt-Regel: keine Auto-Pushes).

Run (erst nach User-Freigabe):
```bash
git push origin main
```

Erwartet: 2 Commits werden gepusht (Spec aus vorangegangener Session + Implementation).

---

## Self-Review

**1. Spec coverage:**
- „Ziel: dynamischer Wechsel der ActivationPolicy" → Task 1 Step 3 ✔
- „Keine Info.plist-Änderung" → explizit vermerkt ✔
- „Keine Unit-Tests, manueller Smoketest" → Task 2 ✔
- „Fallback via NSWindow-Notifications" → Task 2 Step 3 dokumentiert ✔
- „Edge Cases (Cmd+Q, mehrfach öffnen, Diktat während offen)" → Smoketest-Punkte 6 und 7 ✔

**2. Placeholder scan:** Keine TBD/TODO. Alle Code-Blöcke vollständig.

**3. Type consistency:**
- `NSApp.setActivationPolicy(.regular)` / `.accessory` — korrekte NSApplication-API ✔
- `NSApp.activate(ignoringOtherApps: true)` — korrekte Signatur ✔
- `.onAppear` / `.onDisappear` — SwiftUI-Standard ✔

Plan ist konsistent mit dem Spec.
