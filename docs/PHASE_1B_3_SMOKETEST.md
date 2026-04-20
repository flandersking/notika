# Phase 1b-3 Smoketest — SwiftData-Dictionary

Manuelle Akzeptanz-Tests vor dem Commit „Phase 1b-3 done".

## Settings → Wörterbuch-Tab
- [ ] Tab erscheint zwischen „KI" und „Verlauf" (oder an gewohnter Position)
- [ ] Leerer State: ContentUnavailableView „Noch keine Einträge"
- [ ] Toolbar oben: Suchen-Feld, Sprache-Picker (Alle/DE/EN), Kategorie-Picker (Alle + 5 Kategorien), „+ Neu"-Button, CSV-Import/Export, Anzahl-Label

## Einträge verwalten
- [ ] „+ Neu" → Sheet öffnet sich → Term + Sprache + Kategorie eingeben → Speichern → Eintrag erscheint in der Tabelle
- [ ] Doppelklick auf Zeile oder „Bearbeiten"-Button → EditSheet mit vorbelegten Werten → Änderung → Speichern → Tabelle aktualisiert
- [ ] Mülleimer-Button → Bestätigungs-Dialog → „Löschen" → Eintrag weg
- [ ] Leere Begriffe (nur Whitespace) werden beim Speichern ignoriert

## Filter
- [ ] Such-Feld filtert Terms live (case-insensitive, substring)
- [ ] Sprach-Filter: „Alle" → alle, „Deutsch" → nur DE, „Englisch" → nur EN
- [ ] Kategorie-Filter: „Alle" → alle, einzelne Kategorie → nur diese
- [ ] Kombination Filter + Suche arbeiten zusammen

## CSV Import + Export
- [ ] Export: „CSV exportieren…" → Save-Panel → .csv-Datei schreibt alle Einträge (Header + Semikolon-separiert)
- [ ] Import: einfache CSV mit 3 Zeilen → „X importiert, Y übersprungen" Toast
- [ ] Roundtrip: Export → Import einer anderen Instanz → alle Einträge da
- [ ] Malformed CSV (fehlende Spalten, unbekannte Sprache) → Zeilen werden übersprungen, nicht Gesamt-Abort
- [ ] Excel-exportierte CSV (Latin-1 Encoding) → wird trotzdem importiert

## Hints-Integration mit STT
- [ ] Eintrag „Mdymny" als Namen hinzufügen (Deutsch)
- [ ] Diktat mit Apple SpeechAnalyzer: „Ich heiße Mdymny" → Chance auf korrekte Erkennung steigt
- [ ] Diktat mit Whisper-Modell: gleicher Test → `initial_prompt` enthält Hint
- [ ] Console-Log: keine Term-Inhalte geloggt, nur Zählwerte

## Persistenz
- [ ] Einträge hinzufügen → App neustarten → Einträge sind noch da
- [ ] SwiftData-DB liegt im App-Container

## Grenzfälle
- [ ] 100+ Einträge → `hintsForLanguage` liefert max 100 (die neuesten)
- [ ] Sonderzeichen im Term (Semikolon, Anführungszeichen) → Export-Import-Roundtrip erhält sie

## Build
- [ ] Build SUCCEEDED mit Team P7QK554EET
- [ ] Alle Tests grün: KirjoCore, KirjoDictionary, KirjoWhisper, KirjoPostProcessing
