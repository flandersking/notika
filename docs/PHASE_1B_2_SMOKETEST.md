# Phase 1b-2 Smoketest — Whisper lokale STT

Manuelle Akzeptanz-Tests vor dem Commit „Phase 1b-2 done".

## Vorbereitung
- macOS 26 Tahoe, Apple Silicon
- Notika frisch installiert oder `defaults delete <bundle-id>` + Neustart
- Internet-Verbindung für Modell-Download

## Settings → Spracherkennung Tab
- [ ] Tab erscheint zwischen „Engines" und „Wörterbuch"
- [ ] Aktive-Picker zeigt zwei Optionen, „Whisper" disabled wenn kein Modell installiert
- [ ] Apple-Zeile zeigt „aktiv" wenn `sttEngineChoice = .apple`
- [ ] Whisper-Zeilen zeigen Größe (~80 MB / ~800 MB / ~1,5 GB) und „Laden"-Button

## Modell-Download
- [ ] „Whisper Base" Laden klicken → Progress-Bar erscheint, läuft hoch
- [ ] Während Download: „Abbrechen"-Button funktioniert, räumt Tempfiles weg
- [ ] Nach erfolgreichem Download: Confirm-Sheet erscheint („Als Standard verwenden?")
- [ ] „Ja, jetzt aktivieren" → `sttEngineChoice` = `.whisper(.base)`, Tab oben aktualisiert
- [ ] „Nein, später" → Modell installiert, aber Apple bleibt aktiv

## Disk-Space
- [ ] Künstlich Disk auf <2 GB füllen, Large-V3-Download starten → Fehler-Meldung „Nicht genug Speicherplatz"

## Diktat mit aktivem Whisper
- [ ] Mode 1 Diktat starten → Pill: Recording → Transcribing (mehrere Sekunden!) → Inserting → Text landet
- [ ] Latenz: Base ~1s, Turbo ~2-3s, Large V3 ~5-7s (auf MacBook M-Serie)
- [ ] Mode 2/3 funktionieren ebenfalls
- [ ] Auto-Detect: deutsches Audio → deutsches Transkript, englisches Audio → englisches Transkript

## Whisper-Fehler-Fallback
- [ ] Aktives Modell extern löschen (`rm -rf ~/Library/Application\ Support/Notika/WhisperModels/openai_whisper-base/`)
- [ ] Diktat starten → Pill „Whisper-Modell nicht geladen" orange → automatisch mit Apple weiter, Text landet trotzdem
- [ ] `sttEngineChoice` bleibt auf `.whisper(.base)` (nicht auto-rückgesetzt)

## Modell-Löschen
- [ ] „Löschen" auf Turbo (aktiv) → Confirm-Dialog → Bestätigen → Modell-Verzeichnis weg
- [ ] Aktive-Picker zeigt jetzt Apple aktiv (Auto-Switch)

## Persistenz
- [ ] App neustarten → letzte STT-Wahl wird wiederhergestellt
- [ ] Installierte Modelle erscheinen wieder als „installiert"

## Sicherheit
- [ ] Console-Logs prüfen (`log stream --predicate 'subsystem == "com.notika.mac" AND category == "Whisper"'`):
  - Modell-IDs, Latenz, Audio-Längen sichtbar
  - Audio-Daten, Transkript-Inhalt NICHT sichtbar
- [ ] Modell-Dateien im Finder sichtbar in `~/Library/Application Support/Notika/WhisperModels/`

## Build
- [ ] Build SUCCEEDED, signiert mit Team P7QK554EET
- [ ] NotikaWhisper-Source enthält keinen `import AppKit` (iOS-Tauglichkeit)

## Tests
- [ ] `cd Packages/NotikaCore && swift test` — alle grün
- [ ] `cd Packages/NotikaWhisper && swift test` — alle grün
- [ ] `cd Packages/NotikaPostProcessing && swift test` — alle grün
