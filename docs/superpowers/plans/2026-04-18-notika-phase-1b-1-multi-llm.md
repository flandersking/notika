# Notika Phase 1b-1 — Multi-LLM-Engines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vier auswählbare LLM-Provider (Anthropic, OpenAI, Google, Ollama) als BYOK-Engines für die drei Notika-Modi parallel verfügbar machen, mit Hybrid-Auswahl (global + Pro-Modus-Override), Cost-Tracking, Keychain-Storage und Fallback-Logik.

**Architecture:** Engine-Protokoll (`PostProcessingEngine`) wird auf `ProcessedText`-Return erweitert. Ein gemeinsamer `LLMHTTPClient` kapselt URLSession+Retry. Jeder Cloud-Provider (Anthropic/OpenAI/Google) hat einen Sub-Folder mit Codable Request/Response + Engine. Ollama nutzt OpenAI-Adapter mit anderer Base-URL. UI bekommt einen neuen Onboarding-Step, Engines-Tab-Redesign, Menübar-Cost-Indikator, Pill-Fehler-State.

**Tech Stack:** Swift 6.3 (Strict Concurrency), SwiftUI + Observation, URLSession, Keychain Services, XCTest, MockURLProtocol.

**Spec:** `docs/superpowers/specs/2026-04-18-notika-phase-1b-1-multi-llm-design.md`

---

## File Structure

### Erstellt

**NotikaCore (Datenmodell):**
- `Packages/NotikaCore/Sources/NotikaCore/Models/LLMChoice.swift` (extrahiert aus SettingsStore.swift)
- `Packages/NotikaCore/Sources/NotikaCore/Models/ProviderModels.swift` (Anthropic/OpenAI/Google Modell-Enums)
- `Packages/NotikaCore/Sources/NotikaCore/Models/ProcessedText.swift`

**NotikaPostProcessing (4 Provider + Infrastruktur):**
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Networking/LLMHTTPClient.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Networking/LLMError.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Networking/KeychainStore.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Costs/PricingTable.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Costs/CostCalculator.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Costs/CostStore.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Anthropic/AnthropicRequest.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Anthropic/AnthropicResponse.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Anthropic/AnthropicEngine.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/OpenAI/OpenAIRequest.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/OpenAI/OpenAIResponse.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/OpenAI/OpenAIEngine.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Google/GoogleRequest.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Google/GoogleResponse.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Google/GoogleEngine.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Ollama/OllamaModelDiscovery.swift`
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Ollama/OllamaEngine.swift`

**Tests (XCTest, neues Test-Target wenn noch nicht da):**
- `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/MockURLProtocol.swift`
- `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/LLMHTTPClientTests.swift`
- `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/CostStoreTests.swift`
- `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/AnthropicEngineTests.swift`
- `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/OpenAIEngineTests.swift`
- `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/GoogleEngineTests.swift`
- `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/` (Snapshot JSONs)

**App-UI:**
- `Notika/Onboarding/LLMSetupStep.swift`
- `Notika/Settings/HotkeysTab.swift` (kein neuer File, aber Engines-Tab wird stark erweitert)
- `Notika/Settings/EnginesTab+ProviderRows.swift` (Sub-Views für Provider-Sektionen)
- `Notika/Settings/EnginesTab+OllamaSection.swift` (separater Sub-View)
- `docs/PHASE_1B_1_SMOKETEST.md`

### Modifiziert

- `Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift` — `llmChoice` → `globalLLMChoice` + `modeLLMOverride` + Cost-Spiegel + Migration
- `Packages/NotikaCore/Sources/NotikaCore/Protocols/PostProcessingEngine.swift` — Return `ProcessedText` statt String, ID-Enum erweitern
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/FoundationModelsEngine.swift` — Anpassen an neuen Return-Typ
- `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/PostProcessingEngineFactory.swift` — alle 4 neuen Engines registrieren
- `Packages/NotikaPostProcessing/Package.swift` — Test-Target hinzufügen falls nicht vorhanden
- `Notika/DictationCoordinator.swift` — Engine-Resolve via Override + LLMError-Fallback + CostStore-Aufruf
- `Notika/Onboarding/OnboardingFlow.swift` — neuen `.llmSetup`-Step zwischen permissions und finished
- `Notika/Settings/EnginesTab.swift` — komplettes Redesign
- `Notika/MenuBar/MenuBarContent.swift` — Tages-/Monats-Kosten + Reset-Button
- `Notika/Overlay/PillView.swift` — orange Fehler-Variante für „KI-Helfer offline"
- `Notika/AppDelegate.swift` — Migration-Aufruf beim Start, FirstUseHint-Wiring
- `Notika/Info.plist` — `NSAllowsLocalNetworking` für Ollama auf localhost

---

## Task 1: Datenmodell-Foundation in NotikaCore

**Files:**
- Create: `Packages/NotikaCore/Sources/NotikaCore/Models/LLMChoice.swift`
- Create: `Packages/NotikaCore/Sources/NotikaCore/Models/ProviderModels.swift`
- Create: `Packages/NotikaCore/Sources/NotikaCore/Models/ProcessedText.swift`
- Modify: `Packages/NotikaCore/Sources/NotikaCore/Protocols/PostProcessingEngine.swift`
- Modify: `Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift`
- Test: `Packages/NotikaCore/Tests/NotikaCoreTests/LLMChoiceTests.swift` (Test-Target ggf. neu im Package.swift anlegen)

- [ ] **Step 1.1: Test-Target im NotikaCore/Package.swift anlegen falls nicht vorhanden**

```swift
// in Packages/NotikaCore/Package.swift, in der targets-Liste am Ende:
.testTarget(
    name: "NotikaCoreTests",
    dependencies: ["NotikaCore"]
)
```

Falls bereits vorhanden, überspringen.

- [ ] **Step 1.2: Failing test für LLMChoice-Codable schreiben**

`Packages/NotikaCore/Tests/NotikaCoreTests/LLMChoiceTests.swift`:

```swift
import XCTest
@testable import NotikaCore

final class LLMChoiceTests: XCTestCase {
    func test_anthropicHaiku_codable_roundtrip() throws {
        let original: LLMChoice = .anthropic(.haiku45)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_ollama_withModelID_codable_roundtrip() throws {
        let original: LLMChoice = .ollama(modelID: "llama3.2:latest")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_none_codable_roundtrip() throws {
        let original: LLMChoice = .none
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LLMChoice.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_displayName_anthropicHaiku() {
        XCTAssertEqual(LLMChoice.anthropic(.haiku45).displayName, "Claude Haiku 4.5 (schnell, günstig)")
    }
}
```

- [ ] **Step 1.3: Test laufen lassen, schlägt fehl**

```bash
cd Packages/NotikaCore && swift test --filter LLMChoiceTests
```

Erwartet: Fehlschlag „cannot find 'LLMChoice' in scope" (weil noch in SettingsStore.swift).

- [ ] **Step 1.4: ProviderModels.swift erstellen**

`Packages/NotikaCore/Sources/NotikaCore/Models/ProviderModels.swift`:

```swift
import Foundation

public enum AnthropicModel: String, Codable, CaseIterable, Sendable, Hashable {
    case haiku45  = "claude-haiku-4-5"
    case sonnet46 = "claude-sonnet-4-6"
    case opus47   = "claude-opus-4-7"

    public var displayName: String {
        switch self {
        case .haiku45:  return "Claude Haiku 4.5 (schnell, günstig)"
        case .sonnet46: return "Claude Sonnet 4.6 (empfohlen)"
        case .opus47:   return "Claude Opus 4.7 (präziseste)"
        }
    }
}

public enum OpenAIModel: String, Codable, CaseIterable, Sendable, Hashable {
    case nano54 = "gpt-5.4-nano"
    case mini54 = "gpt-5.4-mini"
    case full54 = "gpt-5.4"

    public var displayName: String {
        switch self {
        case .nano54: return "GPT-5.4 nano (sehr günstig)"
        case .mini54: return "GPT-5.4 mini (empfohlen)"
        case .full54: return "GPT-5.4 (präziseste)"
        }
    }
}

public enum GoogleModel: String, Codable, CaseIterable, Sendable, Hashable {
    case flashLite31Preview = "gemini-3.1-flash-lite-preview"
    case flash25            = "gemini-2.5-flash"
    case pro31Preview       = "gemini-3.1-pro-preview"

    public var displayName: String {
        switch self {
        case .flashLite31Preview: return "Gemini 3.1 Flash-Lite (Preview)"
        case .flash25:            return "Gemini 2.5 Flash (empfohlen)"
        case .pro31Preview:       return "Gemini 3.1 Pro (Preview)"
        }
    }
}
```

- [ ] **Step 1.5: LLMChoice.swift erstellen, alten Inhalt aus SettingsStore.swift entfernen**

`Packages/NotikaCore/Sources/NotikaCore/Models/LLMChoice.swift`:

```swift
import Foundation

public enum LLMChoice: Codable, Sendable, Hashable {
    case none
    case appleFoundationModels
    case anthropic(AnthropicModel)
    case openAI(OpenAIModel)
    case google(GoogleModel)
    case ollama(modelID: String)

    public var displayName: String {
        switch self {
        case .none:                   return "Kein KI-Helfer — Text bleibt wie gesprochen"
        case .appleFoundationModels:  return "Apple (gratis, läuft auf deinem Mac)"
        case .anthropic(let m):       return m.displayName
        case .openAI(let m):          return m.displayName
        case .google(let m):          return m.displayName
        case .ollama(let id):         return "Ollama · \(id)"
        }
    }

    public var providerID: PostProcessingEngineID {
        switch self {
        case .none:                   return .none
        case .appleFoundationModels:  return .appleFoundationModels
        case .anthropic:              return .anthropic
        case .openAI:                 return .openAI
        case .google:                 return .google
        case .ollama:                 return .ollama
        }
    }
}
```

In `SettingsStore.swift` das alte `LLMChoice`-Enum **vollständig entfernen** (Zeilen 4-25). Datei bleibt mit `SettingsStore`-class — wird in Step 1.8 erweitert.

- [ ] **Step 1.6: ProcessedText.swift erstellen**

`Packages/NotikaCore/Sources/NotikaCore/Models/ProcessedText.swift`:

```swift
import Foundation

public struct ProcessedText: Sendable, Equatable {
    public let text: String
    public let costUSD: Double?
    public let tokensIn: Int?
    public let tokensOut: Int?
    public let provider: PostProcessingEngineID
    public let model: String?

    public init(
        text: String,
        costUSD: Double? = nil,
        tokensIn: Int? = nil,
        tokensOut: Int? = nil,
        provider: PostProcessingEngineID,
        model: String? = nil
    ) {
        self.text = text
        self.costUSD = costUSD
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.provider = provider
        self.model = model
    }
}
```

- [ ] **Step 1.7: PostProcessingEngine-Protokoll erweitern**

`Packages/NotikaCore/Sources/NotikaCore/Protocols/PostProcessingEngine.swift` komplett ersetzen:

```swift
import Foundation

public enum PostProcessingEngineID: String, Codable, Sendable, CaseIterable {
    case none
    case appleFoundationModels
    case anthropic
    case openAI
    case google
    case ollama
}

public protocol PostProcessingEngine: AnyObject, Sendable {
    var id: PostProcessingEngineID { get }

    func process(
        transcript: String,
        mode: DictationMode,
        language: Language
    ) async throws -> ProcessedText
}
```

- [ ] **Step 1.8: SettingsStore mit globalLLMChoice/modeLLMOverride/Migration erweitern**

`Packages/NotikaCore/Sources/NotikaCore/Settings/SettingsStore.swift` komplett ersetzen:

```swift
import Foundation
import Observation

@MainActor
@Observable
public final class SettingsStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateIfNeeded(defaults: defaults)
    }

    // MARK: - Global LLM-Wahl

    public var globalLLMChoice: LLMChoice {
        get {
            guard let data = defaults.data(forKey: "notika.settings.globalLLMChoice"),
                  let value = try? JSONDecoder().decode(LLMChoice.self, from: data)
            else {
                return .appleFoundationModels   // Phase-1b-1-Default (Wahl 6b)
            }
            return value
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "notika.settings.globalLLMChoice")
            }
        }
    }

    // MARK: - Pro-Modus-Override (leer = nutzt global)

    public func override(for mode: DictationMode) -> LLMChoice? {
        guard let data = defaults.data(forKey: overrideKey(for: mode)),
              let value = try? JSONDecoder().decode(LLMChoice.self, from: data)
        else { return nil }
        return value
    }

    public func setOverride(_ choice: LLMChoice?, for mode: DictationMode) {
        let key = overrideKey(for: mode)
        if let choice, let data = try? JSONEncoder().encode(choice) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func effectiveChoice(for mode: DictationMode) -> LLMChoice {
        override(for: mode) ?? globalLLMChoice
    }

    private func overrideKey(for mode: DictationMode) -> String {
        "notika.settings.modeOverride.\(mode.rawValue)"
    }

    // MARK: - Sprache

    public var defaultLanguage: String {
        get { defaults.string(forKey: "notika.settings.language") ?? "de" }
        set { defaults.set(newValue, forKey: "notika.settings.language") }
    }

    // MARK: - Migration vom Phase-1a-rawString-Format

    private static func migrateIfNeeded(defaults: UserDefaults) {
        let oldKey = "notika.settings.llmChoice"
        let newKey = "notika.settings.globalLLMChoice"
        guard defaults.data(forKey: newKey) == nil,
              let oldRaw = defaults.string(forKey: oldKey)
        else { return }

        let migrated: LLMChoice
        switch oldRaw {
        case "appleFoundationModels":
            migrated = .appleFoundationModels
        case "none":
            migrated = .none
        case "anthropic":
            // Phase-1a hatte keinen funktionalen Anthropic-Engine; sinnvoll auf Apple zurück.
            migrated = .appleFoundationModels
        default:
            migrated = .appleFoundationModels
        }
        if let data = try? JSONEncoder().encode(migrated) {
            defaults.set(data, forKey: newKey)
        }
        defaults.removeObject(forKey: oldKey)
    }
}
```

- [ ] **Step 1.9: Tests laufen lassen, müssen grün sein**

```bash
cd Packages/NotikaCore && swift test --filter LLMChoiceTests
```

Erwartet: 4× PASS.

- [ ] **Step 1.10: Build des gesamten Workspaces, um Breaking Changes aufzudecken**

```bash
xcodebuild -workspace Notika.xcodeproj/project.xcworkspace -scheme Notika -destination 'platform=macOS' build 2>&1 | tail -40
```

Erwartet: Fehler in `FoundationModelsEngine.swift` (Return-Typ), `PostProcessingEngineFactory.swift` (`.anthropic` case + neue Provider-IDs), `DictationCoordinator.swift` (`.llmChoice` → `.globalLLMChoice`/`effectiveChoice`).

**Kein Fix in diesem Task — die Folge-Tasks reparieren die Build-Fehler systematisch.** In Step 1.11 wird der Coordinator/Factory minimal gefixt, damit der Build für die nachfolgenden Tasks wieder grün ist.

- [ ] **Step 1.11: Minimaler Build-Fix (FoundationModelsEngine + Factory + Coordinator)**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/FoundationModelsEngine.swift`:

Den letzten Block der `process`-Methode ändern (Zeile 42-46):

```swift
        let raw = response.content
        let cleaned = Self.stripPreambleAndQuotes(raw)
        logger.info("LLM-Output roh: \(raw, privacy: .public)")
        logger.info("LLM-Output final: \(cleaned, privacy: .public)")
        let final = cleaned.isEmpty ? transcript : cleaned
        return ProcessedText(
            text: final,
            costUSD: nil,
            tokensIn: nil,
            tokensOut: nil,
            provider: .appleFoundationModels,
            model: nil
        )
```

Und den Early-Return bei `transcript.isEmpty` ändern:

```swift
        guard !transcript.isEmpty else {
            return ProcessedText(text: transcript, provider: .appleFoundationModels)
        }
```

Und den `model.isAvailable`-Branch:

```swift
        guard model.isAvailable else {
            logger.warning("SystemLanguageModel nicht verfügbar — gebe Transkript unverändert zurück")
            return ProcessedText(text: transcript, provider: .appleFoundationModels)
        }
```

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/PostProcessingEngineFactory.swift` komplett ersetzen:

```swift
import Foundation
import NotikaCore

public enum PostProcessingEngineFactory {
    public static func makeEngine(for choice: LLMChoice) -> PostProcessingEngine? {
        switch choice {
        case .none:
            return nil
        case .appleFoundationModels:
            return FoundationModelsEngine()
        case .anthropic, .openAI, .google, .ollama:
            // Werden in Tasks 4-7 implementiert. Bis dahin: nil → DictationCoordinator
            // fällt automatisch auf Rohtranskript zurück.
            return nil
        }
    }
}
```

`Notika/DictationCoordinator.swift` Zeile 36-46 (`makePostProcessingEngine()`) ersetzen:

```swift
    private func makePostProcessingEngine(for mode: DictationMode) -> PostProcessingEngine? {
        let choice = settings.effectiveChoice(for: mode)
        return PostProcessingEngineFactory.makeEngine(for: choice)
    }
```

Und im Pipeline-Block (Zeile 159) Aufruf anpassen:

```swift
                    if let engine = self.makePostProcessingEngine(for: mode) {
                        self.overlay.updateState(.processing(mode: mode))
                        let result = try await engine.process(
                            transcript: transcript.text,
                            mode: mode,
                            language: .german
                        )
                        processed = result.text
                        self.logger.info("Transkript final (LLM): \(processed, privacy: .public)")
                    } else {
```

- [ ] **Step 1.12: Build erneut, muss grün sein**

```bash
xcodebuild -workspace Notika.xcodeproj/project.xcworkspace -scheme Notika -destination 'platform=macOS' build 2>&1 | tail -10
```

Erwartet: `** BUILD SUCCEEDED **`.

- [ ] **Step 1.13: Commit**

```bash
git add Packages/NotikaCore Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/FoundationModelsEngine.swift Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/PostProcessingEngineFactory.swift Notika/DictationCoordinator.swift
git commit -m "Phase 1b-1 #1: Datenmodell-Foundation (LLMChoice, ProcessedText, Migration)"
```

---

## Task 2: Networking-Layer (LLMHTTPClient, LLMError, KeychainStore)

**Files:**
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Networking/LLMError.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Networking/LLMHTTPClient.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Networking/KeychainStore.swift`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/MockURLProtocol.swift`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/LLMHTTPClientTests.swift`
- Modify: `Packages/NotikaPostProcessing/Package.swift` (Test-Target falls fehlt)

- [ ] **Step 2.1: Test-Target im Package.swift sicherstellen**

In `Packages/NotikaPostProcessing/Package.swift` `targets:`-Liste prüfen — falls kein `.testTarget(name: "NotikaPostProcessingTests"...)` vorhanden, hinzufügen:

```swift
.testTarget(
    name: "NotikaPostProcessingTests",
    dependencies: ["NotikaPostProcessing"]
)
```

- [ ] **Step 2.2: LLMError.swift erstellen**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Networking/LLMError.swift`:

```swift
import Foundation

public enum LLMError: Error, Sendable, Equatable {
    case invalidKey
    case rateLimit(retryAfter: TimeInterval?)
    case network
    case timeout
    case serverError(status: Int, body: String)
    case invalidResponse
    case ollamaUnavailable
    case modelNotFound(String)

    public var userFacingMessage: String {
        switch self {
        case .invalidKey:        return "Schlüssel ungültig — in Einstellungen prüfen"
        case .rateLimit:         return "Anbieter-Limit erreicht — kurz warten"
        case .network, .timeout: return "KI-Helfer offline — Rohtext eingefügt"
        case .serverError:       return "Server-Fehler — Rohtext eingefügt"
        case .invalidResponse:   return "Antwort nicht lesbar — Rohtext eingefügt"
        case .ollamaUnavailable: return "Ollama nicht erreichbar — Rohtext eingefügt"
        case .modelNotFound:     return "Modell nicht verfügbar — in Einstellungen prüfen"
        }
    }
}
```

- [ ] **Step 2.3: MockURLProtocol für Tests erstellen**

`Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/MockURLProtocol.swift`:

```swift
import Foundation

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() { requestHandler = nil }
}
```

- [ ] **Step 2.4: Failing test für LLMHTTPClient (Happy Path) schreiben**

`Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/LLMHTTPClientTests.swift`:

```swift
import XCTest
@testable import NotikaPostProcessing

final class LLMHTTPClientTests: XCTestCase {
    var client: LLMHTTPClient!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        client = LLMHTTPClient(session: session, timeout: 1.0)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func test_send_returns_data_on_200() async throws {
        MockURLProtocol.requestHandler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("ok".utf8))
        }
        var req = URLRequest(url: URL(string: "https://example.com/x")!)
        req.httpMethod = "POST"
        let data = try await client.send(req)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "ok")
    }

    func test_send_returns_invalidKey_on_401() async {
        MockURLProtocol.requestHandler = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data("unauthorized".utf8))
        }
        let req = URLRequest(url: URL(string: "https://example.com/x")!)
        do {
            _ = try await client.send(req)
            XCTFail("should throw")
        } catch let error as LLMError {
            XCTAssertEqual(error, .invalidKey)
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    func test_send_retries_once_on_network_error_then_succeeds() async throws {
        let attempts = AttemptCounter()
        MockURLProtocol.requestHandler = { req in
            let n = attempts.increment()
            if n == 1 {
                throw URLError(.notConnectedToInternet)
            }
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("retry-ok".utf8))
        }
        var req = URLRequest(url: URL(string: "https://example.com/x")!)
        req.httpMethod = "POST"
        let data = try await client.send(req)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "retry-ok")
        XCTAssertEqual(attempts.value, 2)
    }

    func test_send_does_not_retry_on_invalidKey() async {
        let attempts = AttemptCounter()
        MockURLProtocol.requestHandler = { req in
            _ = attempts.increment()
            let resp = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let req = URLRequest(url: URL(string: "https://example.com/x")!)
        do { _ = try await client.send(req) } catch {}
        XCTAssertEqual(attempts.value, 1)
    }
}

final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int { lock.withLock { _value } }
    @discardableResult
    func increment() -> Int { lock.withLock { _value += 1; return _value } }
}
```

- [ ] **Step 2.5: Test laufen lassen, schlägt fehl**

```bash
cd Packages/NotikaPostProcessing && swift test --filter LLMHTTPClientTests
```

Erwartet: Compile-Error „cannot find 'LLMHTTPClient'".

- [ ] **Step 2.6: LLMHTTPClient.swift implementieren**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Networking/LLMHTTPClient.swift`:

```swift
import Foundation
import os

public final class LLMHTTPClient: Sendable {
    private let session: URLSession
    private let timeout: TimeInterval
    private let retryDelay: TimeInterval
    private let logger = Logger(subsystem: "com.notika.mac", category: "PostProcessing.HTTP")

    public init(session: URLSession = .shared, timeout: TimeInterval = 12, retryDelay: TimeInterval = 1) {
        self.session = session
        self.timeout = timeout
        self.retryDelay = retryDelay
    }

    public func send(_ request: URLRequest) async throws -> Data {
        do {
            return try await sendOnce(request)
        } catch LLMError.network, LLMError.timeout {
            logger.info("Retry nach Netzwerk-/Timeout-Fehler")
            try? await Task.sleep(for: .seconds(retryDelay))
            return try await sendOnce(request)
        }
    }

    private func sendOnce(_ request: URLRequest) async throws -> Data {
        var req = request
        req.timeoutInterval = timeout
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlError as URLError {
            switch urlError.code {
            case .timedOut:                  throw LLMError.timeout
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotConnectToHost,
                 .cannotFindHost:            throw LLMError.network
            default:                          throw LLMError.network
            }
        } catch {
            throw LLMError.network
        }
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw LLMError.invalidKey
        case 404:
            let body = String(decoding: data, as: UTF8.self)
            throw LLMError.modelNotFound(body)
        case 429:
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After") as NSString?)?.doubleValue
            throw LLMError.rateLimit(retryAfter: retryAfter)
        default:
            let body = String(decoding: data, as: UTF8.self)
            throw LLMError.serverError(status: http.statusCode, body: String(body.prefix(500)))
        }
    }
}
```

- [ ] **Step 2.7: Tests laufen, müssen alle 4 grün sein**

```bash
cd Packages/NotikaPostProcessing && swift test --filter LLMHTTPClientTests
```

Erwartet: 4× PASS.

- [ ] **Step 2.8: KeychainStore.swift erstellen**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Networking/KeychainStore.swift`:

```swift
import Foundation
import Security
import NotikaCore

public enum KeychainProvider: String, Sendable {
    case anthropic
    case openAI
    case google
}

public enum KeychainStore {
    private static func service(for provider: KeychainProvider) -> String {
        "app.notika.apikey.\(provider.rawValue)"
    }

    public static func setKey(_ key: String?, for provider: KeychainProvider) {
        let svc = service(for: provider)
        // Vorhandenen Eintrag löschen
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard let key, !key.isEmpty, let data = key.data(using: .utf8) else { return }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    public static func key(for provider: KeychainProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service(for: provider),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
```

- [ ] **Step 2.9: Build und Tests laufen, alles grün**

```bash
cd Packages/NotikaPostProcessing && swift build && swift test
```

- [ ] **Step 2.10: Commit**

```bash
git add Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Networking Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/MockURLProtocol.swift Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/LLMHTTPClientTests.swift Packages/NotikaPostProcessing/Package.swift
git commit -m "Phase 1b-1 #2: Networking-Layer (HTTPClient, Errors, Keychain) mit Tests"
```

---

## Task 3: Costs-Layer (PricingTable, CostCalculator, CostStore)

**Files:**
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Costs/PricingTable.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Costs/CostCalculator.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Costs/CostStore.swift`
- Create: `Packages/NotikaCore/Sources/NotikaCore/Models/CostSnapshot.swift`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/CostStoreTests.swift`

- [ ] **Step 3.1: CostSnapshot in NotikaCore anlegen**

`Packages/NotikaCore/Sources/NotikaCore/Models/CostSnapshot.swift`:

```swift
import Foundation

public struct CostSnapshot: Codable, Sendable, Equatable {
    public let totalUSD: Double
    public let callCount: Int
    public let lastReset: Date

    public init(totalUSD: Double = 0, callCount: Int = 0, lastReset: Date = Date()) {
        self.totalUSD = totalUSD
        self.callCount = callCount
        self.lastReset = lastReset
    }
}
```

- [ ] **Step 3.2: PricingTable.swift erstellen**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Costs/PricingTable.swift`:

```swift
import Foundation
import NotikaCore

/// Preise pro 1 Million Tokens in USD.
/// Quelle: Provider-Doku, Stand 2026-04-18.
/// Vor Release verifizieren auf docs.anthropic.com/pricing,
/// openai.com/api/pricing/, ai.google.dev/gemini-api/docs/pricing.
public enum PricingTable {
    public struct Entry: Sendable, Equatable {
        public let inputUSDPerMillion: Double
        public let outputUSDPerMillion: Double
    }

    public static let entries: [String: Entry] = [
        // Anthropic
        "claude-haiku-4-5":  Entry(inputUSDPerMillion: 1.00,  outputUSDPerMillion: 5.00),
        "claude-sonnet-4-6": Entry(inputUSDPerMillion: 3.00,  outputUSDPerMillion: 15.00),
        "claude-opus-4-7":   Entry(inputUSDPerMillion: 5.00,  outputUSDPerMillion: 25.00),
        // OpenAI
        "gpt-5.4-nano":      Entry(inputUSDPerMillion: 0.20,  outputUSDPerMillion: 1.25),
        "gpt-5.4-mini":      Entry(inputUSDPerMillion: 0.75,  outputUSDPerMillion: 4.50),
        "gpt-5.4":           Entry(inputUSDPerMillion: 2.50,  outputUSDPerMillion: 15.00),
        // Google
        "gemini-3.1-flash-lite-preview": Entry(inputUSDPerMillion: 0.25, outputUSDPerMillion: 1.50),
        "gemini-2.5-flash":              Entry(inputUSDPerMillion: 0.30, outputUSDPerMillion: 2.50),
        "gemini-3.1-pro-preview":        Entry(inputUSDPerMillion: 2.00, outputUSDPerMillion: 12.00),
    ]

    public static func entry(for modelID: String) -> Entry? {
        entries[modelID]
    }
}
```

- [ ] **Step 3.3: CostCalculator.swift erstellen**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Costs/CostCalculator.swift`:

```swift
import Foundation
import NotikaCore

public enum CostCalculator {
    /// Berechnet die USD-Kosten für einen Call. `nil` wenn Modell nicht in Tabelle (z.B. Ollama-Modell).
    public static func cost(modelID: String, tokensIn: Int, tokensOut: Int) -> Double? {
        guard let entry = PricingTable.entry(for: modelID) else { return nil }
        let inCost  = Double(tokensIn)  / 1_000_000.0 * entry.inputUSDPerMillion
        let outCost = Double(tokensOut) / 1_000_000.0 * entry.outputUSDPerMillion
        return inCost + outCost
    }
}
```

- [ ] **Step 3.4: Failing test für CostStore schreiben**

`Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/CostStoreTests.swift`:

```swift
import XCTest
@testable import NotikaPostProcessing
import NotikaCore

final class CostStoreTests: XCTestCase {
    var defaults: UserDefaults!
    var store: CostStore!

    override func setUp() async throws {
        let suiteName = "test.notika.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = await CostStore(defaults: defaults, calendar: Calendar(identifier: .gregorian))
    }

    @MainActor
    func test_record_increments_today() async {
        store.record(modelID: "claude-haiku-4-5", tokensIn: 1000, tokensOut: 500)
        let today = store.today()
        XCTAssertEqual(today.callCount, 1)
        XCTAssertEqual(today.totalUSD, (1000.0/1_000_000 * 1.0) + (500.0/1_000_000 * 5.0), accuracy: 0.0000001)
    }

    @MainActor
    func test_record_zero_for_unknown_model() async {
        store.record(modelID: "ollama:llama3.2", tokensIn: 1000, tokensOut: 500)
        let today = store.today()
        XCTAssertEqual(today.callCount, 1)
        XCTAssertEqual(today.totalUSD, 0)
    }

    @MainActor
    func test_today_resets_after_day_change() async {
        // Tag 1
        store.record(modelID: "claude-haiku-4-5", tokensIn: 1000, tokensOut: 1000)
        XCTAssertEqual(store.today().callCount, 1)
        // Simuliere Tageswechsel: Datum-Provider auf morgen setzen
        store.now = { Date().addingTimeInterval(86_400) }
        let day2 = store.today()
        XCTAssertEqual(day2.callCount, 0)
        XCTAssertEqual(day2.totalUSD, 0)
    }
}
```

- [ ] **Step 3.5: Test laufen, schlägt fehl**

```bash
cd Packages/NotikaPostProcessing && swift test --filter CostStoreTests
```

Erwartet: Compile-Error „cannot find 'CostStore'".

- [ ] **Step 3.6: CostStore.swift implementieren**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Costs/CostStore.swift`:

```swift
import Foundation
import NotikaCore

@MainActor
public final class CostStore {
    private let defaults: UserDefaults
    private let calendar: Calendar
    public var now: @Sendable () -> Date

    public init(defaults: UserDefaults = .standard,
                calendar: Calendar = Calendar.current,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    public func record(modelID: String, tokensIn: Int, tokensOut: Int) {
        let cost = CostCalculator.cost(modelID: modelID, tokensIn: tokensIn, tokensOut: tokensOut) ?? 0

        var todaySnap = readSnapshot(key: dailyKey())
        todaySnap = CostSnapshot(
            totalUSD: todaySnap.totalUSD + cost,
            callCount: todaySnap.callCount + 1,
            lastReset: todaySnap.lastReset
        )
        writeSnapshot(todaySnap, key: dailyKey())

        var monthSnap = readSnapshot(key: monthlyKey())
        monthSnap = CostSnapshot(
            totalUSD: monthSnap.totalUSD + cost,
            callCount: monthSnap.callCount + 1,
            lastReset: monthSnap.lastReset
        )
        writeSnapshot(monthSnap, key: monthlyKey())
    }

    public func today() -> CostSnapshot {
        readSnapshot(key: dailyKey())
    }

    public func thisMonth() -> CostSnapshot {
        readSnapshot(key: monthlyKey())
    }

    public func resetToday() {
        defaults.removeObject(forKey: dailyKey())
    }

    // MARK: - Persistence helpers

    private func dailyKey() -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: now())
        return String(format: "notika.costs.daily.%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
    }

    private func monthlyKey() -> String {
        let comps = calendar.dateComponents([.year, .month], from: now())
        return String(format: "notika.costs.monthly.%04d-%02d", comps.year!, comps.month!)
    }

    private func readSnapshot(key: String) -> CostSnapshot {
        guard let data = defaults.data(forKey: key),
              let snap = try? JSONDecoder().decode(CostSnapshot.self, from: data)
        else { return CostSnapshot(lastReset: now()) }
        return snap
    }

    private func writeSnapshot(_ snap: CostSnapshot, key: String) {
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: key)
        }
    }
}
```

- [ ] **Step 3.7: Tests laufen, alle 3 grün**

```bash
cd Packages/NotikaPostProcessing && swift test --filter CostStoreTests
```

- [ ] **Step 3.8: Commit**

```bash
git add Packages/NotikaCore/Sources/NotikaCore/Models/CostSnapshot.swift Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Costs Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/CostStoreTests.swift
git commit -m "Phase 1b-1 #3: Costs-Layer (PricingTable, Calculator, Store) mit Tests"
```

---

## Task 4: AnthropicEngine (kann an Subagent „impl-anthropic" delegiert werden)

**Files:**
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Anthropic/AnthropicRequest.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Anthropic/AnthropicResponse.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Anthropic/AnthropicEngine.swift`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/anthropic-haiku-success.json`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/AnthropicEngineTests.swift`

- [ ] **Step 4.1: Failing test für AnthropicEngine (Happy Path) schreiben**

Erst die Fixture: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/anthropic-haiku-success.json`:

```json
{
  "id": "msg_abc123",
  "type": "message",
  "role": "assistant",
  "model": "claude-haiku-4-5",
  "content": [
    { "type": "text", "text": "Hallo, wie geht es Ihnen heute?" }
  ],
  "stop_reason": "end_turn",
  "usage": { "input_tokens": 42, "output_tokens": 11 }
}
```

Dann der Test: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/AnthropicEngineTests.swift`:

```swift
import XCTest
@testable import NotikaPostProcessing
import NotikaCore

final class AnthropicEngineTests: XCTestCase {
    var engine: AnthropicEngine!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = LLMHTTPClient(session: session, timeout: 1.0, retryDelay: 0)
        engine = AnthropicEngine(model: .haiku45, apiKey: "sk-ant-test", httpClient: client)
    }

    override func tearDown() { MockURLProtocol.reset(); super.tearDown() }

    func test_process_returns_processedText_with_cost() async throws {
        let url = Bundle.module.url(forResource: "anthropic-haiku-success", withExtension: "json", subdirectory: "Fixtures")!
        let fixtureData = try Data(contentsOf: url)
        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.absoluteString, "https://api.anthropic.com/v1/messages")
            XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
            XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, fixtureData)
        }
        let result = try await engine.process(transcript: "hallo wie geht es ihnen heute", mode: .formal, language: .german)
        XCTAssertEqual(result.text, "Hallo, wie geht es Ihnen heute?")
        XCTAssertEqual(result.tokensIn, 42)
        XCTAssertEqual(result.tokensOut, 11)
        XCTAssertEqual(result.provider, .anthropic)
        XCTAssertEqual(result.model, "claude-haiku-4-5")
        // 42 in × 1$/1M + 11 out × 5$/1M
        XCTAssertEqual(result.costUSD!, (42.0/1_000_000) + (5 * 11.0/1_000_000), accuracy: 0.0000001)
    }
}
```

Hinweis: Für Bundle.module-Zugriff auf die Fixture muss im Package.swift das Test-Target `resources: [.copy("Fixtures")]` haben — falls noch nicht da, in Step 4.2 mitanlegen.

- [ ] **Step 4.2: Test-Target um Resources erweitern**

`Packages/NotikaPostProcessing/Package.swift`, im `.testTarget(name: "NotikaPostProcessingTests"...)`:

```swift
.testTarget(
    name: "NotikaPostProcessingTests",
    dependencies: ["NotikaPostProcessing"],
    resources: [.copy("Fixtures")]
)
```

- [ ] **Step 4.3: Test laufen, schlägt fehl**

```bash
cd Packages/NotikaPostProcessing && swift test --filter AnthropicEngineTests
```

Erwartet: Compile-Error „cannot find 'AnthropicEngine'".

- [ ] **Step 4.4: AnthropicRequest.swift erstellen**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Anthropic/AnthropicRequest.swift`:

```swift
import Foundation

struct AnthropicRequest: Encodable {
    struct Message: Encodable {
        let role: String   // "user"
        let content: String
    }

    let model: String
    let max_tokens: Int
    let temperature: Double
    let system: String
    let messages: [Message]
}
```

- [ ] **Step 4.5: AnthropicResponse.swift erstellen**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Anthropic/AnthropicResponse.swift`:

```swift
import Foundation

struct AnthropicResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
    struct Usage: Decodable {
        let input_tokens: Int
        let output_tokens: Int
    }
    let model: String
    let content: [ContentBlock]
    let usage: Usage

    var firstText: String {
        content.first(where: { $0.type == "text" })?.text ?? ""
    }
}
```

- [ ] **Step 4.6: AnthropicEngine.swift erstellen**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Anthropic/AnthropicEngine.swift`:

```swift
import Foundation
import NotikaCore
import os

public final class AnthropicEngine: PostProcessingEngine {
    public let id: PostProcessingEngineID = .anthropic

    private let model: AnthropicModel
    private let apiKey: String
    private let client: LLMHTTPClient
    private let logger = Logger(subsystem: "com.notika.mac", category: "PostProcessing.Anthropic")

    public init(model: AnthropicModel, apiKey: String, httpClient: LLMHTTPClient = LLMHTTPClient()) {
        self.model = model
        self.apiKey = apiKey
        self.client = httpClient
    }

    public func process(transcript: String, mode: DictationMode, language: Language) async throws -> ProcessedText {
        guard !transcript.isEmpty else {
            return ProcessedText(text: transcript, provider: .anthropic, model: model.rawValue)
        }
        let systemPrompt = PromptStore.effectivePrompt(for: mode)
            + "\n\nAntworte in der Sprache des Eingabetextes (Deutsch oder Englisch)."

        let body = AnthropicRequest(
            model: model.rawValue,
            max_tokens: 1024,
            temperature: temperature(for: mode),
            system: systemPrompt,
            messages: [.init(role: "user", content: transcript)]
        )

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONEncoder().encode(body)

        logger.info("→ Anthropic \(self.model.rawValue, privacy: .public), \(transcript.count) chars")
        let data = try await client.send(req)

        let decoded: AnthropicResponse
        do {
            decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        } catch {
            logger.error("Decode-Fehler: \(error.localizedDescription, privacy: .public)")
            throw LLMError.invalidResponse
        }
        let cost = CostCalculator.cost(modelID: model.rawValue, tokensIn: decoded.usage.input_tokens, tokensOut: decoded.usage.output_tokens)
        logger.info("← Anthropic OK, in=\(decoded.usage.input_tokens) out=\(decoded.usage.output_tokens) cost=\(cost ?? 0)")
        return ProcessedText(
            text: decoded.firstText,
            costUSD: cost,
            tokensIn: decoded.usage.input_tokens,
            tokensOut: decoded.usage.output_tokens,
            provider: .anthropic,
            model: decoded.model
        )
    }

    private func temperature(for mode: DictationMode) -> Double {
        switch mode {
        case .literal: return 0.05
        case .social:  return 0.6
        case .formal:  return 0.2
        }
    }
}
```

- [ ] **Step 4.7: Tests laufen, müssen grün sein**

```bash
cd Packages/NotikaPostProcessing && swift test --filter AnthropicEngineTests
```

- [ ] **Step 4.8: Commit**

```bash
git add Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Anthropic Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/AnthropicEngineTests.swift Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/anthropic-haiku-success.json Packages/NotikaPostProcessing/Package.swift
git commit -m "Phase 1b-1 #4: AnthropicEngine mit Codable-Layer und Tests"
```

---

## Task 5: OpenAIEngine (kann an Subagent „impl-openai" delegiert werden)

**Files:**
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/OpenAI/OpenAIRequest.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/OpenAI/OpenAIResponse.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/OpenAI/OpenAIEngine.swift`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/openai-mini-success.json`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/OpenAIEngineTests.swift`

OpenAI Responses-API: `POST https://api.openai.com/v1/responses`. Request: `{ model, instructions, input }`. Response: `{ output: [{ content: [{ text }]}], usage: { input_tokens, output_tokens } }`.

- [ ] **Step 5.1: Fixture anlegen**

`Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/openai-mini-success.json`:

```json
{
  "id": "resp_abc",
  "model": "gpt-5.4-mini",
  "output": [
    {
      "type": "message",
      "role": "assistant",
      "content": [{ "type": "output_text", "text": "Hallo, wie geht es dir heute?" }]
    }
  ],
  "usage": { "input_tokens": 38, "output_tokens": 9 }
}
```

- [ ] **Step 5.2: Failing Test schreiben**

`Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/OpenAIEngineTests.swift`:

```swift
import XCTest
@testable import NotikaPostProcessing
import NotikaCore

final class OpenAIEngineTests: XCTestCase {
    var engine: OpenAIEngine!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = LLMHTTPClient(session: session, timeout: 1.0, retryDelay: 0)
        engine = OpenAIEngine(model: .mini54, apiKey: "sk-test", httpClient: client)
    }

    override func tearDown() { MockURLProtocol.reset(); super.tearDown() }

    func test_process_returns_processedText_with_cost() async throws {
        let url = Bundle.module.url(forResource: "openai-mini-success", withExtension: "json", subdirectory: "Fixtures")!
        let fixtureData = try Data(contentsOf: url)
        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.absoluteString, "https://api.openai.com/v1/responses")
            XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, fixtureData)
        }
        let result = try await engine.process(transcript: "hallo wie gehts", mode: .social, language: .german)
        XCTAssertEqual(result.text, "Hallo, wie geht es dir heute?")
        XCTAssertEqual(result.tokensIn, 38)
        XCTAssertEqual(result.tokensOut, 9)
        XCTAssertEqual(result.provider, .openAI)
        XCTAssertEqual(result.model, "gpt-5.4-mini")
        XCTAssertEqual(result.costUSD!, (38.0/1_000_000 * 0.75) + (9.0/1_000_000 * 4.5), accuracy: 0.0000001)
    }
}
```

- [ ] **Step 5.3: Test laufen, schlägt fehl**

```bash
cd Packages/NotikaPostProcessing && swift test --filter OpenAIEngineTests
```

- [ ] **Step 5.4: OpenAIRequest.swift**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/OpenAI/OpenAIRequest.swift`:

```swift
import Foundation

struct OpenAIRequest: Encodable {
    let model: String
    let instructions: String
    let input: String
    let temperature: Double
    let max_output_tokens: Int
}
```

- [ ] **Step 5.5: OpenAIResponse.swift**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/OpenAI/OpenAIResponse.swift`:

```swift
import Foundation

struct OpenAIResponse: Decodable {
    struct OutputItem: Decodable {
        struct ContentPart: Decodable {
            let type: String
            let text: String?
        }
        let type: String
        let role: String?
        let content: [ContentPart]?
    }
    struct Usage: Decodable {
        let input_tokens: Int
        let output_tokens: Int
    }
    let model: String
    let output: [OutputItem]
    let usage: Usage

    var firstText: String {
        for item in output {
            if let parts = item.content {
                for part in parts where part.type == "output_text" {
                    if let text = part.text { return text }
                }
            }
        }
        return ""
    }
}
```

- [ ] **Step 5.6: OpenAIEngine.swift**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/OpenAI/OpenAIEngine.swift`:

```swift
import Foundation
import NotikaCore
import os

public final class OpenAIEngine: PostProcessingEngine {
    public let id: PostProcessingEngineID = .openAI

    private let model: OpenAIModel
    private let apiKey: String
    private let client: LLMHTTPClient
    private let logger = Logger(subsystem: "com.notika.mac", category: "PostProcessing.OpenAI")

    public init(model: OpenAIModel, apiKey: String, httpClient: LLMHTTPClient = LLMHTTPClient()) {
        self.model = model
        self.apiKey = apiKey
        self.client = httpClient
    }

    public func process(transcript: String, mode: DictationMode, language: Language) async throws -> ProcessedText {
        guard !transcript.isEmpty else {
            return ProcessedText(text: transcript, provider: .openAI, model: model.rawValue)
        }
        let instructions = PromptStore.effectivePrompt(for: mode)
            + "\n\nAntworte in der Sprache des Eingabetextes (Deutsch oder Englisch)."

        let body = OpenAIRequest(
            model: model.rawValue,
            instructions: instructions,
            input: transcript,
            temperature: temperature(for: mode),
            max_output_tokens: 1024
        )

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)

        logger.info("→ OpenAI \(self.model.rawValue, privacy: .public), \(transcript.count) chars")
        let data = try await client.send(req)

        let decoded: OpenAIResponse
        do {
            decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            logger.error("Decode-Fehler: \(error.localizedDescription, privacy: .public)")
            throw LLMError.invalidResponse
        }
        let cost = CostCalculator.cost(modelID: model.rawValue, tokensIn: decoded.usage.input_tokens, tokensOut: decoded.usage.output_tokens)
        logger.info("← OpenAI OK, in=\(decoded.usage.input_tokens) out=\(decoded.usage.output_tokens) cost=\(cost ?? 0)")
        return ProcessedText(
            text: decoded.firstText,
            costUSD: cost,
            tokensIn: decoded.usage.input_tokens,
            tokensOut: decoded.usage.output_tokens,
            provider: .openAI,
            model: decoded.model
        )
    }

    private func temperature(for mode: DictationMode) -> Double {
        switch mode {
        case .literal: return 0.05
        case .social:  return 0.6
        case .formal:  return 0.2
        }
    }
}
```

- [ ] **Step 5.7: Tests grün**

```bash
cd Packages/NotikaPostProcessing && swift test --filter OpenAIEngineTests
```

- [ ] **Step 5.8: Commit**

```bash
git add Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/OpenAI Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/OpenAIEngineTests.swift Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/openai-mini-success.json
git commit -m "Phase 1b-1 #5: OpenAIEngine mit Responses-API und Tests"
```

---

## Task 6: GoogleEngine (kann an Subagent „impl-google" delegiert werden)

**Files:**
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Google/GoogleRequest.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Google/GoogleResponse.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Google/GoogleEngine.swift`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/google-flash-success.json`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/GoogleEngineTests.swift`

Google Gemini: `POST https://generativelanguage.googleapis.com/v1beta/models/<MODEL>:generateContent`. Request hat `contents`, `system_instruction`, `generationConfig`. Response: `candidates[0].content.parts[0].text` + `usageMetadata.promptTokenCount` / `candidatesTokenCount`.

- [ ] **Step 6.1: Fixture**

`Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/google-flash-success.json`:

```json
{
  "candidates": [
    {
      "content": {
        "parts": [{ "text": "Hallo, wie geht es dir?" }],
        "role": "model"
      },
      "finishReason": "STOP"
    }
  ],
  "usageMetadata": {
    "promptTokenCount": 30,
    "candidatesTokenCount": 8,
    "totalTokenCount": 38
  },
  "modelVersion": "gemini-2.5-flash"
}
```

- [ ] **Step 6.2: Failing test**

`Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/GoogleEngineTests.swift`:

```swift
import XCTest
@testable import NotikaPostProcessing
import NotikaCore

final class GoogleEngineTests: XCTestCase {
    var engine: GoogleEngine!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = LLMHTTPClient(session: session, timeout: 1.0, retryDelay: 0)
        engine = GoogleEngine(model: .flash25, apiKey: "g-test", httpClient: client)
    }

    override func tearDown() { MockURLProtocol.reset(); super.tearDown() }

    func test_process_returns_processedText_with_cost() async throws {
        let url = Bundle.module.url(forResource: "google-flash-success", withExtension: "json", subdirectory: "Fixtures")!
        let fixtureData = try Data(contentsOf: url)
        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.absoluteString, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")
            XCTAssertEqual(req.value(forHTTPHeaderField: "x-goog-api-key"), "g-test")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, fixtureData)
        }
        let result = try await engine.process(transcript: "hallo", mode: .social, language: .german)
        XCTAssertEqual(result.text, "Hallo, wie geht es dir?")
        XCTAssertEqual(result.tokensIn, 30)
        XCTAssertEqual(result.tokensOut, 8)
        XCTAssertEqual(result.provider, .google)
        XCTAssertEqual(result.model, "gemini-2.5-flash")
        XCTAssertEqual(result.costUSD!, (30.0/1_000_000 * 0.30) + (8.0/1_000_000 * 2.50), accuracy: 0.0000001)
    }
}
```

- [ ] **Step 6.3: Test schlägt fehl**

```bash
cd Packages/NotikaPostProcessing && swift test --filter GoogleEngineTests
```

- [ ] **Step 6.4: GoogleRequest.swift**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Google/GoogleRequest.swift`:

```swift
import Foundation

struct GoogleRequest: Encodable {
    struct Part: Encodable { let text: String }
    struct Content: Encodable { let parts: [Part]; let role: String? }
    struct SystemInstruction: Encodable { let parts: [Part] }
    struct GenerationConfig: Encodable {
        let temperature: Double
        let maxOutputTokens: Int
    }

    let contents: [Content]
    let systemInstruction: SystemInstruction
    let generationConfig: GenerationConfig

    enum CodingKeys: String, CodingKey {
        case contents
        case systemInstruction = "system_instruction"
        case generationConfig
    }
}
```

- [ ] **Step 6.5: GoogleResponse.swift**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Google/GoogleResponse.swift`:

```swift
import Foundation

struct GoogleResponse: Decodable {
    struct Part: Decodable { let text: String? }
    struct Content: Decodable { let parts: [Part] }
    struct Candidate: Decodable {
        let content: Content
    }
    struct UsageMetadata: Decodable {
        let promptTokenCount: Int
        let candidatesTokenCount: Int
    }
    let candidates: [Candidate]
    let usageMetadata: UsageMetadata
    let modelVersion: String?

    var firstText: String {
        candidates.first?.content.parts.first?.text ?? ""
    }
}
```

- [ ] **Step 6.6: GoogleEngine.swift**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Google/GoogleEngine.swift`:

```swift
import Foundation
import NotikaCore
import os

public final class GoogleEngine: PostProcessingEngine {
    public let id: PostProcessingEngineID = .google

    private let model: GoogleModel
    private let apiKey: String
    private let client: LLMHTTPClient
    private let logger = Logger(subsystem: "com.notika.mac", category: "PostProcessing.Google")

    public init(model: GoogleModel, apiKey: String, httpClient: LLMHTTPClient = LLMHTTPClient()) {
        self.model = model
        self.apiKey = apiKey
        self.client = httpClient
    }

    public func process(transcript: String, mode: DictationMode, language: Language) async throws -> ProcessedText {
        guard !transcript.isEmpty else {
            return ProcessedText(text: transcript, provider: .google, model: model.rawValue)
        }
        let systemPrompt = PromptStore.effectivePrompt(for: mode)
            + "\n\nAntworte in der Sprache des Eingabetextes (Deutsch oder Englisch)."

        let body = GoogleRequest(
            contents: [.init(parts: [.init(text: transcript)], role: "user")],
            systemInstruction: .init(parts: [.init(text: systemPrompt)]),
            generationConfig: .init(temperature: temperature(for: mode), maxOutputTokens: 1024)
        )

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model.rawValue):generateContent"
        var req = URLRequest(url: URL(string: urlString)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = try JSONEncoder().encode(body)

        logger.info("→ Google \(self.model.rawValue, privacy: .public), \(transcript.count) chars")
        let data = try await client.send(req)

        let decoded: GoogleResponse
        do {
            decoded = try JSONDecoder().decode(GoogleResponse.self, from: data)
        } catch {
            logger.error("Decode-Fehler: \(error.localizedDescription, privacy: .public)")
            throw LLMError.invalidResponse
        }
        let cost = CostCalculator.cost(modelID: model.rawValue, tokensIn: decoded.usageMetadata.promptTokenCount, tokensOut: decoded.usageMetadata.candidatesTokenCount)
        logger.info("← Google OK, in=\(decoded.usageMetadata.promptTokenCount) out=\(decoded.usageMetadata.candidatesTokenCount) cost=\(cost ?? 0)")
        return ProcessedText(
            text: decoded.firstText,
            costUSD: cost,
            tokensIn: decoded.usageMetadata.promptTokenCount,
            tokensOut: decoded.usageMetadata.candidatesTokenCount,
            provider: .google,
            model: decoded.modelVersion ?? model.rawValue
        )
    }

    private func temperature(for mode: DictationMode) -> Double {
        switch mode {
        case .literal: return 0.05
        case .social:  return 0.6
        case .formal:  return 0.2
        }
    }
}
```

- [ ] **Step 6.7: Tests grün**

```bash
cd Packages/NotikaPostProcessing && swift test --filter GoogleEngineTests
```

- [ ] **Step 6.8: Commit**

```bash
git add Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Google Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/GoogleEngineTests.swift Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/google-flash-success.json
git commit -m "Phase 1b-1 #6: GoogleEngine mit generateContent-API und Tests"
```

---

## Task 7: OllamaEngine + ModelDiscovery

**Files:**
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Ollama/OllamaModelDiscovery.swift`
- Create: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Ollama/OllamaEngine.swift`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/ollama-tags.json`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/ollama-chat-success.json`
- Create: `Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/OllamaEngineTests.swift`

Ollama bietet `GET /api/tags` (für Modell-Liste) und `POST /v1/chat/completions` (OpenAI-kompatibel).

- [ ] **Step 7.1: Fixtures anlegen**

`ollama-tags.json`:
```json
{ "models": [
  { "name": "llama3.2:latest", "modified_at": "2026-04-01T12:00:00Z", "size": 2000000000 },
  { "name": "qwen2.5:7b", "modified_at": "2026-04-02T12:00:00Z", "size": 4500000000 }
]}
```

`ollama-chat-success.json` (OpenAI-kompatibles Format):
```json
{
  "id": "chatcmpl-x",
  "model": "llama3.2:latest",
  "choices": [{
    "index": 0,
    "message": { "role": "assistant", "content": "Hallo, wie geht es dir?" },
    "finish_reason": "stop"
  }],
  "usage": { "prompt_tokens": 22, "completion_tokens": 7, "total_tokens": 29 }
}
```

- [ ] **Step 7.2: Failing tests**

`Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/OllamaEngineTests.swift`:

```swift
import XCTest
@testable import NotikaPostProcessing
import NotikaCore

final class OllamaEngineTests: XCTestCase {

    func test_modelDiscovery_returns_installed_models() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let url = Bundle.module.url(forResource: "ollama-tags", withExtension: "json", subdirectory: "Fixtures")!
        let fixtureData = try Data(contentsOf: url)
        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.absoluteString, "http://localhost:11434/api/tags")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, fixtureData)
        }
        let discovery = OllamaModelDiscovery(session: session)
        let models = try await discovery.installedModels()
        XCTAssertEqual(models, ["llama3.2:latest", "qwen2.5:7b"])
        MockURLProtocol.reset()
    }

    func test_modelDiscovery_throws_unavailable_when_server_down() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        MockURLProtocol.requestHandler = { _ in throw URLError(.cannotConnectToHost) }
        let discovery = OllamaModelDiscovery(session: session)
        do {
            _ = try await discovery.installedModels()
            XCTFail("should throw")
        } catch let err as LLMError {
            XCTAssertEqual(err, .ollamaUnavailable)
        } catch {
            XCTFail("wrong error: \(error)")
        }
        MockURLProtocol.reset()
    }

    func test_engine_process_returns_processedText_with_zero_cost() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = LLMHTTPClient(session: session, timeout: 1.0, retryDelay: 0)
        let url = Bundle.module.url(forResource: "ollama-chat-success", withExtension: "json", subdirectory: "Fixtures")!
        let fixtureData = try Data(contentsOf: url)
        MockURLProtocol.requestHandler = { req in
            XCTAssertEqual(req.url?.absoluteString, "http://localhost:11434/v1/chat/completions")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, fixtureData)
        }
        let engine = OllamaEngine(modelID: "llama3.2:latest", httpClient: client)
        let result = try await engine.process(transcript: "hallo", mode: .literal, language: .german)
        XCTAssertEqual(result.text, "Hallo, wie geht es dir?")
        XCTAssertEqual(result.tokensIn, 22)
        XCTAssertEqual(result.tokensOut, 7)
        XCTAssertEqual(result.provider, .ollama)
        XCTAssertEqual(result.model, "llama3.2:latest")
        XCTAssertNil(result.costUSD)   // Ollama nicht in PricingTable
        MockURLProtocol.reset()
    }
}
```

- [ ] **Step 7.3: Test schlägt fehl**

```bash
cd Packages/NotikaPostProcessing && swift test --filter OllamaEngineTests
```

- [ ] **Step 7.4: OllamaModelDiscovery.swift**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Ollama/OllamaModelDiscovery.swift`:

```swift
import Foundation

public final class OllamaModelDiscovery: Sendable {
    private let session: URLSession
    private let baseURL: URL

    public init(session: URLSession = .shared,
                baseURL: URL = URL(string: "http://localhost:11434")!) {
        self.session = session
        self.baseURL = baseURL
    }

    private struct TagsResponse: Decodable {
        struct Model: Decodable { let name: String }
        let models: [Model]
    }

    public func installedModels() async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw LLMError.ollamaUnavailable
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw LLMError.ollamaUnavailable
        }
        let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
        return decoded.models.map(\.name)
    }
}
```

- [ ] **Step 7.5: OllamaEngine.swift (nutzt OpenAI-kompatibles Format)**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Ollama/OllamaEngine.swift`:

```swift
import Foundation
import NotikaCore
import os

public final class OllamaEngine: PostProcessingEngine {
    public let id: PostProcessingEngineID = .ollama

    private let modelID: String
    private let baseURL: URL
    private let client: LLMHTTPClient
    private let logger = Logger(subsystem: "com.notika.mac", category: "PostProcessing.Ollama")

    public init(modelID: String,
                baseURL: URL = URL(string: "http://localhost:11434")!,
                httpClient: LLMHTTPClient = LLMHTTPClient()) {
        self.modelID = modelID
        self.baseURL = baseURL
        self.client = httpClient
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        struct Usage: Decodable {
            let prompt_tokens: Int
            let completion_tokens: Int
        }
        let model: String
        let choices: [Choice]
        let usage: Usage?
    }

    public func process(transcript: String, mode: DictationMode, language: Language) async throws -> ProcessedText {
        guard !transcript.isEmpty else {
            return ProcessedText(text: transcript, provider: .ollama, model: modelID)
        }
        let systemPrompt = PromptStore.effectivePrompt(for: mode)
            + "\n\nAntworte in der Sprache des Eingabetextes (Deutsch oder Englisch)."

        let body = ChatRequest(
            model: modelID,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: transcript)
            ],
            temperature: temperature(for: mode),
            max_tokens: 1024
        )

        var req = URLRequest(url: baseURL.appendingPathComponent("v1/chat/completions"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)

        logger.info("→ Ollama \(self.modelID, privacy: .public), \(transcript.count) chars")
        let data: Data
        do {
            data = try await client.send(req)
        } catch let err as LLMError {
            // Wenn der Server gar nicht da ist, hat LLMHTTPClient .network geworfen.
            // Wir mappen das auf .ollamaUnavailable für klare UI-Meldung.
            if case .network = err { throw LLMError.ollamaUnavailable }
            throw err
        }

        let decoded: ChatResponse
        do {
            decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            logger.error("Decode-Fehler: \(error.localizedDescription, privacy: .public)")
            throw LLMError.invalidResponse
        }
        let text = decoded.choices.first?.message.content ?? ""
        return ProcessedText(
            text: text,
            costUSD: nil,                                  // lokal = 0 USD
            tokensIn: decoded.usage?.prompt_tokens,
            tokensOut: decoded.usage?.completion_tokens,
            provider: .ollama,
            model: decoded.model
        )
    }

    private func temperature(for mode: DictationMode) -> Double {
        switch mode {
        case .literal: return 0.05
        case .social:  return 0.6
        case .formal:  return 0.2
        }
    }
}
```

- [ ] **Step 7.6: Tests grün**

```bash
cd Packages/NotikaPostProcessing && swift test --filter OllamaEngineTests
```

- [ ] **Step 7.7: Commit**

```bash
git add Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/Ollama Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/OllamaEngineTests.swift Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/ollama-tags.json Packages/NotikaPostProcessing/Tests/NotikaPostProcessingTests/Fixtures/ollama-chat-success.json
git commit -m "Phase 1b-1 #7: OllamaEngine + ModelDiscovery mit Tests"
```

---

## Task 8: PostProcessingEngineFactory mit allen 4 Providern verdrahten

**Files:**
- Modify: `Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/PostProcessingEngineFactory.swift`

- [ ] **Step 8.1: Factory um alle Provider erweitern**

`Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/PostProcessingEngineFactory.swift` komplett ersetzen:

```swift
import Foundation
import NotikaCore

public enum PostProcessingEngineFactory {
    /// Liefert die passende Engine-Instanz für eine LLMChoice.
    /// - Returns: `nil` für `.none` oder wenn ein Cloud-Provider ohne Key konfiguriert ist
    ///   → DictationCoordinator fällt automatisch auf das Rohtranskript zurück.
    public static func makeEngine(for choice: LLMChoice) -> PostProcessingEngine? {
        switch choice {
        case .none:
            return nil
        case .appleFoundationModels:
            return FoundationModelsEngine()
        case .anthropic(let model):
            guard let key = KeychainStore.key(for: .anthropic) else { return nil }
            return AnthropicEngine(model: model, apiKey: key)
        case .openAI(let model):
            guard let key = KeychainStore.key(for: .openAI) else { return nil }
            return OpenAIEngine(model: model, apiKey: key)
        case .google(let model):
            guard let key = KeychainStore.key(for: .google) else { return nil }
            return GoogleEngine(model: model, apiKey: key)
        case .ollama(let modelID):
            return OllamaEngine(modelID: modelID)
        }
    }
}
```

- [ ] **Step 8.2: Build muss grün sein**

```bash
xcodebuild -workspace Notika.xcodeproj/project.xcworkspace -scheme Notika -destination 'platform=macOS' build 2>&1 | tail -5
```

- [ ] **Step 8.3: Commit**

```bash
git add Packages/NotikaPostProcessing/Sources/NotikaPostProcessing/PostProcessingEngineFactory.swift
git commit -m "Phase 1b-1 #8: Factory dispatcht alle 4 Provider mit Keychain-Lookup"
```

---

## Task 9: DictationCoordinator — Override + LLMError-Fallback + Cost-Recording

**Files:**
- Modify: `Notika/DictationCoordinator.swift`

- [ ] **Step 9.1: CostStore-Property + Pipeline-Update**

Im `DictationCoordinator` (`Notika/DictationCoordinator.swift`):

Property unter `private let textInserter` einfügen:

```swift
    private let costStore = CostStore()
```

`runPipeline(mode:audioURL:)` so umstellen, dass LLM-Fehler abgefangen werden und CostStore.record gerufen wird. Den `if let engine = ...`-Block (Zeilen ca. 159-170 nach Step 1.11) ersetzen durch:

```swift
                    if let engine = self.makePostProcessingEngine(for: mode) {
                        self.overlay.updateState(.processing(mode: mode))
                        do {
                            let result = try await engine.process(
                                transcript: transcript.text,
                                mode: mode,
                                language: .german
                            )
                            processed = result.text.isEmpty ? transcript.text : result.text
                            if let model = result.model,
                               let tIn = result.tokensIn,
                               let tOut = result.tokensOut {
                                self.costStore.record(modelID: model, tokensIn: tIn, tokensOut: tOut)
                            }
                            self.logger.info("Transkript final (LLM): \(processed, privacy: .public)")
                        } catch let err as LLMError {
                            self.logger.warning("LLM-Fehler: \(String(describing: err), privacy: .public) — Rohtext-Fallback")
                            processed = transcript.text
                            self.overlay.updateState(.error(message: err.userFacingMessage))
                            try? await Task.sleep(for: .seconds(2))
                        }
                    } else {
```

- [ ] **Step 9.2: Build und manueller Smoketest**

```bash
xcodebuild -workspace Notika.xcodeproj/project.xcworkspace -scheme Notika -destination 'platform=macOS' build 2>&1 | tail -5
```

App starten, ein Diktat in Mode 1 mit Default `appleFoundationModels` machen — soll wie in Phase 1a funktionieren (keine Regression).

- [ ] **Step 9.3: Commit**

```bash
git add Notika/DictationCoordinator.swift
git commit -m "Phase 1b-1 #9: Coordinator dispatcht Pro-Modus + fängt LLMError ab + recordet Cost"
```

---

## Task 10: Settings → EnginesTab Redesign

**Files:**
- Modify: `Notika/Settings/EnginesTab.swift` (komplette Neuschreibung)
- Create: `Notika/Settings/EnginesTab+ProviderRows.swift`
- Create: `Notika/Settings/EnginesTab+OllamaSection.swift`

- [ ] **Step 10.1: Neue Haupt-Datei EnginesTab.swift**

`Notika/Settings/EnginesTab.swift` komplett ersetzen:

```swift
import SwiftUI
import NotikaCore
import NotikaPostProcessing

/// Provider-Kategorie für den Top-Picker. Mappt auf konkrete LLMChoice-cases.
enum ProviderKind: String, CaseIterable, Identifiable {
    case none, apple, anthropic, openAI, google, ollama
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:      return "Kein KI-Helfer — Text bleibt wie gesprochen"
        case .apple:     return "Apple (gratis, läuft auf deinem Mac)"
        case .anthropic: return "Claude (von Anthropic, kostenpflichtig)"
        case .openAI:    return "ChatGPT (von OpenAI, kostenpflichtig)"
        case .google:    return "Gemini (von Google, kostenpflichtig)"
        case .ollama:    return "Lokales Modell via Ollama"
        }
    }
}

extension LLMChoice {
    var kind: ProviderKind {
        switch self {
        case .none:                  return .none
        case .appleFoundationModels: return .apple
        case .anthropic:             return .anthropic
        case .openAI:                return .openAI
        case .google:                return .google
        case .ollama:                return .ollama
        }
    }
}

struct EnginesTab: View {
    @State private var settings = SettingsStore()
    @State private var globalKind: ProviderKind = .apple
    @State private var anthropicModel: AnthropicModel = .haiku45
    @State private var openAIModel: OpenAIModel = .mini54
    @State private var googleModel: GoogleModel = .flash25
    @State private var ollamaModel: String = ""
    @State private var showAdvanced = false

    var body: some View {
        Form {
            Section {
                Picker("Wer poliert deinen Text? (LLM)", selection: $globalKind) {
                    ForEach(ProviderKind.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: globalKind) { _, _ in writeGlobal() }

                Group {
                    switch globalKind {
                    case .anthropic: AnthropicProviderRow(model: $anthropicModel) { writeGlobal() }
                    case .openAI:    OpenAIProviderRow(model: $openAIModel) { writeGlobal() }
                    case .google:    GoogleProviderRow(model: $googleModel) { writeGlobal() }
                    case .ollama:    OllamaSection(modelID: $ollamaModel) { writeGlobal() }
                    case .apple, .none: EmptyView()
                    }
                }
            } header: {
                Text("Standard für alle Modi")
            }

            Section {
                DisclosureGroup("Erweitert: Pro Modus überschreiben", isExpanded: $showAdvanced) {
                    ForEach(DictationMode.allCases) { mode in
                        ModeOverrideRow(mode: mode, settings: settings)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { loadFromSettings() }
    }

    private func loadFromSettings() {
        let choice = settings.globalLLMChoice
        globalKind = choice.kind
        switch choice {
        case .anthropic(let m): anthropicModel = m
        case .openAI(let m):    openAIModel = m
        case .google(let m):    googleModel = m
        case .ollama(let id):   ollamaModel = id
        default: break
        }
    }

    private func writeGlobal() {
        let new: LLMChoice
        switch globalKind {
        case .none:      new = .none
        case .apple:     new = .appleFoundationModels
        case .anthropic: new = .anthropic(anthropicModel)
        case .openAI:    new = .openAI(openAIModel)
        case .google:    new = .google(googleModel)
        case .ollama:    new = .ollama(modelID: ollamaModel)
        }
        settings.globalLLMChoice = new
    }
}

private struct ModeOverrideRow: View {
    let mode: DictationMode
    @Bindable var settings: SettingsStore
    @State private var useGlobal: Bool = true

    var body: some View {
        HStack {
            Text(mode.displayName)
            Spacer()
            // Vereinfachte Override-UI: nur Toggle „nutzt Standard" — vollständige
            // Sub-Picker pro Modus folgen, wenn User es braucht. Für Phase 1b-1 reicht
            // das, weil der Backlog „Pro-Modus-Override" als Power-Feature flaggt.
            Toggle("Standard", isOn: $useGlobal)
                .onChange(of: useGlobal) { _, on in
                    if on { settings.setOverride(nil, for: mode) }
                }
        }
        .task {
            useGlobal = settings.override(for: mode) == nil
        }
    }
}

#Preview { EnginesTab().frame(width: 640, height: 520) }
```

> **Hinweis zum Override-UI:** Vereinfachung dokumentiert — full per-mode Picker (mit Provider-Auswahl) liegt in Phase 1b-1 nicht im kritischen Pfad. Wenn der Smoketest in Task 16 zeigt, dass Power-User mehr brauchen, wird in Step 10.4 nachgezogen.

- [ ] **Step 10.2: ProviderRows-Subviews**

`Notika/Settings/EnginesTab+ProviderRows.swift`:

```swift
import SwiftUI
import NotikaCore
import NotikaPostProcessing

struct AnthropicProviderRow: View {
    @Binding var model: AnthropicModel
    @State private var apiKey: String = ""
    @State private var testStatus: TestStatus = .idle
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Modell", selection: $model) {
                ForEach(AnthropicModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .onChange(of: model) { _, _ in onChange() }

            HStack {
                SecureField("API-Key", text: $apiKey)
                Button("Testen") { testKey() }
                    .disabled(apiKey.isEmpty)
            }
            testStatus.label
        }
        .task {
            apiKey = KeychainStore.key(for: .anthropic) ?? ""
        }
        .onChange(of: apiKey) { _, new in
            KeychainStore.setKey(new.isEmpty ? nil : new, for: .anthropic)
        }
    }

    private func testKey() {
        testStatus = .checking
        let chosen = model
        let key = apiKey
        Task {
            let engine = AnthropicEngine(model: chosen, apiKey: key)
            do {
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
                await MainActor.run { testStatus = .ok }
            } catch let err as LLMError {
                await MainActor.run { testStatus = .fail(err.userFacingMessage) }
            } catch {
                await MainActor.run { testStatus = .fail("Unbekannter Fehler") }
            }
        }
    }
}

struct OpenAIProviderRow: View {
    @Binding var model: OpenAIModel
    @State private var apiKey: String = ""
    @State private var testStatus: TestStatus = .idle
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Modell", selection: $model) {
                ForEach(OpenAIModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .onChange(of: model) { _, _ in onChange() }

            HStack {
                SecureField("API-Key", text: $apiKey)
                Button("Testen") { testKey() }
                    .disabled(apiKey.isEmpty)
            }
            testStatus.label
        }
        .task { apiKey = KeychainStore.key(for: .openAI) ?? "" }
        .onChange(of: apiKey) { _, new in
            KeychainStore.setKey(new.isEmpty ? nil : new, for: .openAI)
        }
    }

    private func testKey() {
        testStatus = .checking
        let chosen = model
        let key = apiKey
        Task {
            let engine = OpenAIEngine(model: chosen, apiKey: key)
            do {
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
                await MainActor.run { testStatus = .ok }
            } catch let err as LLMError {
                await MainActor.run { testStatus = .fail(err.userFacingMessage) }
            } catch {
                await MainActor.run { testStatus = .fail("Unbekannter Fehler") }
            }
        }
    }
}

struct GoogleProviderRow: View {
    @Binding var model: GoogleModel
    @State private var apiKey: String = ""
    @State private var testStatus: TestStatus = .idle
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Modell", selection: $model) {
                ForEach(GoogleModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .onChange(of: model) { _, _ in onChange() }

            HStack {
                SecureField("API-Key", text: $apiKey)
                Button("Testen") { testKey() }
                    .disabled(apiKey.isEmpty)
            }
            testStatus.label
        }
        .task { apiKey = KeychainStore.key(for: .google) ?? "" }
        .onChange(of: apiKey) { _, new in
            KeychainStore.setKey(new.isEmpty ? nil : new, for: .google)
        }
    }

    private func testKey() {
        testStatus = .checking
        let chosen = model
        let key = apiKey
        Task {
            let engine = GoogleEngine(model: chosen, apiKey: key)
            do {
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
                await MainActor.run { testStatus = .ok }
            } catch let err as LLMError {
                await MainActor.run { testStatus = .fail(err.userFacingMessage) }
            } catch {
                await MainActor.run { testStatus = .fail("Unbekannter Fehler") }
            }
        }
    }
}

enum TestStatus {
    case idle, checking, ok, fail(String)

    @ViewBuilder var label: some View {
        switch self {
        case .idle: EmptyView()
        case .checking:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Teste …") }
                .foregroundStyle(.secondary).font(.footnote)
        case .ok:
            Label("Schlüssel gültig", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.footnote)
        case .fail(let msg):
            Label(msg, systemImage: "xmark.octagon.fill")
                .foregroundStyle(.red).font(.footnote)
        }
    }
}
```

- [ ] **Step 10.3: OllamaSection-Subview**

`Notika/Settings/EnginesTab+OllamaSection.swift`:

```swift
import SwiftUI
import NotikaPostProcessing

struct OllamaSection: View {
    @Binding var modelID: String
    @State private var status: OllamaStatus = .idle
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                switch status {
                case .idle, .loading:
                    Picker("Modell", selection: $modelID) {
                        Text("(noch keine Auswahl)").tag("")
                    }
                    .disabled(true)
                case .available(let models):
                    Picker("Modell", selection: $modelID) {
                        ForEach(models, id: \.self) { Text($0).tag($0) }
                    }
                    .onChange(of: modelID) { _, _ in onChange() }
                case .empty, .unavailable:
                    Picker("Modell", selection: $modelID) {
                        Text("(keine Modelle)").tag("")
                    }
                    .disabled(true)
                }
                Button("Aktualisieren") { Task { await refresh() } }
            }
            statusBanner
        }
        .task { await refresh() }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch status {
        case .idle, .loading:
            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Suche Modelle …") }
                .font(.footnote).foregroundStyle(.secondary)
        case .available:
            Label("Verbunden mit localhost:11434", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.footnote)
        case .empty:
            VStack(alignment: .leading, spacing: 4) {
                Label("Ollama läuft, aber keine Modelle installiert.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).font(.footnote)
                Text("Im Terminal: `ollama pull llama3.2`")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        case .unavailable:
            VStack(alignment: .leading, spacing: 4) {
                Label("Ollama scheint nicht zu laufen.", systemImage: "xmark.octagon")
                    .foregroundStyle(.red).font(.footnote)
                Link("Ollama herunterladen", destination: URL(string: "https://ollama.com/download")!)
                    .font(.footnote)
            }
        }
    }

    private func refresh() async {
        status = .loading
        let discovery = OllamaModelDiscovery()
        do {
            let models = try await discovery.installedModels()
            if models.isEmpty {
                status = .empty
            } else {
                status = .available(models)
                if modelID.isEmpty || !models.contains(modelID) {
                    modelID = models.first(where: { $0.contains(":latest") }) ?? models.first ?? ""
                    onChange()
                }
            }
        } catch {
            status = .unavailable
        }
    }

    enum OllamaStatus {
        case idle, loading, available([String]), empty, unavailable
    }
}
```

- [ ] **Step 10.4: Build + manueller UI-Check**

```bash
xcodebuild -workspace Notika.xcodeproj/project.xcworkspace -scheme Notika -destination 'platform=macOS' build 2>&1 | tail -5
```

App starten, Settings → Engines öffnen, Provider-Picker durchklicken, sehen ob die richtigen Sub-Views erscheinen. Apple zeigt nichts, Ollama startet Discovery.

- [ ] **Step 10.5: Commit**

```bash
git add Notika/Settings/EnginesTab.swift Notika/Settings/EnginesTab+ProviderRows.swift Notika/Settings/EnginesTab+OllamaSection.swift
git commit -m "Phase 1b-1 #10: Engines-Tab Redesign mit 4 Provider-Sektionen + Override-DisclosureGroup"
```

---

## Task 11: Onboarding-Step „KI-Helfer"

**Files:**
- Create: `Notika/Onboarding/LLMSetupStep.swift`
- Modify: `Notika/Onboarding/OnboardingFlow.swift`

- [ ] **Step 11.1: LLMSetupStep.swift erstellen**

`Notika/Onboarding/LLMSetupStep.swift`:

```swift
import SwiftUI
import NotikaCore
import NotikaPostProcessing

struct LLMSetupStep: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var settings = SettingsStore()
    @State private var kind: ProviderKind = .apple
    @State private var anthropicModel: AnthropicModel = .haiku45
    @State private var openAIModel: OpenAIModel = .mini54
    @State private var googleModel: GoogleModel = .flash25
    @State private var apiKey: String = ""
    @State private var ollamaModel: String = ""
    @State private var inlineError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer().frame(height: 12)

            VStack(alignment: .leading, spacing: 6) {
                Text("Wer poliert deinen Text? (LLM)")
                    .font(.title).bold()
                Text("Optional — du kannst es jetzt einrichten oder später in den Einstellungen.")
                    .foregroundStyle(.secondary)
            }

            Picker("KI-Helfer", selection: $kind) {
                ForEach(ProviderKind.allCases) { k in
                    Text(k.displayName).tag(k)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            switch kind {
            case .apple, .none:
                EmptyView()
            case .anthropic:
                Picker("Modell", selection: $anthropicModel) {
                    ForEach(AnthropicModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                SecureField("API-Key (sk-ant-…)", text: $apiKey)
            case .openAI:
                Picker("Modell", selection: $openAIModel) {
                    ForEach(OpenAIModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                SecureField("API-Key (sk-…)", text: $apiKey)
            case .google:
                Picker("Modell", selection: $googleModel) {
                    ForEach(GoogleModel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                SecureField("API-Key", text: $apiKey)
            case .ollama:
                OllamaSection(modelID: $ollamaModel) {}
            }

            if let inlineError {
                Label(inlineError, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Spacer()

            HStack {
                Button("Überspringen") {
                    settings.globalLLMChoice = .appleFoundationModels   // Wahl 6b
                    UserDefaults.standard.set(false, forKey: "notika.onboarding.llmStepCompleted")
                    onSkip()
                }
                Spacer()
                Button("Weiter") {
                    Task { await commit() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 16)
    }

    private func commit() async {
        inlineError = nil
        switch kind {
        case .none:
            settings.globalLLMChoice = .none
        case .apple:
            settings.globalLLMChoice = .appleFoundationModels
        case .anthropic:
            guard !apiKey.isEmpty else { inlineError = "API-Key fehlt"; return }
            do {
                let engine = AnthropicEngine(model: anthropicModel, apiKey: apiKey)
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
            } catch let err as LLMError {
                inlineError = err.userFacingMessage; return
            } catch {
                inlineError = "Unbekannter Fehler"; return
            }
            KeychainStore.setKey(apiKey, for: .anthropic)
            settings.globalLLMChoice = .anthropic(anthropicModel)
        case .openAI:
            guard !apiKey.isEmpty else { inlineError = "API-Key fehlt"; return }
            do {
                let engine = OpenAIEngine(model: openAIModel, apiKey: apiKey)
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
            } catch let err as LLMError {
                inlineError = err.userFacingMessage; return
            } catch {
                inlineError = "Unbekannter Fehler"; return
            }
            KeychainStore.setKey(apiKey, for: .openAI)
            settings.globalLLMChoice = .openAI(openAIModel)
        case .google:
            guard !apiKey.isEmpty else { inlineError = "API-Key fehlt"; return }
            do {
                let engine = GoogleEngine(model: googleModel, apiKey: apiKey)
                _ = try await engine.process(transcript: "ping", mode: .literal, language: .german)
            } catch let err as LLMError {
                inlineError = err.userFacingMessage; return
            } catch {
                inlineError = "Unbekannter Fehler"; return
            }
            KeychainStore.setKey(apiKey, for: .google)
            settings.globalLLMChoice = .google(googleModel)
        case .ollama:
            guard !ollamaModel.isEmpty else { inlineError = "Bitte ein Modell wählen"; return }
            settings.globalLLMChoice = .ollama(modelID: ollamaModel)
        }
        UserDefaults.standard.set(true, forKey: "notika.onboarding.llmStepCompleted")
        onContinue()
    }
}
```

- [ ] **Step 11.2: OnboardingFlow.swift mit neuem Step erweitern**

In `Notika/Onboarding/OnboardingFlow.swift` enum ergänzen:

```swift
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case permissions
    case llmSetup
    case finished

    var title: String {
        switch self {
        case .welcome:     return "Willkommen bei Notika"
        case .permissions: return "Berechtigungen erteilen"
        case .llmSetup:    return "KI-Helfer einrichten"
        case .finished:    return "Alles bereit"
        }
    }
}
```

Im `body`-switch nach `.permissions`-Case einsetzen:

```swift
                case .permissions:
                    PermissionsStep(checker: checker) {
                        step = .llmSetup
                    }
                case .llmSetup:
                    LLMSetupStep(
                        onContinue: { step = .finished },
                        onSkip:     { step = .finished }
                    )
```

- [ ] **Step 11.3: Build und manueller Onboarding-Run**

```bash
xcodebuild -workspace Notika.xcodeproj/project.xcworkspace -scheme Notika -destination 'platform=macOS' build 2>&1 | tail -5
```

App-Daten löschen (oder UserDefaults-Key `notika.hasCompletedOnboarding` zurücksetzen), App starten, Onboarding durchklicken — neuen Step muss erscheinen, Skip muss zu `.finished` führen, Apple-Auswahl + Weiter ebenfalls.

- [ ] **Step 11.4: Commit**

```bash
git add Notika/Onboarding/LLMSetupStep.swift Notika/Onboarding/OnboardingFlow.swift
git commit -m "Phase 1b-1 #11: Onboarding-Step KI-Helfer mit Skip + inline Key-Test"
```

---

## Task 12: First-Use-Hint bei Mode 2/3 wenn Onboarding-Step geskippt

**Files:**
- Modify: `Notika/DictationCoordinator.swift`
- Create: `Notika/Overlay/LLMHintSheet.swift`
- Modify: `Notika/AppDelegate.swift`

- [ ] **Step 12.1: LLMHintSheet.swift erstellen**

`Notika/Overlay/LLMHintSheet.swift`:

```swift
import SwiftUI

struct LLMHintSheet: View {
    let onOpenSettings: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Tipp: Mit KI-Helfer wird's besser")
                .font(.title2).bold()
            Text("Mit einem Cloud-LLM oder Ollama wird das Ergebnis deutlich besser. Jetzt einrichten?")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            HStack {
                Button("Später", action: onLater)
                Spacer()
                Button("Einstellungen öffnen") { onOpenSettings() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(28)
        .frame(width: 420)
    }
}
```

- [ ] **Step 12.2: AppDelegate-Methode für Hint-Sheet**

In `Notika/AppDelegate.swift` Methode hinzufügen (genaue Position siehe bestehende `showOnboarding()`-Methode):

```swift
    func showLLMHintSheet() {
        let view = LLMHintSheet(
            onOpenSettings: { [weak self] in
                self?.dismissActiveSheet()
                if #available(macOS 13, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                NSApp.activate(ignoringOtherApps: true)
            },
            onLater: { [weak self] in
                self?.dismissActiveSheet()
            }
        )
        presentSheet(view: AnyView(view))
    }
```

(Falls AppDelegate noch keine `presentSheet`/`dismissActiveSheet`-Helfer hat, neue Methoden anlegen, die ein NSWindow mit NSHostingController halten — analog zur bestehenden `showOnboarding()`-Methode.)

- [ ] **Step 12.3: Coordinator-Hook für First-Use-Hint**

In `Notika/DictationCoordinator.swift` neue Methode am Ende der Klasse:

```swift
    /// Zeigt einmalig den First-Use-Hint, wenn der Onboarding-Step geskippt wurde
    /// und der User Mode 2 oder 3 nutzt.
    private func maybeShowFirstUseHint(mode: DictationMode) {
        let stepCompleted = UserDefaults.standard.bool(forKey: "notika.onboarding.llmStepCompleted")
        let alreadyShown  = UserDefaults.standard.bool(forKey: "notika.hint.llmShown")
        guard !stepCompleted, !alreadyShown, mode != .literal else { return }
        UserDefaults.standard.set(true, forKey: "notika.hint.llmShown")
        AppDelegate.shared?.showLLMHintSheet()
    }
```

Im `beginRecording(mode:)` als allerersten Schritt aufrufen:

```swift
    private func beginRecording(mode: DictationMode) {
        maybeShowFirstUseHint(mode: mode)
        guard activeMode == nil else { return }
        // … Rest unverändert
    }
```

- [ ] **Step 12.4: Build und manueller Test**

```bash
xcodebuild -workspace Notika.xcodeproj/project.xcworkspace -scheme Notika -destination 'platform=macOS' build 2>&1 | tail -5
```

UserDefaults zurücksetzen (z.B. `defaults delete <bundle-id> notika.hint.llmShown && defaults write <bundle-id> notika.onboarding.llmStepCompleted -bool false`), App starten, Mode 2 triggern → Hint erscheint einmalig.

- [ ] **Step 12.5: Commit**

```bash
git add Notika/Overlay/LLMHintSheet.swift Notika/AppDelegate.swift Notika/DictationCoordinator.swift
git commit -m "Phase 1b-1 #12: First-Use-Hint einmalig bei Mode 2/3 wenn Onboarding geskippt"
```

---

## Task 13: Menübar-Cost-Indikator

**Files:**
- Modify: `Notika/MenuBar/MenuBarContent.swift`

- [ ] **Step 13.1: MenuBarContent erweitern**

`Notika/MenuBar/MenuBarContent.swift` ersetzen:

```swift
import SwiftUI
import NotikaCore
import NotikaPostProcessing

struct MenuBarContent: View {
    @Environment(\.openSettings) private var openSettings
    @AppStorage("notika.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var costStore = CostStore()
    @State private var todaySnap: CostSnapshot = .init()
    @State private var monthSnap: CostSnapshot = .init()

    var body: some View {
        Group {
            Text("Notika")
                .font(.headline)

            Divider()

            ForEach(DictationMode.allCases) { mode in
                Label(mode.displayName, systemImage: iconName(for: mode))
                    .foregroundStyle(.secondary)
            }

            Divider()

            costSection

            Divider()

            if !hasCompletedOnboarding {
                Button("Einrichtung fortsetzen …") {
                    AppDelegate.shared?.showOnboarding()
                }
            }

            Button("Einstellungen …") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: [.command])

            Button("Berechtigungen prüfen …") {
                AppDelegate.shared?.showOnboarding()
            }

            Divider()

            Button("Notika beenden") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: [.command])
        }
        .onAppear { refresh() }
    }

    @ViewBuilder
    private var costSection: some View {
        Text(String(format: "Heute: %.2f $ · %d Diktate", todaySnap.totalUSD, todaySnap.callCount))
            .foregroundStyle(.secondary)
        Text(String(format: "Diesen Monat: %.2f $", monthSnap.totalUSD))
            .foregroundStyle(.secondary)
            .font(.caption)
        Button("Tageszähler zurücksetzen") {
            costStore.resetToday()
            refresh()
        }
    }

    private func refresh() {
        todaySnap = costStore.today()
        monthSnap = costStore.thisMonth()
    }

    private func iconName(for mode: DictationMode) -> String {
        switch mode {
        case .literal: return "text.bubble"
        case .social:  return "face.smiling"
        case .formal:  return "envelope"
        }
    }
}
```

- [ ] **Step 13.2: Build und sichtprüfen**

```bash
xcodebuild -workspace Notika.xcodeproj/project.xcworkspace -scheme Notika -destination 'platform=macOS' build 2>&1 | tail -5
```

Menübar öffnen, Tag/Monat-Zeilen müssen erscheinen mit `0,00 $ · 0 Diktate` initial.

- [ ] **Step 13.3: Commit**

```bash
git add Notika/MenuBar/MenuBarContent.swift
git commit -m "Phase 1b-1 #13: Menübar zeigt Tages-/Monatskosten + Reset-Button"
```

---

## Task 14: Pill-Fehler-State (orange) für „KI-Helfer offline"

**Files:**
- Modify: `Notika/Overlay/PillView.swift`

Der Coordinator nutzt schon `overlay.updateState(.error(message:))` (in Step 9.1 ergänzt). Wir müssen nur sichern, dass die Pill bei `.error`-State eine sichtbar andere (orange) Farbe nutzt — falls das schon der Fall ist, wird dieser Task minimal.

- [ ] **Step 14.1: PillView prüfen**

`Notika/Overlay/PillView.swift` öffnen und das Color-Mapping für `.error` ansehen.

```bash
grep -n "error" Notika/Overlay/PillView.swift
```

- [ ] **Step 14.2: Falls noch nicht orange: anpassen**

Im PillView muss für `.error` ein orange Hintergrund kommen, z.B. (Beispiel — exakte Stelle abhängig vom existierenden Code):

```swift
private var background: Color {
    switch model.state {
    case .recording:    return .red.opacity(0.85)
    case .transcribing: return .blue.opacity(0.85)
    case .processing:   return .purple.opacity(0.85)
    case .inserting:    return .green.opacity(0.85)
    case .error:        return .orange.opacity(0.9)
    case .idle:         return .clear
    }
}
```

- [ ] **Step 14.3: Manueller Test**

App starten mit ungültigem Anthropic-Key (`anthropic` als globalLLMChoice + bewusst falscher Key in Keychain), Mode 1 triggern — Pill muss orange werden mit Text „Schlüssel ungültig — in Einstellungen prüfen".

- [ ] **Step 14.4: Commit**

```bash
git add Notika/Overlay/PillView.swift
git commit -m "Phase 1b-1 #14: Pill orange für LLM-Fehler-Fallback"
```

---

## Task 15: Info.plist — `NSAllowsLocalNetworking` für Ollama

**Files:**
- Modify: `Notika/Info.plist` (oder die zugehörige `project.yml`-Sektion falls xcodegen)

- [ ] **Step 15.1: project.yml prüfen**

```bash
grep -n "NSApp" project.yml ; grep -n "Info.plist" project.yml
```

Wenn `project.yml` Info.plist-Einträge generiert, dort hinzufügen. Sonst direkt in `Notika/Info.plist`.

- [ ] **Step 15.2: NSAppTransportSecurity-Eintrag**

In der entsprechenden `Info.plist` (oder im `info`-Block der `project.yml`):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

Falls per xcodegen: `xcodegen generate` ausführen.

- [ ] **Step 15.3: Build + Test mit Ollama**

```bash
xcodebuild -workspace Notika.xcodeproj/project.xcworkspace -scheme Notika -destination 'platform=macOS' build 2>&1 | tail -5
```

Mit laufendem Ollama (`ollama serve` + `ollama pull llama3.2`) Settings → Engines → Ollama → Modell wählen → Mode 1 diktieren — muss durchlaufen.

- [ ] **Step 15.4: Commit**

```bash
git add Notika/Info.plist project.yml Notika.xcodeproj
git commit -m "Phase 1b-1 #15: NSAllowsLocalNetworking für Ollama auf localhost"
```

---

## Task 16: Smoketest-Doku + Akzeptanz-Run

**Files:**
- Create: `docs/PHASE_1B_1_SMOKETEST.md`

- [ ] **Step 16.1: Smoketest-Checkliste schreiben**

`docs/PHASE_1B_1_SMOKETEST.md`:

```markdown
# Phase 1b-1 Smoketest — Multi-LLM-Engines

Manuelle Akzeptanz-Tests vor dem Commit „Phase 1b-1 done".

## Vorbereitung
- macOS 26 Tahoe, Apple Silicon
- Notika frisch installiert oder `defaults delete <bundle-id>` gefolgt von Neustart
- Bereit gehaltene API-Keys: Anthropic, OpenAI, Google
- Lokal laufender Ollama (`ollama serve`), `ollama pull llama3.2` ausgeführt

## Onboarding
- [ ] Onboarding zeigt 4 Steps: Welcome, Permissions, KI-Helfer, Fertig
- [ ] „KI-Helfer überspringen" speichert Apple Foundation Models als Default
- [ ] „KI-Helfer Claude + Key + Weiter" mit gültigem Key → Step schließt; mit ungültigem → bleibt offen mit roter Meldung

## Settings → Engines
- [ ] Provider-Picker zeigt 6 Optionen
- [ ] Wechsel zwischen Providern blendet passende Sub-UI ein
- [ ] Anthropic: Modell-Picker, Key-Feld, Testen-Button — grün/rot in <3 s
- [ ] OpenAI: dito
- [ ] Google: dito
- [ ] Ollama: Modell-Picker zeigt installierte Modelle, „Aktualisieren" funktioniert
- [ ] Ollama mit gestopptem Server: zeigt rote Hinweis + Download-Link
- [ ] Erweitert-DisclosureGroup: 3 Modus-Zeilen, Toggle „Standard" funktioniert

## Diktat-Pipeline pro Provider
Für jeden der 4 Provider × 3 Modi (= 12 Tests):
- [ ] Hotkey halten, sprechen, loslassen → Text erscheint im fokussierten Programm
- [ ] Pill zeigt richtige States: Recording → Transcribing → Processing → Inserting
- [ ] Console-Log enthält keine API-Keys, keinen Diktat-Inhalt im Klartext bei Cloud-Calls

## Cost-Indikator
- [ ] Nach 1 Cloud-Diktat: Menübar „Heute"-Zeile erhöht sich
- [ ] Nach 1 Apple/Ollama-Diktat: „Diktate"-Zähler erhöht, USD bleibt 0,00
- [ ] „Tageszähler zurücksetzen" → Heute=0
- [ ] Monats-Zeile bleibt nach Tagesreset stehen

## Fehler-Pfade
- [ ] Anthropic ohne Key (`KeychainStore.setKey(nil, …)` simulieren) → Pill zeigt „KI-Helfer offline" orange, Rohtext landet im Programm
- [ ] Anthropic mit ungültigem Key → Pill zeigt „Schlüssel ungültig — in Einstellungen prüfen", Rohtext landet
- [ ] WLAN aus → Diktat → Pill „KI-Helfer offline", Rohtext landet
- [ ] Ollama-Server gestoppt → Pill „Ollama nicht erreichbar", Rohtext landet

## First-Use-Hint
- [ ] `notika.onboarding.llmStepCompleted = false`, `notika.hint.llmShown` gelöscht
- [ ] Mode 2 oder 3 starten → Hint-Sheet erscheint einmalig
- [ ] Sheet schließen, Mode 2 erneut starten → Hint kommt **nicht** wieder

## Migration
- [ ] Phase-1a-Build laufen lassen, dann Phase-1b-1-Build → `notika.settings.llmChoice` ist weg, `notika.settings.globalLLMChoice` enthält Apple-Foundation-Default
- [ ] Diktat funktioniert weiterhin

## Sicherheit
- [ ] Console-Logs prüfen (`log stream --predicate 'subsystem == "com.notika.mac"'`) — keine Keys, keine Diktat-Inhalte bei Cloud
- [ ] Keychain Access App: Einträge `app.notika.apikey.anthropic/openai/google` vorhanden, Werte verschlüsselt

## Build/Signatur
- [ ] `codesign -dvv /Applications/Notika.app` zeigt Team `P7QK554EET`
- [ ] Bedienungshilfen-Toggle bleibt nach Rebuild stabil
```

- [ ] **Step 16.2: Alle Unit-Tests final laufen lassen**

```bash
cd Packages/NotikaCore && swift test
cd ../NotikaPostProcessing && swift test
```

Alle grün.

- [ ] **Step 16.3: Smoketest manuell durchgehen**

Checkliste oben Schritt für Schritt abhaken. Bei Failures: zugehörigen Task neu öffnen, fixen, neuen Commit.

- [ ] **Step 16.4: Final-Commit**

```bash
git add docs/PHASE_1B_1_SMOKETEST.md
git commit -m "Phase 1b-1 #16: Smoketest-Doku + Akzeptanz dokumentiert"
```

- [ ] **Step 16.5: Memory updaten + STATUS.md aktualisieren**

Schreibe in `docs/STATUS.md` neue Sektion:

```markdown
## Phase 1b-1 abgeschlossen (TT.MM.2026)

- 4 LLM-Provider als BYOK: Anthropic, OpenAI, Google, Ollama
- Hybrid-Wahl (global + Pro-Modus-Override) funktional
- Cost-Indikator im Menübar (Tag/Monat)
- API-Keys in Keychain
- 1× Retry → Rohtext-Fallback bei API-Fehler
- Migration vom Phase-1a-Default sauber

Nächste Sub-Phase: 1b-2 (whisper.cpp lokale STT)
```

```bash
git add docs/STATUS.md
git commit -m "Phase 1b-1 abgeschlossen — Status-Update"
```

---

## Subagent-Strategie für die Implementation

Die Tasks 4, 5, 6 (Anthropic / OpenAI / Google) sind strukturell identisch und können **parallel** an drei Subagents delegiert werden, sobald Tasks 1-3 (Foundation, Networking, Costs) im Hauptkontext fertig sind. Subagent-Briefing:

> „Implementiere Task N aus `docs/superpowers/plans/2026-04-18-notika-phase-1b-1-multi-llm.md`. Lies zuerst den Spec-Abschnitt 4.3 und die Tasks 1-3 (LLMHTTPClient, LLMError, ProcessedText, PostProcessingEngine-Protokoll) und folge dann den Steps des Tasks exakt. Commit am Ende. Falls die Pricing-Werte deinen Recherchen widersprechen, melde es zurück, fix nicht selbst."

Task 7 (Ollama) hängt von Task 5 (OpenAI-Format als Vorbild) ab — danach starten. Tasks 8-15 sind UI-cross-cutting und besser im Hauptkontext.
