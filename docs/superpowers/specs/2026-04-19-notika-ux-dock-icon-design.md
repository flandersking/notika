# Design-Spec: Dock-Icon während Einstellungsfenster offen

**Datum:** 2026-04-19
**Scope:** UX-Backlog Punkt A — Dock-Icon-Verhalten
**Aufwand:** ~20 min

## Problem

Notika ist eine MenuBar-App (`LSUIElement=YES`). Wenn der User die Einstellungen
über die Menüleiste öffnet und dann zu einem anderen Fenster wechselt, ist das
Einstellungsfenster nicht mehr per Cmd+Tab oder Dock erreichbar — Notika taucht
dort gar nicht erst auf. Der einzige Weg zurück ist Menüleiste → Einstellungen.
Das fühlt sich für den User falsch an und unterbricht den Flow.

## Ziel

Während das Einstellungsfenster geöffnet ist, verhält sich Notika wie eine
normale Foreground-App (Dock-Icon sichtbar, in Cmd+Tab enthalten). Sobald das
Fenster geschlossen wird, verschwindet das Dock-Icon wieder und die App läuft
wie gewohnt unsichtbar in der Menüleiste weiter.

## Nicht-Ziel

- Kein User-Setting "Dock-Icon immer anzeigen" (Wispr-Flow-artig).
  Wenn später gewünscht, trivial nachrüstbar.
- Kein Eingriff in das Close-Button-Verhalten selbst — das × schließt weiterhin
  nur das Fenster.
- Kein Wechsel von `LSUIElement=YES` in der `Info.plist`. Die App bleibt
  standardmäßig eine Accessory-App.

## Lösung

SwiftUI-Lifecycle auf `SettingsView` nutzen, um die `NSApp.activationPolicy`
dynamisch zwischen `.accessory` und `.regular` umzuschalten.

```swift
// Notika/Settings/SettingsView.swift
struct SettingsView: View {
    var body: some View {
        TabView { /* … bestehende Tabs … */ }
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

### Flow

1. App startet → `Info.plist` `LSUIElement=YES` → ActivationPolicy = `.accessory`
   → nur Menüleiste, kein Dock-Icon.
2. User: Menüleiste → Einstellungen. SwiftUI öffnet die `Settings`-Scene,
   `SettingsView` erscheint.
3. `.onAppear` feuert:
   - `setActivationPolicy(.regular)` → Dock-Icon erscheint, App ist in Cmd+Tab.
   - `activate(ignoringOtherApps: true)` → Settings-Fenster kommt nach vorn.
4. User wechselt zu anderem Fenster → Notika-Dock-Icon + Cmd+Tab-Eintrag
   bleiben → Rückkehr per Klick aufs Dock-Icon oder Cmd+Tab.
5. User schließt Einstellungsfenster per rotem ×. `.onDisappear` feuert:
   - `setActivationPolicy(.accessory)` → Dock-Icon verschwindet, App läuft
     weiter in der Menüleiste.

### Edge Cases

- **Cmd+Q während Fenster offen:** App terminiert normal. Der Policy-Wert ist
  beim Beenden irrelevant.
- **Fenster mehrfach öffnen/schließen:** `onAppear`/`onDisappear` feuern
  jedes Mal. `setActivationPolicy` ist idempotent.
- **Diktat während Fenster offen:** Policy beeinflusst weder Hotkeys noch
  MenuBarExtra. Diktieren funktioniert unabhängig.
- **Mehrere Settings-Tabs:** Tab-Wechsel triggert weder `onAppear` noch
  `onDisappear` auf der Root-View — Policy bleibt `.regular`.
- **User wechselt Settings-Tab bei noch im Dock gehaltenem Fokus:** unkritisch,
  Policy ändert sich nicht durch Tab-Wechsel.

## Betroffene Dateien

- `Notika/Settings/SettingsView.swift` — `.onAppear` / `.onDisappear` an
  `TabView` anhängen.

Keine anderen Dateien. Insbesondere **keine** Änderung an
`Notika/Resources/Info.plist` (`LSUIElement=YES` bleibt) und **keine** an
`Notika/NotikaApp.swift`.

## Testing

- **Keine Unit-Tests** — reiner AppKit-Side-Effect ohne testbare Logik.
- **Manueller Smoketest:**
  1. App starten → kein Dock-Icon ✔
  2. Menüleiste → Einstellungen → Dock-Icon erscheint, Fenster im Vordergrund ✔
  3. Anderes Fenster (z. B. Finder) nach vorn → Notika bleibt im Dock ✔
  4. Cmd+Tab → Notika erscheint in Liste → auswählen → Settings-Fenster vorn ✔
  5. Dock-Icon klicken → Settings-Fenster vorn ✔
  6. Settings mit × schließen → Dock-Icon verschwindet ✔
  7. Neu öffnen, mehrfach zu/auf → kein Dock-Leak, Policy wechselt sauber ✔

## Fallback

Falls sich im Smoketest zeigt, dass `.onAppear` / `.onDisappear` auf der
`Settings`-Scene unter macOS 26 unzuverlässig feuert (z. B. beim ersten Öffnen
gar nicht, oder doppelt durch Tab-Wechsel), wechseln wir auf
`NSWindow.didBecomeKeyNotification` + `NSWindow.willCloseNotification` mit
Filter auf Window-Identifier. Das ist robuster, aber verbose. Erstmal den
SwiftUI-Weg probieren.

## Offene Fragen

Keine.
