# Notika — Status

> Letzte Aktualisierung: **2026-04-18** (Phase 1b-3 abgeschlossen)

## Phase 1b-3 abgeschlossen (2026-04-18)

- SwiftData-Dictionary für STT-Hints implementiert
- 5 feste Kategorien: Allgemein, Namen, Firmen, Medizin, Technik
- Settings-Tab „Wörterbuch" mit Table, Add/Edit/Remove, Such- und Filter-UI
- CSV Import + Export (UTF-8 + Latin-1-Fallback, quote-aware Parser)
- `DictionaryHintsCache` (thread-safer NSLock-Wrapper) → `nonisolated hintsForLanguage` für STT-Engines
- DictationCoordinator reicht Hints an Apple SpeechAnalyzer und WhisperKit weiter
- Limit 100 Hints pro Sprache (neueste via updatedAt)
- 94 Tests grün (30 NotikaCore + 19 NotikaDictionary + 15 NotikaWhisper + 30 NotikaPostProcessing)
- Build SUCCEEDED

Nächste Sub-Phase: 1b-6 (Modifier-only Hotkeys) oder 1b-4 (Toggle-Trigger-Modus) oder 1b-5 (Sparkle)

## Phase 1b-2 abgeschlossen (2026-04-18)

- WhisperKit (0.18.0) als SPM-Dependency in NotikaWhisper
- 3 kuratierte Whisper-Modelle (Base / Turbo / Large V3) downloadbar
- Eigener Settings-Tab „Spracherkennung" mit Engine-Picker + Modell-Liste
- Confirm-Sheet nach Download („Als Standard verwenden?")
- Auto-Sprach-Detection (Deutsch/Englisch)
- Auto-Fallback auf Apple SpeechAnalyzer bei Whisper-Fehler
- 100 % offline nach Modell-Download (DSGVO-Story für Phase 2)
- iOS-tauglich (kein AppKit in NotikaWhisper)
- 71 Tests grün (26 NotikaCore + 15 NotikaWhisper + 30 NotikaPostProcessing)
- Build SUCCEEDED

Nächste Sub-Phase: 1b-3 (SwiftData-Dictionary)

## Phase 1b-1 abgeschlossen (2026-04-18)

- 4 LLM-Provider als BYOK: Anthropic, OpenAI, Google, Ollama
- Hybrid-Wahl (global + Pro-Modus-Override) funktional
- Cost-Indikator im Menübar (Tag/Monat)
- API-Keys in Keychain
- 1× Retry → Rohtext-Fallback bei API-Fehler
- Migration vom Phase-1a-Default sauber
- Onboarding-Step + First-Use-Hint
- Pill-Fehler-State (orange) für KI-Helfer-Offline
- 43 Unit-Tests (14 NotikaCore + 29 NotikaPostProcessing) grün
- Build SUCCEEDED, signiert mit Team P7QK554EET

Nächste Sub-Phase: 1b-2 (whisper.cpp lokale STT)

## Was bisher funktioniert

**Phase 1a ist komplett.** Alle acht geplanten Bausteine laufen:

1. ✅ Xcode-Workspace mit 6 Swift Packages, stabile Signatur mit Apple Development Certificate (Team `P7QK554EET`)
2. ✅ Onboarding-Flow mit Permissions-Prompts (Mikrofon, Spracherkennung, Bedienungshilfen) + 1-Sek-Polling
3. ✅ HotkeyManager (`sindresorhus/KeyboardShortcuts`) + AudioRecorder (`AVAudioEngine`, natives Format) + Floating Pill (NSPanel, Waveform, Zustände)
4. ✅ Apple SpeechAnalyzer-Engine — Deutsch/Englisch on-device
5. ✅ Apple Foundation Models Engine (optional, 3B, halluziniert bei komplexen Umformulierungen)
6. ✅ TextInserter mit Accessibility-API + Clipboard-Cmd-V-Fallback
7. ✅ DictationCoordinator State-Machine — End-to-End
8. ✅ Settings-Fenster mit Tabs: Allgemein, Kurzbefehle, **Modi (User-editierbare Prompts!)**, **Engines (LLM-Auswahl!)**, Wörterbuch-Stub, Über

## Aktuelle Settings-Defaults

- LLM: **Kein LLM — Rohtranskript** (bewusst, weil Foundation Models 3B zu schwach ist)
- Prompts: meine drei Defaults in `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Prompts/`
- Sprache: Deutsch
- Trigger: Push-to-Talk

## Ausstehend — Phase 1b

Priorität 1: **Drei LLM-Provider als BYOK parallel einbauen** (Claude, OpenAI, Google). Der User hat das am 17.04.2026 explizit gefordert — nicht nur Anthropic.

Siehe `phase_1b_backlog.md` in der Memory für die volle Liste.

## Kritische Erkenntnisse aus Tag 1

- **Swift-6-Concurrency bricht** bei Callbacks vom Background-Thread in `@MainActor`-Klassen (SpeechRecognizer, AVAudioEngine-Tap). Fix: `nonisolated`-Helper oder ganze Klasse nicht-isolieren.
- **Apple SpeechAnalyzer** braucht Audio im nativen Input-Format (48 kHz), nicht 16 kHz — sonst stiller Fail mit 0 Results.
- **Ad-hoc-Signaturen** invalidieren Bedienungshilfen-Toggle bei jedem Rebuild. Developer Certificate löst das dauerhaft.
- **Foundation Models 3B halluziniert** — "Lass es uns probieren" wird zu "Ich stehe Ihnen zur Verfügung". Muss für seriöse Umformulierungen durch eine Cloud-Engine ersetzt werden.
