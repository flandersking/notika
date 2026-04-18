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
