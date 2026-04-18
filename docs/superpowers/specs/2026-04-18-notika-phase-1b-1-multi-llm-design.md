# Notika — Phase 1b-1 Design: Multi-LLM-Engines (4 Provider, BYOK)

**Stand:** 2026-04-18
**Vorgängerphase:** Phase 1a (Kern End-to-End Diktier-Pipeline, abgeschlossen)
**Folge-Phasen (separate Specs):**
- Phase 1b-2 — whisper.cpp lokale STT
- Phase 1b-3 — SwiftData-Dictionary
- Phase 1b-4 — Toggle-Trigger-Modus
- Phase 1b-5 — Sparkle Auto-Update

## 1. Ziel & Scope

Notika erhält **vier auswählbare LLM-Provider** als „Bring Your Own Key" (BYOK)-Optionen für die Text-Politur (Modi Literal / Social / Formell):

1. **Anthropic Claude** — Cloud, kostenpflichtig
2. **OpenAI ChatGPT** — Cloud, kostenpflichtig (Responses-API)
3. **Google Gemini** — Cloud, kostenpflichtig
4. **Ollama** — lokaler Server auf `http://localhost:11434`, kein Key

Sowie eine **Hybrid-Wahl-Logik**: Globaler Default + optionale Pro-Modus-Overrides.

Begleitende Features:
- Optionaler Onboarding-Step für Setup
- Kuratierter Modell-Picker pro Cloud-Provider (3 Modelle), Auto-Discovery für Ollama
- Menübar-Cost-Indikator (Tag/Monat)
- First-Use-Hint bei Skip
- 1× Retry, dann Fallback auf Rohtext bei API-Fehler
- API-Keys in Keychain

**Begründung:** Phase-1a-Default „Kein LLM" wurde gewählt, weil Apple Foundation Models 3B halluziniert. Cloud-Provider lösen das. Ollama als vierte Option erschließt Privacy-First-Nutzer (insb. medizinische Zielgruppe in Phase 2 — DSGVO bei Patientendaten).

## 2. Vokabular-Konvention

Nutzeroberfläche folgt einem konsistenten Mischmodell:
- **Mutter-Klartext bei der Auswahl:** „Wer poliert deinen Text? (LLM)", „Apple (gratis, läuft auf deinem Mac)", „Claude (von Anthropic, kostenpflichtig)", „ChatGPT (von OpenAI, kostenpflichtig)", „Gemini (von Google, kostenpflichtig)", „Lokales Modell via Ollama".
- **Tech-Begriffe in Detail-Konfiguration:** Settings-Tab heißt weiterhin „Engines"; Felder „API-Key", „Modell", „Prompt", „Token / Kosten" bleiben.

Begründung: Auswahl muss niedrigschwellig sein, Detail-Konfiguration berührt nur Power-User.

## 3. Datenmodell

### 3.1 LLMChoice (NotikaCore)

```swift
public enum LLMChoice: Codable, Sendable, Hashable {
    case none
    case appleFoundationModels
    case anthropic(AnthropicModel)
    case openAI(OpenAIModel)
    case google(GoogleModel)
    case ollama(modelID: String)   // dynamisch, kein Enum
}

public enum AnthropicModel: String, Codable, CaseIterable, Sendable {
    case haiku45  = "claude-haiku-4-5"
    case sonnet46 = "claude-sonnet-4-6"
    case opus47   = "claude-opus-4-7"
}

public enum OpenAIModel: String, Codable, CaseIterable, Sendable {
    case nano54 = "gpt-5.4-nano"
    case mini54 = "gpt-5.4-mini"
    case full54 = "gpt-5.4"
}

public enum GoogleModel: String, Codable, CaseIterable, Sendable {
    case flashLite31Preview = "gemini-3.1-flash-lite-preview"
    case flash25            = "gemini-2.5-flash"
    case pro31Preview       = "gemini-3.1-pro-preview"
}
```

Display-Names der Modelle als Computed-Property im jeweiligen Enum (für Picker-Labels). Codable-Persistierung via JSON in UserDefaults statt rawString, damit das verschachtelte Enum sauber serialisiert.

### 3.2 SettingsStore-Erweiterung (NotikaCore)

```swift
@MainActor @Observable
public final class SettingsStore {
    public var globalLLMChoice: LLMChoice           // war: llmChoice
    public var modeLLMOverride: [DictationMode: LLMChoice]   // leer = nutzt global
    public var defaultLanguage: String              // unverändert

    // neue Cost-Felder, gespiegelt aus CostStore für UI-Bindings
    public var costsToday: CostSnapshot?
    public var costsMonth: CostSnapshot?
}
```

**Migration:** Bestehender Key `notika.settings.llmChoice` wird beim ersten Start migriert: `none` → `LLMChoice.none`, `appleFoundationModels` → `.appleFoundationModels`, `anthropic` (rawString aus Phase-1a-Stub) → `.appleFoundationModels` (weil kein Key vorhanden war). Anschließend wird der alte Key gelöscht. Neuer Key: `notika.settings.globalLLMChoice` (JSON-codiert).

### 3.3 CostSnapshot & CostStore (NotikaPostProcessing/Costs)

```swift
public struct CostSnapshot: Codable, Sendable {
    public let totalUSD: Double
    public let callCount: Int
    public let lastReset: Date
}

@MainActor public final class CostStore {
    public func record(provider: ProviderID, model: String,
                       tokensIn: Int, tokensOut: Int)
    public func today() -> CostSnapshot
    public func thisMonth() -> CostSnapshot
    public func resetToday()
}
```
Persistierung in UserDefaults unter `notika.costs.today.<yyyy-mm-dd>` und `notika.costs.month.<yyyy-mm>`. Tagesreset automatisch beim nächsten Call nach Tageswechsel (lokaler Kalender).

## 4. Architektur

### 4.1 Package-Struktur

```
Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/
├── PostProcessingEngineFactory.swift     ← LLMChoice → Engine-Instanz
├── FoundationModelsEngine.swift          ← unverändert
├── PromptStore.swift                     ← unverändert
├── Prompts/                              ← unverändert
├── Networking/
│   ├── LLMHTTPClient.swift               ← URLSession, Retry, Timeout 12s
│   ├── LLMError.swift                    ← typisierte Fehler
│   └── KeychainStore.swift               ← API-Keys getrennt pro Provider
├── Anthropic/
│   ├── AnthropicEngine.swift             ← PostProcessingEngine
│   ├── AnthropicRequest.swift            ← Codable
│   └── AnthropicResponse.swift
├── OpenAI/
│   ├── OpenAIEngine.swift
│   ├── OpenAIRequest.swift
│   └── OpenAIResponse.swift
├── Google/
│   ├── GoogleEngine.swift
│   ├── GoogleRequest.swift
│   └── GoogleResponse.swift
├── Ollama/
│   ├── OllamaEngine.swift                ← intern: OpenAI-Adapter mit base http://localhost:11434/v1
│   └── OllamaModelDiscovery.swift        ← GET /api/tags
└── Costs/
    ├── CostCalculator.swift              ← provider+model+tokens → USD
    ├── CostStore.swift                   ← UserDefaults-Persistierung
    └── PricingTable.swift                ← Modell-IDs → $/1M-Tokens
```

### 4.2 Engine-Protokoll (bleibt stabil aus Phase 1a)

```swift
public protocol PostProcessingEngine: Sendable {
    func process(text: String, mode: DictationMode, prompt: String)
        async throws -> ProcessedText
}

public struct ProcessedText: Sendable {
    public let text: String
    public let costUSD: Double?     // nil bei lokalen Engines
    public let tokensIn: Int?
    public let tokensOut: Int?
    public let provider: ProviderID
    public let model: String?
}

public enum ProviderID: String, Sendable {
    case none, apple, anthropic, openAI, google, ollama
}
```

### 4.3 Provider-Spezifika

| Provider | Endpoint | Auth-Header | System-Prompt-Position |
|---|---|---|---|
| Anthropic | `POST https://api.anthropic.com/v1/messages` | `x-api-key`, `anthropic-version: 2023-06-01` | Top-Level `system`-Feld |
| OpenAI | `POST https://api.openai.com/v1/responses` | `Authorization: Bearer <key>` | Im `instructions`-Feld der Responses-API |
| Google | `POST https://generativelanguage.googleapis.com/v1beta/models/<id>:generateContent` | `x-goog-api-key` | `system_instruction.parts[0].text` |
| Ollama | `POST http://localhost:11434/v1/chat/completions` | keiner | `messages[0]` mit `role: "system"` |

**Pricing-Tabelle (Stand 2026-04-18, recherchiert via WebFetch):**

| Modell-ID | Input $/1M | Output $/1M | Kontext |
|---|---|---|---|
| claude-haiku-4-5 | 1.00 | 5.00 | 200k |
| claude-sonnet-4-6 | 3.00 | 15.00 | 1M |
| claude-opus-4-7 | 5.00 | 25.00 | 1M |
| gpt-5.4-nano | 0.20 | 1.25 | 400k |
| gpt-5.4-mini | 0.75 | 4.50 | 400k |
| gpt-5.4 | 2.50 | 15.00 | 1.05M |
| gemini-3.1-flash-lite-preview | 0.25 | 1.50 | n/a |
| gemini-2.5-flash | 0.30 | 2.50 | 1M |
| gemini-3.1-pro-preview | 2.00 | 12.00 | 1M+ |
| Ollama (alle) | 0 | 0 | je nach Modell |

> Die Preise werden vor dem ersten Release manuell auf den Provider-Seiten verifiziert. Hardcoded in `PricingTable.swift`, Kommentar mit Link und Datum der Verifikation.

### 4.4 Implementierungs-Strategie

Drei Subagenten parallel für **Anthropic / OpenAI / Google**, jeweils mit gleicher Vorgabe (Engine-Protokoll, Networking-Helper, Test-Fixtures-Format). Ollama nutzt den OpenAI-Adapter mit anderer Base-URL und ohne Auth → kleiner separater Wrapper. Costs-Layer und UI baue ich im Hauptkontext, weil die UI-Updates (Onboarding-Step, Engines-Tab, Menübar) cross-cutting sind.

## 5. UI-Veränderungen

### 5.1 Onboarding-Step „KI-Helfer" (neu, nach Bedienungshilfen-Step)

```
┌──────────────────────────────────────────────────┐
│  Wer poliert deinen Text? (LLM)                  │
│  Optional — du kannst es jetzt einrichten oder   │
│  später in den Einstellungen.                    │
│                                                   │
│  ⦿ Apple (gratis, läuft auf deinem Mac)         │
│  ○ Claude (von Anthropic, kostenpflichtig)      │
│  ○ ChatGPT (von OpenAI, kostenpflichtig)        │
│  ○ Gemini (von Google, kostenpflichtig)         │
│  ○ Lokales Modell via Ollama                    │
│                                                   │
│  [Wenn Cloud-Provider: API-Key + „Testen"]       │
│  [Wenn Ollama: Modell-Picker via /api/tags]      │
│                                                   │
│  [ Überspringen ]            [ Weiter ]          │
└──────────────────────────────────────────────────┘
```

Default-Auswahl im Step: **Apple Foundation Models** (Wahl 6b).

Verhalten je nach Aktion:
- **„Weiter" mit Apple/Ollama** → `globalLLMChoice` entsprechend gesetzt, `notika.onboarding.llmStepCompleted = true`.
- **„Weiter" mit Cloud-Provider** → API-Key-Test muss grün sein, sonst inline-Fehler und Step bleibt offen. Bei Erfolg: Key in Keychain, `globalLLMChoice` gesetzt, `llmStepCompleted = true`.
- **„Überspringen"** → `globalLLMChoice = .appleFoundationModels` (Default-Wahl 6b), `llmStepCompleted = false`. Der First-Use-Hint nutzt das Flag.

### 5.2 Settings → Engines-Tab (Redesign)

```
══ Wer poliert deinen Text? (LLM) ══════════════════
  Standard für alle Modi:  [ Claude (Anthropic) ▼ ]
                                        ↓ wenn Cloud
  Modell: [ claude-haiku-4-5 (schnell, günstig) ▼ ]
  API-Key: [ sk-ant-•••••••••••• ]  [ Testen ]
                                        ↓ wenn Ollama
  Modell: [ llama3.2:latest ▼ ]  [ Aktualisieren ]
  Status: ✓ Verbunden mit localhost:11434

  ▽ Erweitert: Pro Modus überschreiben
    Modus 1 — Literal:   [ Standard ▼ ]
    Modus 2 — Social:    [ ChatGPT (gpt-5.4-mini) ▼ ]
    Modus 3 — Formell:   [ Standard ▼ ]
═══════════════════════════════════════════════════
```

Beim Wechsel des Standard-Providers klappt der Modell-Picker und das Key-Feld passend dazu.

**Ollama-Sektion:** Auto-Discovery via `GET /api/tags` mit drei möglichen Zuständen:
- **Server läuft + Modelle vorhanden:** Picker zeigt installierte Modelle, Default auf erstes mit „latest"-Tag.
- **Server läuft + keine Modelle:** Hinweis „Ollama läuft, aber keine Modelle installiert. Im Terminal: `ollama pull llama3.2`" + Aktualisieren-Button.
- **Server nicht erreichbar:** Hinweis „Ollama scheint nicht zu laufen — [Download ↗](https://ollama.com/download)" + Aktualisieren-Button.

### 5.3 Menübar-Menü (erweitert)

```
🎙️  Notika
─────────────────────────
Heute: 0,12 € · 38 Diktate
Diesen Monat: 2,40 €
─────────────────────────
   [Reset Tageszähler]
   Einstellungen…
   Beenden
```

Lokale Engines (Apple, Ollama) zählen als 0,00 €.

### 5.4 First-Use-Hint (einmalig)

Wenn `llmStepCompleted == false` und User zum ersten Mal Mode 2 oder 3 nutzt: Sheet
> „Tipp: Mit Cloud-LLM oder Ollama wird das Ergebnis deutlich besser. Jetzt einrichten?"
> [ Später ]   [ Einstellungen öffnen ]

Flag `notika.hint.llmShown = true` nach Anzeige.

### 5.5 Pill-Fehler-State (neu)

Bei API-Fehler nach Retry: Pill-Hintergrund kurz orange, Text:
> „KI-Helfer offline — Rohtext eingefügt"

Verschwindet nach 3 s. Diktat-Audio wird **nicht** persistiert.

Bei `.invalidKey`: Spezifischer Text „Schlüssel ungültig — in Einstellungen prüfen".

## 6. Fehlerbehandlung

`LLMError` typisiert in `Networking/LLMError.swift`:

```swift
public enum LLMError: Error, Sendable {
    case invalidKey
    case rateLimit(retryAfter: TimeInterval?)
    case network
    case timeout
    case serverError(status: Int, body: String)
    case invalidResponse
    case ollamaUnavailable
    case modelNotFound(String)
}
```

Flow pro Call (`LLMHTTPClient.send(_:)`):
1. Versuch 1, Timeout 12 s
2. Bei `.network` oder `.timeout` → 1× Retry nach 1 s
3. Wenn Retry scheitert oder direkt `.invalidKey` / `.rateLimit` / `.serverError` / `.modelNotFound` → keine weiteren Retries → Fallback im Coordinator auf Rohtext, Pill-Fehler-State

`DictationCoordinator` fängt `LLMError` ab und nutzt das Rohtranskript aus dem Speech-Step als Insertion-Text.

## 7. Sicherheit & Privacy

- **API-Keys in Keychain** (Service `app.notika.apikey.<provider>`, Account = leer). Keine Persistierung in UserDefaults oder Plain-Files.
- **Logging-Disziplin** (`os.Logger` Subsystem `com.notika.mac`, Categories wie `PostProcessing.HTTP`):
  - Erlaubt: Provider-Name, Modell-ID, HTTP-Status-Code, Längen (Zeichen, Tokens), Latenz.
  - Verboten: API-Keys (auch nicht teilweise), Diktat-Inhalt, Response-Bodies.
- **TLS:** Nur HTTPS für Cloud-Provider. ATS-Default ist OK. Ollama läuft per HTTP auf localhost — explizit erlaubt via `NSAllowsLocalNetworking` im Info.plist.
- **Test-Endpoint** für „Schlüssel testen"-Button: 1-Token-Ping pro Provider (minimaler Verbrauch).

## 8. Tests

### 8.1 Unit-Tests (XCTest, Target `NotikaPostProcessingTests`)

Pro Provider:
- Request-Encoding gegen JSON-Snapshot-Fixture
- Response-Decoding aus JSON-Fixture (success + error)
- Cost-Berechnung mit bekannten Token-Zahlen

Networking-Layer:
- `LLMHTTPClient.send` Retry bei `.network` und `.timeout` mit `MockURLProtocol`
- Timeout-Verhalten
- Header-Setzen ohne Key-Leak in Logs

Costs:
- `CostStore.today()` reset bei Tageswechsel
- Monatsaggregation
- Lokale Engine = 0 USD

### 8.2 Integration-Smoketest (manuell, dokumentiert in `docs/PHASE_1B_1_SMOKETEST.md`)

Pro Provider:
- 1× Diktat in Mode Literal, Mode Social, Mode Formell mit echtem Key
- API-Key-Test-Button gibt grünes Feedback in <3 s
- Falscher Key → rotes Feedback mit korrekter Fehlermeldung

Ollama-spezifisch:
- Server gestoppt → Settings zeigen „nicht erreichbar"
- `ollama pull llama3.2` → Discovery findet das Modell
- Diktat mit `llama3.2:latest` läuft

## 9. Akzeptanzkriterien

Phase 1b-1 gilt als abgeschlossen, wenn:

- ✅ Alle 4 Provider als Auswahl in Settings vorhanden
- ✅ Diktat in jedem Modus (Literal/Social/Formell) funktioniert mit allen 4 Providern
- ✅ Pro-Modus-Override funktioniert (testbar im Engines-Tab)
- ✅ Menübar zeigt Tages- und Monats-Kosten korrekt; Tagesreset funktioniert
- ✅ API-Down → 1× Retry → Fallback auf Rohtext mit Pill-Hinweis
- ✅ Falscher Key → Fallback ohne Retry mit spezifischer Pill-Meldung
- ✅ API-Key-Test-Button gibt grünes/rotes Feedback in <3 s
- ✅ Ollama-Modell-Discovery funktioniert wenn Server läuft
- ✅ Ollama nicht erreichbar → klarer UI-Hinweis mit Download-Link
- ✅ Onboarding-Step skippbar; First-Use-Hint kommt **einmalig** wenn geskippt
- ✅ Migration: Bestehender `notika.settings.llmChoice` wird gelesen und nach `notika.settings.globalLLMChoice` migriert
- ✅ API-Keys in Keychain, nicht in UserDefaults sichtbar
- ✅ Keine Diktat-Texte oder Keys in Console-Logs
- ✅ Alle Unit-Tests grün
- ✅ Build signiert mit Team `P7QK554EET`, läuft auf macOS 26 Tahoe

## 10. Out of Scope (explizit in Phase 1b-1 ausgeschlossen)

- Streaming (word-by-word Insertion in Zielprogramm) — eventuell Phase 1b-3 oder Phase 2
- whisper.cpp lokale STT — **Phase 1b-2** (eigener Spec)
- Custom Modell-IDs als Freitextfeld (User wählte kuratiertes Picker)
- Pro-Provider-Cost-Limits („Stop bei 5 €/Tag")
- Multi-Key pro Provider (mehrere Anthropic-Keys gleichzeitig)
- Detail-Cost-History (Tag/Stunden-Aufschlüsselung) — nur Tag/Monat sichtbar
- Provider-spezifische System-Prompts (alle nutzen dieselben drei `mode_*.md`-Defaults aus PromptStore)
- Sprachen-Auto-Detection per Provider (bleibt SettingsStore-Sprache)

## 11. Subagent-Strategie für Implementation

| Subagent | Verantwortung | Eingabe |
|---|---|---|
| `impl-anthropic` | `Anthropic/`-Folder + Tests | Engine-Protokoll, Networking-Helper, Pricing-Zeile, Request/Response-Snapshot-Format |
| `impl-openai` | `OpenAI/`-Folder + Tests | dito, mit Responses-API-Spec |
| `impl-google` | `Google/`-Folder + Tests | dito, mit `generateContent`-Format |
| `impl-research` | Verifikation der Pricing-Tabelle vor Release | WebFetch auf 6 Provider-URLs |

Hauptkontext erledigt: Datenmodell-Erweiterung, Networking-Helpers, Costs-Layer, Ollama-Wrapper, alle UI-Veränderungen (Onboarding, Settings, Menübar, Pill), Migration, Coordinator-Anpassung, manuelle Smoketests.

## 12. Risiken & offene Fragen

- **Pricing-Drift:** Provider können quartalsweise Preise ändern. Verifizieren vor Release; in `PricingTable.swift` Kommentar mit Datum. Wenn Drift > 20 %, Hinweis im Engines-Tab.
- **Ollama-Versionen:** `/api/tags` und `/v1/chat/completions` sind seit Ollama 0.1.30 stabil. Notika setzt Ollama ≥ 0.5 voraus, dokumentiert im Settings-Tab-Hinweis.
- **macOS-26-Konkretes:** Foundation-Models-Engine kann beim parallelen Cloud-Call interferieren? Nein — Foundation Models läuft synchron im selben Engine-Slot, nicht parallel.
- **Concurrency-Falle:** Cloud-Engines müssen `Sendable` sein und keine `@MainActor`-Captures haben. Testen analog zu Phase-1a-Lessons (`AVAudioEngine.installTap`).

## Anhang A — Quellen für Modell-Recherche (Stand 2026-04-18)

- Anthropic: https://docs.anthropic.com/en/docs/about-claude/models/overview, /pricing
- OpenAI: https://platform.openai.com/docs/models, https://openai.com/api/pricing/
- Google: https://ai.google.dev/gemini-api/docs/models, /pricing
- Ollama API: https://github.com/ollama/ollama/blob/main/docs/api.md
