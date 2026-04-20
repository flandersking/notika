# Kirjo-Rebrand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Projekt, Packages, Bundle-ID, Identifiers und Docs von "Notika" auf "Kirjo" umbenennen, ohne Git-History zu verlieren und ohne Runtime-Regressionen.

**Architecture:** Single-Branch-Refactor (`rebrand/kirjo`). Reihenfolge: Source-Rename (Packages → App-Ordner → Imports → Identifiers) → Xcode-Projekt regenerieren (xcodegen) → Build-Smoke-Test → Docs → Push. Externe Aktionen (GitHub-Repo, Apple Dev Portal, Domain) am Ende als Checkliste.

**Tech Stack:** Swift 6.0, macOS 26.0, xcodegen (project.yml), SwiftData, swift-log via OSLog `Logger(subsystem:)`, 6 Swift Packages, Apple Dev Team `P7QK554EET`.

**Design-Spec-Referenz:** `docs/superpowers/specs/2026-04-19-kirjo-rebrand-design.md`

---

## Bundle-ID (User-Entscheidung 2026-04-20)

**Bundle-ID: `de.dymny.kirjo.mac`**
- Pattern `de.dymny.<app>` analog zur anderen App des Users (`de.dymny.grammatik-detektiv`)
- `.mac`-Suffix für spätere iOS-Variante (`de.dymny.kirjo.ios`) — parallel sauber.
- `bundleIdPrefix` in `project.yml`: `de.dymny.kirjo` (Suffix `.mac` kommt über `PRODUCT_BUNDLE_IDENTIFIER`).
- Logger-Subsystems in allen `Logger(subsystem: …)` Calls: `de.dymny.kirjo.mac`.

---

## File Structure (nach Rebrand)

### Neue/Umbenannte Verzeichnisse
- `Kirjo/` (war `Notika/`) — App-Target-Sources
- `Kirjo/KirjoApp.swift` (war `NotikaApp.swift`)
- `Kirjo/Resources/Info.plist` (unverändert-Pfad, aber Strings drin geändert)
- `Kirjo/Resources/Kirjo.entitlements` (war `Notika.entitlements`)
- `Packages/KirjoCore/` (war `NotikaCore/`) — inkl. `Sources/KirjoCore/` + `Tests/KirjoCoreTests/`
- `Packages/KirjoTranscription/` (war `NotikaTranscription/`)
- `Packages/KirjoPostProcessing/` (war `NotikaPostProcessing/`)
- `Packages/KirjoDictionary/` (war `NotikaDictionary/`)
- `Packages/KirjoWhisper/` (war `NotikaWhisper/`)
- `Packages/KirjoMacOS/` (war `NotikaMacOS/`)
- `Kirjo.xcodeproj/` (regeneriert durch xcodegen, alt gelöscht)

### Zu ändernde Dateien (nicht Rename)
- `project.yml` — Name, Bundle-ID, Paket-Referenzen, Display-Name
- `README.md`, `LICENSE` (falls Name drin), alle `docs/**/*.md`, alle `tasks/**/*.md`
- `scripts/build.sh`, `scripts/run.sh`
- Alle `.swift`-Dateien mit Imports oder `notika.`/`Notika`-Strings

### Unverändert (wichtig!)
- SwiftData-Container-Config (keine Migrations-Logik)
- Keychain-Service-IDs (bleiben `notika.*`; Migrations-Code später optional)
- Git-History bleibt erhalten (`git mv` statt `rm`+`add`)

---

## Task 1: Entscheidung bestätigen + Branch + Sicherung

**Files:**
- Create: Branch `rebrand/kirjo`
- Create: Tag `pre-rebrand-backup` (Sicherheitsnetz)

- [ ] **Step 1: Bundle-ID-Entscheidung vom User holen**

Fragen:
```
1. Bundle-ID: ai.kirjo.mac (Default, empfohlen) oder com.kirjo.mac?
2. Jetzt loslegen? (Branch wird angelegt, main bleibt unberührt)
```
Warte auf Bestätigung, bevor du weitermachst. Notiere die Antwort als Variable `BUNDLE_ID` für alle folgenden Tasks.

- [ ] **Step 2: Working Tree verifizieren**

Run: `git status`
Expected: `On branch main ... nothing to commit, working tree clean`
Falls nicht clean → STOP, mit User klären.

- [ ] **Step 3: Sicherungs-Tag auf main setzen**

Run: `git tag pre-rebrand-backup`
Expected: kein Output (Erfolg)
Run: `git tag --list pre-rebrand-backup`
Expected: `pre-rebrand-backup`

- [ ] **Step 4: Rebrand-Branch anlegen**

Run: `git checkout -b rebrand/kirjo`
Expected: `Switched to a new branch 'rebrand/kirjo'`

- [ ] **Step 5: Commit (leerer Start-Commit für saubere History)**

Run:
```bash
git commit --allow-empty -m "chore(rebrand): Start Kirjo-Rebrand-Branch"
```
Expected: Commit angelegt.

---

## Task 2: Swift-Packages umbenennen (Verzeichnisse + Package.swift)

**Files:**
- Rename: `Packages/NotikaCore/` → `Packages/KirjoCore/`
- Rename: `Packages/NotikaTranscription/` → `Packages/KirjoTranscription/`
- Rename: `Packages/NotikaPostProcessing/` → `Packages/KirjoPostProcessing/`
- Rename: `Packages/NotikaDictionary/` → `Packages/KirjoDictionary/`
- Rename: `Packages/NotikaWhisper/` → `Packages/KirjoWhisper/`
- Rename: `Packages/NotikaMacOS/` → `Packages/KirjoMacOS/`
- Rename innerhalb jedes Packages: `Sources/Notika*/` → `Sources/Kirjo*/`, `Tests/Notika*Tests/` → `Tests/Kirjo*Tests/`
- Modify: Alle `Packages/*/Package.swift` (Name, Targets, Products, Dependencies)

- [ ] **Step 1: Top-Level-Package-Verzeichnisse via git mv umbenennen**

Run:
```bash
cd /Users/michaeldymny/Desktop/claude-code-projekte/2604_sag_macos
git mv Packages/NotikaCore Packages/KirjoCore
git mv Packages/NotikaTranscription Packages/KirjoTranscription
git mv Packages/NotikaPostProcessing Packages/KirjoPostProcessing
git mv Packages/NotikaDictionary Packages/KirjoDictionary
git mv Packages/NotikaWhisper Packages/KirjoWhisper
git mv Packages/NotikaMacOS Packages/KirjoMacOS
```
Expected: kein Output (Erfolg)
Run: `ls Packages/`
Expected: nur `Kirjo*`-Verzeichnisse.

- [ ] **Step 2: Sources-Unterverzeichnisse umbenennen (je Package)**

Run für jedes Package (Beispiel KirjoCore, analog für alle 6):
```bash
git mv Packages/KirjoCore/Sources/NotikaCore Packages/KirjoCore/Sources/KirjoCore
```
Analog:
```bash
git mv Packages/KirjoTranscription/Sources/NotikaTranscription Packages/KirjoTranscription/Sources/KirjoTranscription
git mv Packages/KirjoPostProcessing/Sources/NotikaPostProcessing Packages/KirjoPostProcessing/Sources/KirjoPostProcessing
git mv Packages/KirjoDictionary/Sources/NotikaDictionary Packages/KirjoDictionary/Sources/KirjoDictionary
git mv Packages/KirjoWhisper/Sources/NotikaWhisper Packages/KirjoWhisper/Sources/KirjoWhisper
git mv Packages/KirjoMacOS/Sources/NotikaMacOS Packages/KirjoMacOS/Sources/KirjoMacOS
```

- [ ] **Step 3: Tests-Unterverzeichnisse umbenennen (falls vorhanden)**

Run: `find Packages -type d -name "Notika*Tests"`
Für jedes Ergebnis analog `git mv` anwenden, z.B.:
```bash
git mv Packages/KirjoCore/Tests/NotikaCoreTests Packages/KirjoCore/Tests/KirjoCoreTests
```
Expected: alle Tests-Ordner umbenannt. Verify: `find Packages -type d -name "Notika*"` → leer.

- [ ] **Step 4: Package.swift-Dateien editieren (je 6 Packages)**

In jeder `Packages/Kirjo*/Package.swift` muss ersetzt werden:
- `name: "Notika*"` → `name: "Kirjo*"` (Package-Name)
- Alle `.target(name: "Notika*", ...)` → `.target(name: "Kirjo*", ...)`
- Alle `.testTarget(name: "Notika*Tests", ...)` → `.testTarget(name: "Kirjo*Tests", ...)`
- Alle `.product(name: "Notika*", ...)` und `.library(name: "Notika*", ...)` → `Kirjo*`
- Alle `dependencies: [.product(name: "NotikaCore", package: "NotikaCore")]` → `KirjoCore, package: KirjoCore`
- `path:` Angaben, falls explizit `Sources/Notika*` → auf `Sources/Kirjo*` anpassen

**Ausführung:** Nutze globalen Replace via sed je Datei oder Edit-Tool für jede Datei einzeln.

Beispiel-Command (vorsichtig — pro Datei verifizieren):
```bash
for f in Packages/*/Package.swift; do sed -i '' 's/Notika/Kirjo/g' "$f"; done
```
Nach Replace: `git diff Packages/*/Package.swift` lesen, prüfen dass *nur* Namen getroffen wurden.

- [ ] **Step 5: Swift-Package-Resolution testen**

Run (im Project-Root):
```bash
cd Packages/KirjoCore && swift package resolve 2>&1 | head -20
```
Expected: keine "package not found"-Fehler.
Falls `NotikaCore` noch irgendwo referenziert → zurück zu Step 4.

Wiederhole für je 1–2 weitere Packages als Stichprobe.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(rebrand): Swift-Packages Notika* → Kirjo* (Verzeichnisse + Package.swift)"
```

---

## Task 3: App-Source-Ordner + Swift-Dateien umbenennen

**Files:**
- Rename: `Notika/` → `Kirjo/`
- Rename: `Notika/NotikaApp.swift` → `Kirjo/KirjoApp.swift`
- Rename: `Notika/Resources/Notika.entitlements` → `Kirjo/Resources/Kirjo.entitlements`

- [ ] **Step 1: App-Ordner umbenennen**

Run: `git mv Notika Kirjo`
Expected: kein Output
Run: `ls Kirjo/`
Expected: `AppDelegate.swift Assets.xcassets DictationCoordinator.swift MenuBar NotikaApp.swift Onboarding Overlay Resources Settings`

- [ ] **Step 2: Swift-Hauptdatei umbenennen**

Run: `git mv Kirjo/NotikaApp.swift Kirjo/KirjoApp.swift`
Expected: kein Output

- [ ] **Step 3: Entitlements umbenennen**

Run: `git mv Kirjo/Resources/Notika.entitlements Kirjo/Resources/Kirjo.entitlements`
Expected: kein Output

- [ ] **Step 4: Suche nach weiteren "Notika"-Dateinamen in Kirjo/**

Run: `find Kirjo -name "*Notika*" -type f`
Expected: leere Ausgabe.
Falls Treffer → `git mv` analog anwenden.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(rebrand): App-Ordner Notika → Kirjo + NotikaApp.swift → KirjoApp.swift"
```

---

## Task 4: Swift-Imports und Typ-/Extension-Referenzen global ersetzen

**Files:**
- Modify: alle `*.swift` mit `import NotikaX` oder `NotikaX.Typ`-Referenzen (App-Target + alle Packages)

- [ ] **Step 1: Alle betroffenen Imports auflisten (Baseline)**

Run:
```bash
grep -rn "import Notika" Kirjo/ Packages/ --include="*.swift" | wc -l
```
Notiere die Zahl als Baseline (z.B. 120 Treffer).

- [ ] **Step 2: Find-Replace `import NotikaX` → `import KirjoX` quer durch Codebase**

Run:
```bash
find Kirjo Packages -name "*.swift" -type f -exec sed -i '' 's/import NotikaCore/import KirjoCore/g; s/import NotikaTranscription/import KirjoTranscription/g; s/import NotikaPostProcessing/import KirjoPostProcessing/g; s/import NotikaDictionary/import KirjoDictionary/g; s/import NotikaWhisper/import KirjoWhisper/g; s/import NotikaMacOS/import KirjoMacOS/g' {} \;
```

- [ ] **Step 3: Verify — keine Notika-Imports mehr**

Run:
```bash
grep -rn "import Notika" Kirjo/ Packages/ --include="*.swift"
```
Expected: leere Ausgabe.

- [ ] **Step 4: Modul-qualifizierte Type-Referenzen suchen**

Run:
```bash
grep -rn "NotikaCore\.\|NotikaTranscription\.\|NotikaPostProcessing\.\|NotikaDictionary\.\|NotikaWhisper\.\|NotikaMacOS\." Kirjo/ Packages/ --include="*.swift"
```
Expected: ggf. Treffer wie `NotikaCore.SettingsStore`.
Für jeden Treffer: mit Edit-Tool ersetzen (`NotikaX.` → `KirjoX.`).
Alternativ (vorsichtig):
```bash
find Kirjo Packages -name "*.swift" -exec sed -i '' 's/NotikaCore\./KirjoCore./g; s/NotikaTranscription\./KirjoTranscription./g; s/NotikaPostProcessing\./KirjoPostProcessing./g; s/NotikaDictionary\./KirjoDictionary./g; s/NotikaWhisper\./KirjoWhisper./g; s/NotikaMacOS\./KirjoMacOS./g' {} \;
```
Verify: Command aus Step 4 nochmal → leere Ausgabe.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(rebrand): Swift-Imports + Modul-qualifizierte Referenzen Notika* → Kirjo*"
```

---

## Task 5: Interne Strings, Logger-Subsystems, UserDefaults-Prefix

**Files:**
- Modify: alle Stellen mit `com.notika.mac` (Logger-Subsystems)
- Modify: alle Stellen mit `notika.`-Prefix (UserDefaults-Keys, Notification-Names, test-SuiteNames)
- Modify: alle textuellen `"Notika"`-Strings in User-Visible-Code (Usage-Description, In-App-Copy)

- [ ] **Step 1: Logger-Subsystem `com.notika.mac` → `$BUNDLE_ID`**

Ersetze in allen `.swift`:
- `com.notika.mac` → `$BUNDLE_ID` (Beispiel: `ai.kirjo.mac`)

Run:
```bash
find Kirjo Packages -name "*.swift" -exec sed -i '' 's/com\.notika\.mac/ai.kirjo.mac/g' {} \;
```
(Falls User Bundle-ID `com.kirjo.mac` wählt: `com.kirjo.mac` statt `ai.kirjo.mac`.)

Verify:
```bash
grep -rn "com\.notika\.mac" Kirjo/ Packages/ --include="*.swift"
```
Expected: leer.

- [ ] **Step 2: UserDefaults + Notification-Prefix `notika.` → `kirjo.`**

Run:
```bash
find Kirjo Packages -name "*.swift" -exec sed -i '' 's/"notika\./"kirjo./g' {} \;
```
Verify:
```bash
grep -rn "\"notika\." Kirjo/ Packages/ --include="*.swift"
```
Expected: leer.

- [ ] **Step 3: Test-Suite-Names `test.notika.` → `test.kirjo.`**

Run:
```bash
find Packages -name "*.swift" -exec sed -i '' 's/test\.notika\./test.kirjo./g' {} \;
```

- [ ] **Step 4: User-sichtbare Text-Strings "Notika" → "Kirjo"**

Dies betrifft u.a. `Info.plist` Usage-Descriptions, `AppDelegate`-Print-Statements, Settings-UI-Copy.

Run:
```bash
grep -rn "Notika" Kirjo/ Packages/ --include="*.swift"
```
Für jeden Treffer: im Kontext prüfen, ob textueller String oder Typ-Referenz. Textuelle Strings via Edit-Tool auf "Kirjo" umstellen.

Häufige Muster:
- `"Notika"` (String-Literal) → `"Kirjo"`
- `"Notika nimmt Audio auf…"` → `"Kirjo nimmt Audio auf…"`
- Kommentare `// Notika-…` → `// Kirjo-…`

Vorsicht: Symbole wie `NotikaApp` (Typ) NICHT ersetzen — nur String-Literale.

Mache das bewusst manuell mit Edit-Tool pro Datei, nicht mit sed, um Symbol-Kollisionen zu vermeiden.

- [ ] **Step 5: `NotikaApp`-Symbol in `KirjoApp.swift` umbenennen**

Lies `Kirjo/KirjoApp.swift` und ersetze die Struct-Deklaration:
- `struct NotikaApp: App` → `struct KirjoApp: App`
- Falls `@main` davor steht: bleibt.

Prüfe mit:
```bash
grep -n "NotikaApp\|KirjoApp" Kirjo/KirjoApp.swift
```
Expected: nur noch `KirjoApp`.

- [ ] **Step 6: Info.plist Usage-Descriptions ändern**

Lies `Kirjo/Resources/Info.plist`. Ersetze:
- `<string>Notika nimmt Audio auf, um Sprache in Text umzuwandeln.</string>` → `<string>Kirjo nimmt Audio auf, um Sprache in Text umzuwandeln.</string>`
- `<string>Notika nutzt Apple Speech für on-device Transkription.</string>` → `<string>Kirjo nutzt Apple Speech für on-device Transkription.</string>`

- [ ] **Step 7: Notification.Name String anpassen**

In `Kirjo/Settings/SettingsView.swift` Zeile ~42:
- `Notification.Name("notika.hotkey.config.changed")` → `Notification.Name("kirjo.hotkey.config.changed")`
(Falls Step 2 das nicht automatisch getroffen hat — verify mit grep.)

- [ ] **Step 8: Verifikation gesamt**

Run:
```bash
grep -rn "notika" Kirjo/ Packages/ --include="*.swift" --include="*.plist" -i | grep -v "KirjoApp\|NotikaApp" | head -20
```
Expected: leer (oder nur harmlose Kommentare in Test-Fixtures). Jede übrige Fundstelle prüfen.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "refactor(rebrand): Logger-Subsystems + UserDefaults-Keys + String-Literals → Kirjo"
```

---

## Task 6: project.yml anpassen

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Lese aktuelle project.yml und plane Ersetzungen**

Lies `project.yml` komplett. Folgende Stellen sind zu ändern:
- `name: Notika` → `name: Kirjo`
- `bundleIdPrefix: com.notika` → `bundleIdPrefix: ai.kirjo` (bzw. `com.kirjo`)
- `packages:` alle 6 Einträge: `NotikaX:` + `path: Packages/NotikaX` → `KirjoX:` + `path: Packages/KirjoX`
- `targets: Notika:` → `targets: Kirjo:`
- `sources: - path: Notika` → `- path: Kirjo`
- `excludes: "Resources/Info.plist"` bleibt
- `excludes: "Resources/Notika.entitlements"` → `"Resources/Kirjo.entitlements"`
- `info: path: Notika/Resources/Info.plist` → `path: Kirjo/Resources/Info.plist`
- `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` Strings auf "Kirjo" anpassen
- `entitlements: path: Notika/Resources/Notika.entitlements` → `path: Kirjo/Resources/Kirjo.entitlements`
- `dependencies:` alle `- package: NotikaX` + `product: NotikaX` → `KirjoX`
- `PRODUCT_BUNDLE_IDENTIFIER: com.notika.mac` → `ai.kirjo.mac` (bzw. `com.kirjo.mac`)
- `PRODUCT_NAME: Notika` → `PRODUCT_NAME: Kirjo`

- [ ] **Step 2: Replace durchführen**

Edit `project.yml` mit dem Edit-Tool. Ein einziges strukturelles Replace (falls sicher):
```bash
sed -i '' 's/Notika/Kirjo/g; s/com\.notika/ai.kirjo/g; s/com\.kirjo/ai.kirjo/g' project.yml
```
(Der letzte Replace ist idempotent — kehrt nichts um.)

**Falls Bundle-ID `com.kirjo.mac` gewünscht:** stattdessen
```bash
sed -i '' 's/Notika/Kirjo/g; s/com\.notika/com.kirjo/g' project.yml
```

Verify:
```bash
grep -i "notika" project.yml
```
Expected: leer.

- [ ] **Step 3: Syntax-Check project.yml**

Run (xcodegen validiert beim Generieren, aber ein Trockenlauf hilft):
```bash
xcodegen --spec project.yml --only-plists 2>&1 | head -20
```
Expected: keine Parse-Fehler. Falls xcodegen nicht installiert → Step überspringen, nächster Task generiert.

- [ ] **Step 4: Commit**

```bash
git add project.yml
git commit -m "refactor(rebrand): project.yml Notika → Kirjo + Bundle-ID"
```

---

## Task 7: Xcode-Projekt regenerieren

**Files:**
- Delete: `Notika.xcodeproj/`
- Create: `Kirjo.xcodeproj/` (via xcodegen)

- [ ] **Step 1: Altes Xcode-Projekt entfernen**

Run:
```bash
git rm -rf Notika.xcodeproj
```
Expected: mehrere `rm`-Zeilen.

- [ ] **Step 2: xcodegen neu ausführen**

Run:
```bash
xcodegen generate
```
Expected: `⚙️  Generating project...` + `Created project at ...Kirjo.xcodeproj`
Falls xcodegen nicht installiert:
```bash
brew install xcodegen
```

- [ ] **Step 3: Neues Projekt verifizieren**

Run: `ls -d *.xcodeproj`
Expected: `Kirjo.xcodeproj`
Run: `ls Kirjo.xcodeproj/`
Expected: `project.pbxproj xcshareddata` etc.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore(rebrand): Xcode-Projekt regeneriert (Notika.xcodeproj → Kirjo.xcodeproj)"
```

---

## Task 8: Clean Build + Smoketest

**Files:** keine (Build-Verifikation)

- [ ] **Step 1: DerivedData löschen**

Run:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/Notika-* ~/Library/Developer/Xcode/DerivedData/Kirjo-*
```
Expected: kein Output.

- [ ] **Step 2: Debug-Build über CLI**

Run:
```bash
xcodebuild -project Kirjo.xcodeproj -scheme Kirjo -configuration Debug build 2>&1 | tail -30
```
Expected: `** BUILD SUCCEEDED **` am Ende.
Falls Fehler → Fehlermeldung analysieren, zurück zum passenden Task.

- [ ] **Step 3: Release-Build**

Run:
```bash
xcodebuild -project Kirjo.xcodeproj -scheme Kirjo -configuration Release build 2>&1 | tail -30
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Unit-Tests (KirjoCore) ausführen**

Run:
```bash
cd Packages/KirjoCore && swift test 2>&1 | tail -20
```
Expected: `Test Suite ... passed` bzw. alle Tests grün.
Falls Fehler → oft UserDefaults-Key-Mismatch in Tests (Task 5, Step 3 prüfen).

Zurück zum Project-Root: `cd -`

- [ ] **Step 5: App launchen + Hotkey-Smoketest**

Run:
```bash
bash scripts/run.sh 2>&1 | tail -10
```
(Oder falls `scripts/run.sh` noch auf `Notika` verweist → erst Task 10 machen.)

**User-Interaktion:**
- App startet unter Namen "Kirjo"?
- Menüleisten-Icon sichtbar?
- Hotkey (Fn gedrückt halten) → Overlay erscheint + Diktat läuft?
- Alle 3 Modi erreichbar?
- Onboarding-State: zeigt erneut "Hello, new user" oder merkt sich `kirjo.hasCompletedOnboarding`-Key (leer)? → Erwartung: Onboarding erscheint erneut (UserDefaults-Key ist neu). Das ist OK.

Bei Regression → STOP, mit User besprechen.

- [ ] **Step 6: Commit (falls Fixes nötig waren)**

Falls Fixes während Smoketest nötig waren:
```bash
git add -A
git commit -m "fix(rebrand): Smoketest-Fixes nach Build"
```
Andernfalls überspringen.

---

## Task 9: Scripts + README + Docs anpassen

**Files:**
- Modify: `scripts/build.sh`, `scripts/run.sh`
- Modify: `README.md`
- Modify: alle `docs/**/*.md` (außer `specs/` und `plans/` — History ist dort intentional)
- Modify: `.gitattributes`, `LICENSE` (falls Name drin)

- [ ] **Step 1: Scripts lesen + anpassen**

Lies `scripts/build.sh` und `scripts/run.sh`. Typische Stellen:
- `-project Notika.xcodeproj` → `-project Kirjo.xcodeproj`
- `-scheme Notika` → `-scheme Kirjo`
- Pfade wie `Notika.app` → `Kirjo.app`

Ersetze mit Edit-Tool.

- [ ] **Step 2: README.md + LICENSE anpassen**

Lies `README.md`. Ersetze Titel, Beschreibung, Screenshots-Pfade (falls vorhanden) Notika → Kirjo.
Lies `LICENSE`. Falls "Notika" drin → ersetzen. Copyright-Jahr prüfen.

- [ ] **Step 3: Running docs (tasks/, docs/) — textueller Rebrand**

Live-Docs (kein Rebrand in History-Dokumenten):
- `tasks/*.md` — ersetzen
- `docs/*.md` (Top-Level) — ersetzen
- `docs/superpowers/specs/` **NICHT** ersetzen (historisch korrekt!)
- `docs/superpowers/plans/` **NICHT** ersetzen (historisch korrekt!)

Run:
```bash
find docs tasks -maxdepth 2 -name "*.md" -not -path "*/specs/*" -not -path "*/plans/*" -type f 2>/dev/null
```

Für jede gefundene Datei: mit Edit-Tool oder `sed -i ''` umbenennen — aber vorsichtig. `sed` über mehrere Dateien:
```bash
find docs tasks -maxdepth 2 -name "*.md" -not -path "*/specs/*" -not -path "*/plans/*" -type f -exec sed -i '' 's/Notika/Kirjo/g' {} \;
```

Verify:
```bash
grep -rn "Notika" docs/ tasks/ --include="*.md" | grep -v "specs/\|plans/"
```
Expected: leer.

- [ ] **Step 4: build.sh/run.sh testen**

Run: `bash scripts/build.sh 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **` oder äquivalent.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs(rebrand): Scripts + README + Live-Docs auf Kirjo"
```

---

## Task 10: Final-Sweep + Regressions-Check

**Files:** alle

- [ ] **Step 1: Globaler Suchlauf nach Rest-"Notika"**

Run:
```bash
grep -rn "Notika\|notika" . --include="*.swift" --include="*.plist" --include="*.yml" --include="*.sh" --include="*.md" --exclude-dir=".git" --exclude-dir=".build" --exclude-dir="DerivedData" 2>/dev/null | grep -v "docs/superpowers/specs\|docs/superpowers/plans"
```
Expected: entweder leer ODER nur bewusste historische Treffer (Keychain-Service-IDs falls Migrations-Code existiert — siehe Spec Kapitel 3 "NICHT umzubenennen").

Für jeden unbeabsichtigten Treffer: anpassen.

- [ ] **Step 2: Finale Build-Verifikation**

```bash
xcodebuild -project Kirjo.xcodeproj -scheme Kirjo -configuration Release build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: App-Bundle-Inspektion**

Run:
```bash
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "Kirjo.app" -path "*/Release/*" | head -1)
echo "App: $BUILT_APP"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$BUILT_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$BUILT_APP/Contents/Info.plist"
```
Expected:
- `CFBundleIdentifier = ai.kirjo.mac` (bzw. `com.kirjo.mac`)
- `CFBundleName = Kirjo`

- [ ] **Step 4: Commit (falls Fixes nötig)**

```bash
git add -A
git commit -m "chore(rebrand): Final-Sweep + Verifikation"
```
Nur falls Fixes nötig.

---

## Task 11: Merge-Prep + Push

**Files:** keine

- [ ] **Step 1: Branch-Historie reviewen**

Run: `git log main..rebrand/kirjo --oneline`
Expected: ~7–10 saubere Commits (chore, refactor, docs).

- [ ] **Step 2: User-Freigabe einholen**

Zeige dem User:
- Commit-Liste aus Step 1
- Zusammenfassung: alle 11 Tasks grün, App baut + startet, Tests grün
- Frage: "Merge nach main jetzt? Strategien: `git merge --no-ff` (empfohlen, Feature-Branch-Struktur sichtbar) oder `git merge --ff-only` (linear)?"

**STOP** — warte auf Bestätigung.

- [ ] **Step 3: Merge nach main**

Nach User-Bestätigung:
```bash
git checkout main
git merge --no-ff rebrand/kirjo -m "feat(rebrand): Projekt Notika → Kirjo komplett umbenannt"
```

- [ ] **Step 4: Push**

```bash
git push origin main
git push --tags  # pre-rebrand-backup mitpushen
```
Expected: Push erfolgreich.

- [ ] **Step 5: Branch aufräumen (optional)**

```bash
git branch -d rebrand/kirjo
git push origin --delete rebrand/kirjo  # nur falls Branch remote gepusht wurde
```

---

## Task 12: Externe Aktionen (manuelle Checkliste — User führt aus)

**Files:** keine

Diese Schritte kann Claude nicht ausführen — sie erfordern Web-UI bzw. Domain-Registrar-Zugang.

- [ ] **Step 1: GitHub-Repo umbenennen**

User-Aktion:
1. Gehe zu https://github.com/flandersking/notika/settings
2. Ändere Repo-Name: `notika` → `kirjo`
3. GitHub richtet automatische Redirects ein.

Lokal (nach Rename):
```bash
git remote set-url origin git@github.com:flandersking/kirjo.git
git remote -v  # verify
git push origin main  # test
```

- [ ] **Step 2: Apple Developer Portal**

User-Aktion:
1. https://developer.apple.com/account → Identifiers
2. Neuen App-ID-Eintrag: `ai.kirjo.mac` (bzw. `com.kirjo.mac`)
3. Capabilities: Microphone, Speech, wie gehabt
4. Provisioning-Profile erstellen (Manual Signing nutzen aktuelle Settings)
5. Alten `com.notika.mac`-Eintrag vorerst nicht löschen (Fallback).

- [ ] **Step 3: Domain-Registrierung**

User-Aktion:
1. `kirjo.ai` kaufen (Primärdomain) — z.B. Namecheap, Porkbun
2. Optional: `kirjo.app`
3. DNS-Records später (noch keine Landing-Page)

- [ ] **Step 4: Memory aktualisieren**

Claude-Aktion (beim nächsten Session-Start):
- `project_kirjo.md` — Status auf "Rebrand abgeschlossen" setzen
- `fortsetzungspunkt.md` — neuen Fortsetzungspunkt für nächste Session (iOS-Entwicklung)
- `MEMORY.md` — Fortsetzungspunkt-Zeile aktualisieren

---

## Erfolgs-Kriterien (aus Spec Kapitel 6)

- [x] Build (Release) läuft ohne Warnings (Task 8+10)
- [x] App startet unter neuem Namen, Hotkeys funktionieren, alle 3 Modi OK (Task 8, Step 5)
- [x] `git log` zeigt sauberen Rebrand-Commit-Strang (Task 11, Step 1)
- [ ] Notarization + DMG erfolgreich — *nicht im Scope dieses Plans* (Sparkle/DMG-Pipeline separat)
- [ ] Sparkle-Update-Check — *nicht im Scope dieses Plans*

---

## Rollback-Plan

Falls nach Task 8 Probleme auftreten, die nicht schnell fixbar sind:
```bash
git checkout main
git branch -D rebrand/kirjo
# Sicherungs-Tag pre-rebrand-backup bleibt als Notnagel
```
main ist unberührt. Tag `pre-rebrand-backup` garantiert Rückweg.

---

## Zeitschätzung

- Task 1–5 (Source-Rename): 45–60 min
- Task 6–8 (Xcode-Gen + Build): 15–30 min (abhängig von Build-Fehlern)
- Task 9–11 (Docs + Merge): 15–20 min
- Task 12 (extern): 15–30 min (User)

**Gesamt: 90–140 min** (Spec schätzt 2–3h — realistisch).
