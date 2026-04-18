# Notika Phase 1b-3 — SwiftData-Dictionary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement. Steps use checkbox syntax.

**Goal:** User-editierbares Wörterbuch mit SwiftData-Persistenz + CSV-Import/Export + Live-Filter, das Hints an STT-Engines weiterreicht.

**Architecture:** `DictionaryTerm` als SwiftData-Model in NotikaCore. `DictionaryStore` in NotikaDictionary-Package ersetzt den Phase-1a-Stub, implementiert das bestehende `DictionaryStoring`-Protokoll und bietet CSV I/O. UI-Tab in App-Target mit Table + EditSheet. Coordinator fragt Hints pro Diktat ab.

**Tech Stack:** Swift 6.3 strict concurrency, SwiftData, SwiftUI Table, XCTest.

**Spec:** `docs/superpowers/specs/2026-04-18-notika-phase-1b-3-dictionary-design.md`

---

## File Structure

**Erstellt:**
- `Packages/NotikaCore/Sources/NotikaCore/Models/DictionaryCategory.swift`
- `Packages/NotikaCore/Sources/NotikaCore/Models/DictionaryTerm.swift` (SwiftData @Model)
- `Packages/NotikaCore/Tests/NotikaCoreTests/DictionaryCategoryTests.swift`
- `Packages/NotikaDictionary/Sources/NotikaDictionary/DictionaryError.swift`
- `Packages/NotikaDictionary/Sources/NotikaDictionary/DictionaryCSV.swift`
- `Packages/NotikaDictionary/Sources/NotikaDictionary/DictionaryHintsCache.swift`
- `Packages/NotikaDictionary/Tests/NotikaDictionaryTests/DictionaryStoreTests.swift`
- `Packages/NotikaDictionary/Tests/NotikaDictionaryTests/DictionaryCSVTests.swift`
- `Notika/Settings/DictionaryEditSheet.swift`

**Modifiziert:**
- `Packages/NotikaDictionary/Package.swift` (Test-Target + Dependencies)
- `Packages/NotikaDictionary/Sources/NotikaDictionary/DictionaryStore.swift` (Stub → echte Impl)
- `Notika/Settings/SettingsView.swift` (Dictionary-Tab wird echt)
- `Notika/DictationCoordinator.swift` (Hints aus DictionaryStore)

---

## Task 1: NotikaCore-Datenmodell

**Files:** DictionaryCategory.swift, DictionaryTerm.swift + Tests

- [ ] Test schreiben: `DictionaryCategoryTests` mit displayName-Checks für alle 5 Cases
- [ ] `DictionaryCategory.swift` mit 5 Cases (general/names/companies/medical/technical) + displayName
- [ ] `DictionaryTerm.swift` als `@Model` mit `term, languageRawValue, categoryRawValue, createdAt, updatedAt` + convenience init
- [ ] `swift test --filter DictionaryCategoryTests` → grün
- [ ] Build grün
- [ ] Commit: `Phase 1b-3 #1: NotikaCore DictionaryCategory + DictionaryTerm @Model`

## Task 2: NotikaDictionary — Store + CSV + HintsCache

**Files:** Package.swift modifications, DictionaryStore.swift (ersetzen), DictionaryError.swift, DictionaryCSV.swift, DictionaryHintsCache.swift + Tests

- [ ] `Package.swift` erweitern: Test-Target `NotikaDictionaryTests`
- [ ] `DictionaryError.swift` mit cases `.csvMalformed(line:, reason:)`, `.fileReadFailed`, `.fileWriteFailed` + userFacingMessage + CustomStringConvertible (kein Body-Leak)
- [ ] `DictionaryHintsCache.swift` — `Sendable`-Wrapper um `[Language: [String]]`-Snapshot, thread-safe via `NSLock`, von Store aktualisiert
- [ ] `DictionaryStore.swift` ersetzen: `@MainActor @Observable`-class mit `ModelContainer`-Injection, CRUD-Methoden (add/update/delete/allTerms/terms(language:)/terms(category:)), `hintsForLanguage` delegiert an Cache (nonisolated-fähig), Limit auf 100 neueste
- [ ] `DictionaryCSV.swift` mit `exportCSV(to:terms:)` und `importCSV(from:) throws -> [CSVRow]`-Funktionen (UTF-8 + Latin-1 Fallback, Semikolon-bevorzugt, Komma-Fallback, Header-Zeile Pflicht)
- [ ] Tests schreiben:
  - Store: add/allTerms, filter by language, filter by category, delete, deleteAll, hintsForLanguage liefert max 100, updatedAt-Sort
  - CSV: export-import-roundtrip, malformed lines → error-count + skipped, encoding-fallback
- [ ] `swift test` → alle grün (mindestens 10 neue Tests)
- [ ] Build grün
- [ ] Commit: `Phase 1b-3 #2: DictionaryStore SwiftData + CSV I/O + HintsCache`

## Task 3: App-UI — DictionaryTab + Table + EditSheet

**Files:** Notika/Settings/DictionaryTab.swift (ersetzen), DictionaryEditSheet.swift (neu)

- [ ] `DictionaryEditSheet.swift` — SwiftUI-Sheet mit TextField (Begriff), Picker (Sprache DE/EN), Picker (Kategorie 5 Cases), „Abbrechen"/„Speichern"-Buttons. Callback `onSave(term, language, category)`.
- [ ] `DictionaryTab.swift` komplett ersetzen (aktuell ist ein Stub in SettingsView.swift eingebettet):
  - Such-Feld oben (live-Filter auf `term`)
  - Sprach-Filter Picker (Alle/DE/EN)
  - Kategorie-Filter Picker (Alle + 5 Cases)
  - Action-Bar: „+ Neu" Button, „CSV importieren…", „CSV exportieren…", Count-Label
  - `Table` mit Columns: Begriff, Sprache, Kategorie, Aktionen (Bearbeiten / Löschen)
  - EditSheet wird per State präsentiert
  - CSV-Importeur: `NSOpenPanel`, parst via `DictionaryCSV`, zeigt Toast mit „X importiert, Y übersprungen"
  - CSV-Exporteur: `NSSavePanel`, schreibt via `DictionaryCSV`
- [ ] `SettingsView.swift`: den `DictionaryTab`-Stub (falls inline) entfernen, der neue echte `DictionaryTab` wird referenziert
- [ ] Build grün — manueller UI-Test (klick durch, add/edit/remove, CSV-roundtrip)
- [ ] Commit: `Phase 1b-3 #3: DictionaryTab UI mit Table + EditSheet + CSV Import/Export`

## Task 4: Coordinator-Integration — Hints an STT

**Files:** DictationCoordinator.swift

- [ ] DictionaryStore als Property ergänzen: `private let dictionaryStore = DictionaryStore()`
- [ ] In `runPipeline(mode:audioURL:)`: **vor** dem `engine.transcribe(...)`-Call Hints abfragen:
  ```swift
  let hints = self.dictionaryStore.hintsForLanguage(.german)
  let transcript = try await engine.transcribe(audio: .file(audioURL), language: .german, hints: hints)
  ```
  (ersetzt das bisherige `hints: []`)
- [ ] Fallback-Apple-Call (im `catch WhisperError`-Branch) bekommt ebenfalls `hints: hints`
- [ ] Build grün — manueller Test mit einem bekannten Fachwort im Dictionary (z.B. „Mdymny" eintragen, diktieren, STT sollte es jetzt richtig erkennen — zumindest mit höherer Chance)
- [ ] Commit: `Phase 1b-3 #4: Coordinator reicht Dictionary-Hints an STT-Engines weiter`

## Task 5: Smoketest-Doku + Merge + Push

**Files:** docs/PHASE_1B_3_SMOKETEST.md (neu), docs/STATUS.md

- [ ] `docs/PHASE_1B_3_SMOKETEST.md` mit Checkliste: Tab erscheint, Add/Edit/Delete, Filter, CSV-Roundtrip, Hints-Effekt, Persistenz, Sicherheit
- [ ] `docs/STATUS.md` updaten: neue Sektion oben „Phase 1b-3 abgeschlossen (2026-04-18)"
- [ ] Alle Tests grün: NotikaCore + NotikaDictionary + NotikaWhisper + NotikaPostProcessing
- [ ] Commit: `Phase 1b-3 #5: Smoketest-Doku + Status-Update`
- [ ] Merge auf main (fast-forward) + Push zu origin
