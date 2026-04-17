# Notika — Status

> Letzte Aktualisierung: **2026-04-17 22:23** (Ende Tag 1)

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
