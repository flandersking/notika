# Kirjo — Rebrand-Design (von "Notika")

**Status:** Entwurf, zur User-Review
**Datum:** 2026-04-19
**Autor:** Michael + Claude (Brainstorming-Session)

## 1. Entscheidung

Der Projektname wechselt von **Notika** zu **Kirjo**.

- Domain-Primär: `kirjo.ai`
- Fallback/Sekundär: `kirjo.app`
- Medizin-Variante (Phase 2): voraussichtlich `Kirjo Med` oder `Kirjo Clinic` (eigener Sub-Brand, gemeinsame Wortmarke)

## 2. Begründung (Kurzfassung)

**Kirjo** ist finnisch für "Spektrum/Vielfalt"; Wortstamm *kirjoittaa* = schreiben, *kirja* = Buch. Dreiklang "Schreiben × Vielfalt × Buch" passt präzise zur Multi-Modus-Diktier-App.

**Warum nicht Notika:** Notika hatte markenrechtliche Fragezeichen in DACH + keine klare semantische Story. Der Rebrand ist jetzt (vor iOS-Entwicklung, vor Beta-Tester) minimal invasiv (~2-3h).

**Warum nicht Perikon:** "Gothaer Perikon" ist etablierte deutsche Dread-Disease-Versicherung → SEO-Dominanz + emotionale Assoziation "Krebsversicherung" toxisch für Kindermedizin-Zielgruppe.

**Recherche-Ergebnis Kirjo:**
- `.ai`, `.app`, `.de`, `.io` alle frei
- App Store + Play Store frei
- Keine TM-Konflikte in Klassen 9/42/10/44 (Teknos KIRJO® = Farben = andere Klasse)
- Finnische Medizin-Marken etabliert (Orion Pharma, Fennia) → Medizin-Phase-2-tauglich

**Reibungspunkte (akzeptiert):**
- `.com` + `.fi` bei Domain-Flippern → `.ai` als Primärdomain reicht
- Social-Handle `@kirjo` belegt → Ausweich auf `@kirjoapp` oder `@getkirjo`
- DE-Aussprache-Hinweis nötig ("Kirjo — finnisch für Spektrum")

## 3. Scope des Rebrands

### Umzubenennen
- Bundle-ID: `com.notika.mac` → `com.kirjo.mac` (oder `ai.kirjo.mac`)
- Xcode-Projektname: `Notika.xcodeproj` → `Kirjo.xcodeproj`
- Swift-Packages: `NotikaCore`, `NotikaTranscription`, `NotikaPostProcessing`, `NotikaDictionary`, `NotikaWhisper`, `NotikaMacOS` → `Kirjo*`
- Xcode-Schemes, Build-Configurations, Targets
- UserDefaults-Prefix: `notika.*` → `kirjo.*` (Hinweis: einmaliger Migrations-Code optional, da noch keine Produktiv-User)
- AppIcon-Referenzen (Asset-Namen, nicht zwingend das visuelle Design)
- Display-Name im Info.plist: "Notika" → "Kirjo"
- Signing-Certs: neue App-Registrierung im Apple Developer Portal (Team P7QK554EET)
- GitHub-Repo: `flandersking/notika` → `flandersking/kirjo` (GitHub bietet automatische Redirects)
- Readme, Dokumentation, Kommentare, `tasks/`-Dateien, `docs/`-Inhalte
- Sparkle-AppCast-URLs (falls im Code bereits konfiguriert)

### NICHT umzubenennen (wichtig!)
- **SwiftData-Store:** läuft über Container-Konfiguration, Rename würde bestehende Daten invalidieren (keine aktive Nutzerdaten, aber sauberer bleibt sauberer)
- **API-Keys in Keychain:** Service-Identifier kann notika.* bleiben ODER via Migrations-Code mitwandern (später prüfen)
- **Git-History:** bleibt erhalten (`git mv` für Dateien, nicht Repo-Reset)

## 4. Reihenfolge (high-level, Plan kommt separat)

1. **Vorbereitung** — Branch `rebrand/kirjo` anlegen, ggf. Arbeitskopie sichern
2. **Xcode-Projekt-Rename** — `Notika.xcodeproj` → `Kirjo.xcodeproj` via Xcode "Rename Project" (dann Clean + Archive testen)
3. **Bundle-ID-Wechsel** — Info.plist + Signing-Settings
4. **Swift-Package-Renames** — Package.swift + Verzeichnisse + Imports quer durch Codebase
5. **UserDefaults-Prefix** — globaler Find-Replace `notika.` → `kirjo.`
6. **Docs + Readme + Comments** — textuelle Aufräumung
7. **Apple Developer Portal** — neue App-ID/Bundle-ID registrieren, Signing-Profile erzeugen
8. **GitHub-Repo-Rename** — via GitHub-Settings (Auto-Redirect)
9. **Domain-Registrierung** — `kirjo.ai` sichern (Primär), optional `kirjo.app`
10. **Smoke-Test** — Build, Signing, Notarization, DMG, Launch, Sparkle-Check
11. **Medizin-Variante-Branding** — später, eigener Design-Zyklus

## 5. Risiken

- **Xcode-Rename-Tücken:** "Rename Project" benennt nicht alle Referenzen zuverlässig — Nachbessern mit Find-Replace nötig
- **Signing-Certs:** Fehler im Apple Developer Portal können Build blockieren. Altes Zertifikat nicht sofort löschen
- **GitHub-Remote-URL:** Nach Repo-Rename muss `git remote set-url origin` im lokalen Checkout aktualisiert werden
- **Sparkle-Updates:** AppCast-URL und Public-Key-Konfiguration prüfen, damit bestehende Beta-Builds (falls vorhanden) nicht brechen
- **macOS-Quarantine:** nach Bundle-ID-Wechsel behandelt macOS die App als "neu" — User-Accessibility-Erlaubnis muss erneut erteilt werden (unkritisch, da noch Entwicklungs-Stadium)

## 6. Erfolgs-Kriterien

- Build (Release) läuft ohne Warnings
- Notarization + DMG erfolgreich
- App startet unter neuem Namen, Hotkeys funktionieren, alle 3 Modi OK
- Sparkle-Update-Check läuft (gegen Test-AppCast)
- `git log` zeigt sauberen Rebrand-Commit (nicht als History-Rewrite)

## 7. Offene Punkte (zu klären vor Plan-Erstellung)

- **Bundle-ID-Präfix:** `com.kirjo.mac` vs. `ai.kirjo.mac`? (`.ai` wäre ungewöhnlich aber thematisch)
- **Medizin-Variante-Naming:** "Kirjo Med", "Kirjo Clinic", "Kirjo Pro Med" — später
- **`kirjo.com` / `kirjo.fi` Kauf:** jetzt verhandeln (Risiko Mitbewerber) oder später?
- **Social-Handles:** `@kirjoapp`, `@getkirjo`, `@kirjo.ai` — welcher primär?

## 8. Nicht im Scope dieses Designs

- Logo-Redesign (bestehendes Kapsel-Icon kann Kirjo tragen — kleine Farbrevision denkbar, eigener Design-Zyklus)
- Website/Landing-Page (separater Track)
- Medizin-Variante-Spec (Phase 2, eigener Spec)
- iOS-Entwicklung (eigener Track, Rename muss aber VORHER passieren)
