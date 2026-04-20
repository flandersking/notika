# Kirjo

Eine macOS-Diktier-App, die Sprache in Text umwandelt und ihn in jede fokussierte Anwendung einfügt. Konzipiert mit drei klar getrennten Modi (1:1, Social Media, Formell), austauschbaren Engines (Apple-nativ oder whisper.cpp / Anthropic Claude) und einer späteren Erweiterung für medizinische Dokumentation.

> **Status:** In aktiver Entwicklung. Kein veröffentlichter Release. Siehe [`docs/PLAN.md`](docs/PLAN.md) für den Entwicklungsplan.

## Features (geplant)

- Menüleisten-App, kein Dock-Icon
- Drei Diktier-Modi mit eigenen Hotkeys:
  - **Modus 1 — Literal:** 1:1-Transkription mit Smart Punctuation
  - **Modus 2 — Social:** Transkript mit Emojis (für Social Media)
  - **Modus 3 — Formell:** E-Mail-taugliche Umformulierung
- Floating Pill mit Waveform während der Aufnahme
- Push-to-Talk **oder** Toggle (pro Modus wählbar)
- Text wird in die fokussierte App eingefügt **und** in die Zwischenablage kopiert
- Sprachen: Deutsch und Englisch
- Custom Dictionary (eigene Begriffe, Firmennamen, später: Medizin)
- Zwei austauschbare Speech-to-Text-Engines:
  - Apple `SpeechAnalyzer` (on-device, macOS 26+)
  - whisper.cpp mit downloadbaren Modellen (Large V3 Turbo, Medium, Small)
- Zwei austauschbare Post-Processing-Engines:
  - Apple Foundation Models (on-device)
  - Anthropic Claude API (BYOK, Haiku 4.5 / Sonnet 4.6 / Opus 4.7)

## Systemvoraussetzungen

- macOS 26.0 Tahoe oder neuer
- Apple Silicon (M1 oder neuer)
- Xcode 16+ und Swift 6.3+ zum Bauen

## Setup

```bash
# Repository klonen
git clone <url>
cd 2604_sag_macos

# Xcode-Projekt generieren
xcodegen generate

# In Xcode öffnen
open Kirjo.xcworkspace
```

## Projekt-Struktur

```
Kirjo.xcworkspace
├── Kirjo/                          # App-Target
└── Packages/
    ├── KirjoCore/                  # Plattform-neutrale Kernlogik
    ├── KirjoTranscription/         # Apple SpeechAnalyzer Engine
    ├── KirjoPostProcessing/        # Foundation Models + Anthropic
    ├── KirjoDictionary/            # Custom-Dictionary-Store
    ├── KirjoWhisper/               # whisper.cpp Bridge (später)
    └── KirjoMacOS/                 # AppKit-spezifisch
```

## Lizenz

MIT. Siehe [`LICENSE`](LICENSE).
