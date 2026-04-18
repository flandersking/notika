# Notika — Phase 1b-3 Design: SwiftData-Dictionary

**Stand:** 2026-04-18
**Vorgänger:** Phase 1b-2 (Whisper-STT, abgeschlossen + gemerged)
**Folge-Phasen:**
- Phase 1b-4 — Toggle-Trigger-Modus
- Phase 1b-5 — Sparkle Auto-Update
- Phase 1b-6 — Modifier-only Hotkeys

## 1. Ziel & Scope

User-editierbare Liste mit Fachbegriffen / Eigennamen, die als Hint an die STT-Engines gehen. Verbessert Erkennung von z.B. „Mdymny" statt „M Dimni", Produktnamen, Fachvokabular.

**User-Entscheidungen (aus Brainstorming):**
- **A1:** Fester Kategorien-Satz (`general`, `names`, `companies`, `medical`, `technical`)
- **B1:** Keine Prioritäten — alle Terms gleich wichtig
- **C1:** Leer starten — kein Seed-Data

**Ziel-Features:**
- Settings-Tab „Wörterbuch" mit Tabelle
- CRUD: Add / Edit / Remove per UI
- CSV Import + Export
- Sprach-Filter (Alle/DE/EN) + Kategorie-Filter + Such-Feld
- Hints-Export an STT-Engines über `DictionaryStoring`-Protokoll

## 2. Datenmodell

### DictionaryCategory (NotikaCore)

```swift
public enum DictionaryCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case general    = "general"
    case names      = "names"
    case companies  = "companies"
    case medical    = "medical"
    case technical  = "technical"

    public var displayName: String {
        switch self {
        case .general:    return "Allgemein"
        case .names:      return "Namen"
        case .companies:  return "Firmen"
        case .medical:    return "Medizin"
        case .technical:  return "Technik"
        }
    }
}
```

### DictionaryTerm (NotikaCore SwiftData)

```swift
@Model
public final class DictionaryTerm {
    public var term: String
    public var languageRawValue: String              // speichert Language.rawValue
    public var categoryRawValue: String              // speichert DictionaryCategory.rawValue
    public var createdAt: Date
    public var updatedAt: Date

    public init(term: String, language: Language, category: DictionaryCategory)

    public var language: Language? { Language(rawValue: languageRawValue) }
    public var category: DictionaryCategory? { DictionaryCategory(rawValue: categoryRawValue) }
}
```

### DictionaryStore (NotikaDictionary)

Ersetzt das bestehende `InMemoryDictionaryStore`-Stub. Implementiert das bereits vorhandene `DictionaryStoring`-Protokoll.

```swift
@MainActor
public final class DictionaryStore: DictionaryStoring {
    public let container: ModelContainer

    public init(container: ModelContainer? = nil)
    public func allTerms() -> [DictionaryTerm]
    public func terms(language: Language?) -> [DictionaryTerm]
    public func terms(category: DictionaryCategory?) -> [DictionaryTerm]
    public func addTerm(_ term: String, language: Language, category: DictionaryCategory)
    public func updateTerm(_ entry: DictionaryTerm, newTerm: String, newLanguage: Language, newCategory: DictionaryCategory)
    public func deleteTerm(_ entry: DictionaryTerm)
    public func deleteAll()

    // Protokoll-Erfüllung (existiert aus Phase 1a)
    public nonisolated func hintsForLanguage(_ language: Language) -> [String]

    // CSV I/O
    public func importCSV(from url: URL) throws -> Int      // liefert Anzahl importierte Terms
    public func exportCSV(to url: URL) throws
}
```

**Wichtig:** `hintsForLanguage` muss `nonisolated` sein, weil STT-Engines es aus Background-Threads rufen. Implementation nutzt einen lokalen in-memory-Cache der letzten bekannten Terms, der bei Änderungen via SwiftData-Observer aktualisiert wird. Alternativ: einen kleinen Snapshot-Cache in `UserDefaults` halten, damit auch beim App-Start sofort Hints verfügbar sind.

## 3. Hint-Integration in STT-Engines

### Apple SpeechAnalyzer
Nutzt `contextualStrings` auf `SFSpeechRecognitionRequest`. Limit erfahrungsgemäß ~100 Strings ohne Performance-Einbruch.

### WhisperKit
Nutzt `initial_prompt` via `DecodingOptions`. Max ~224 Tokens (WhisperKit-intern). Für einen deutschen Satz wie „Mdymny, Notika, WhisperKit" sind das schnell 30-50 Terms möglich.

### Coordinator-Flow

```swift
let hints = dictionaryStore.hintsForLanguage(.german)
let transcript = try await engine.transcribe(audio: ..., language: .german, hints: hints)
```

Der Coordinator holt Hints basierend auf `settings.defaultLanguage` (aktuell immer `.german`, Phase 1b-3 ändert das nicht).

**Limit-Strategie:** Wenn `hintsForLanguage` mehr Terms liefert als die Engine effektiv nutzen kann (Apple ~100, Whisper je nach Token-Länge), **nimmt der Store nur die letzten 100 zurück, sortiert nach `updatedAt DESC`**. Gibt dem User implizite Priorität über „aktuell bearbeiten = wichtig". Explizite Prioritäten (Wahl B1 = kein).

## 4. UI

### Settings-Tab „Wörterbuch" (Redesign des Stubs)

```
══ Wörterbuch ═════════════════════════════════════════════════════
  [ Suchen…                    ]  Sprache: [Alle ▼]  Kategorie: [Alle ▼]
  [+ Neu]  [CSV importieren…]  [CSV exportieren…]        42 Einträge

  ┌─────────────────────────────────────────────────────────────┐
  │ Begriff           │ Sprache  │ Kategorie  │ Aktionen        │
  ├─────────────────────────────────────────────────────────────┤
  │ Mdymny            │ DE       │ Namen      │ Bearbeiten Del  │
  │ WhisperKit        │ DE       │ Technik    │ Bearbeiten Del  │
  │ Arztbrief         │ DE       │ Medizin    │ Bearbeiten Del  │
  │ ...                                                          │
  └─────────────────────────────────────────────────────────────┘
```

**Edit/Neu-Sheet:**

```
┌─── Eintrag bearbeiten ──────┐
│  Begriff:   [WhisperKit    ]│
│  Sprache:   [Deutsch      ▼]│
│  Kategorie: [Technik      ▼]│
│                             │
│  [ Abbrechen ]   [ Speichern ]│
└─────────────────────────────┘
```

### CSV-Format

Zwei Spalten minimum, Semikolon-separiert (Excel-kompatibel in DE):

```
term;language;category
Mdymny;de;names
WhisperKit;de;technical
Arztbrief;de;medical
```

Import akzeptiert auch Komma-separiert als Fallback. Erste Zeile muss Header sein (`term;language;category`). Sprache als ISO-Code (`de`/`en`). Unbekannte Kategorien → `general`.

## 5. Package-Struktur

```
Packages/NotikaCore/Sources/NotikaCore/
├── Models/
│   ├── DictionaryCategory.swift           # NEU
│   └── DictionaryTerm.swift               # NEU (SwiftData @Model)

Packages/NotikaDictionary/Sources/NotikaDictionary/
├── DictionaryStore.swift                  # ERSETZT Stub — SwiftData-Implementation
├── DictionaryCSV.swift                    # NEU — Import/Export-Helpers
└── DictionaryHintsCache.swift             # NEU — nonisolated-Snapshot für STT-Hints

Notika/Settings/
├── DictionaryTab.swift                    # ERSETZT Stub
├── DictionaryTable.swift                  # NEU — Table-View mit Spalten
└── DictionaryEditSheet.swift              # NEU — Add/Edit-Sheet
```

## 6. Fehlerbehandlung

`DictionaryError` in NotikaDictionary:
- `.csvMalformed(line: Int, reason: String)` — bei Import
- `.fileReadFailed` / `.fileWriteFailed`

Import-Verhalten: Einzelne Zeilen mit Fehlern **werden übersprungen** (nicht Gesamt-Abort), aber am Ende zeigt die UI „42 importiert, 3 übersprungen (Zeile 15, 28, 41)". Details in Console-Log (ohne Term-Inhalte — nur Zeilennummern).

## 7. Sicherheit & Privacy

- **SwiftData-DB** liegt im App-Container, offline.
- **Logging:** Nur Zählwerte (Anzahl Terms, Anzahl Hints), niemals Term-Inhalte.
- **CSV-Import:** User-kontrolliert, keine externen URLs erlaubt.
- **Hints an Cloud-STT:** Phase 1b-3 hat keine Cloud-STT (Phase 1b-2 Whisper ist lokal). Aber Apple SpeechAnalyzer läuft on-device. Falls Phase 2 Cloud-STT bekommt: Hints würden dorthin geschickt — das ist akzeptabel, weil User-kontrolliert.

## 8. Tests

### Unit-Tests (XCTest, `NotikaDictionaryTests` — neues Test-Target)

- `DictionaryStore.addTerm` / `allTerms` — Grundoperationen
- `DictionaryStore.terms(language:)` / `terms(category:)` — Filter
- `DictionaryStore.deleteTerm` / `deleteAll`
- `DictionaryStore.hintsForLanguage(.german)` — liefert nur deutsche Terms, max 100
- `DictionaryCSV.export` + reimport-roundtrip
- `DictionaryCSV.import` mit fehlerhaften Zeilen → skips + Error-Count
- `DictionaryTerm` Codable-/SwiftData-Init

NotikaCore-Tests:
- `DictionaryCategory.displayName` für alle Cases
- `DictionaryTerm.init` + `language`/`category`-Lookup (Phase 1b-3-Test nicht nötig, weil SwiftData-Modell — wird in NotikaDictionaryTests getestet)

## 9. Akzeptanzkriterien

- ✅ Settings → „Wörterbuch"-Tab zeigt Tabelle mit sortierbaren Spalten
- ✅ Add/Edit/Remove per UI funktioniert
- ✅ Kategorie-Filter + Sprach-Filter + Such-Feld filtern live
- ✅ CSV Import + Export funktionieren (roundtrip erhält alle Einträge)
- ✅ `hintsForLanguage(.german)` liefert aktuelle deutsche Terms
- ✅ Apple SpeechAnalyzer + Whisper bekommen Hints (via DictationCoordinator)
- ✅ Persistierung: Terms überleben App-Restart
- ✅ Build SUCCEEDED, alle Tests grün

## 10. Out of Scope

- Prioritäten / Gewichtungen (Wahl B1)
- Seed-Data beim ersten Start (Wahl C1)
- Cloud-Sync (iCloud CoreData — kein Ziel für lokale App)
- Sprach-Varianten (z.B. de-CH vs. de-DE) — nur zwei Sprachen
- Konflikt-Detection (zwei Terms identisch) — erlaubt, löst oft keine Probleme
- Pronunciation-Hints / Phonetik
- Auto-Learn aus Diktat-Korrekturen (Phase 2?)

## 11. Subagent-Strategie

| Subagent | Verantwortung |
|---|---|
| `impl-dict-core` | NotikaCore-Modelle (DictionaryTerm + Category) + Tests |
| `impl-dict-store` | NotikaDictionary SwiftData-Store + CSV + Tests |
| Hauptkontext | UI (DictionaryTab + Table + EditSheet) + Coordinator-Integration |

## 12. Risiken

- **SwiftData + `nonisolated` Hints-Access:** SwiftData-Models sind nicht trivial thread-safe. Lösung: `DictionaryHintsCache` als separater `@unchecked Sendable` Snapshot-Provider, der bei Store-Änderungen via einfachem Publisher aktualisiert wird.
- **CSV-Encoding:** macOS `String(contentsOf:encoding:)` default UTF-8. Excel-exportierte CSVs sind manchmal Latin-1 / Windows-1252 — Fallback-Encoding beim Import einplanen.
- **Große Dictionary-Files:** Wenn User 10.000+ Terms importiert: SwiftData-Insert könnte lang dauern. Für MVP OK, später evtl. batch-insert.
