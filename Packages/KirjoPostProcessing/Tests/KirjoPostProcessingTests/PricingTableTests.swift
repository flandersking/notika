import XCTest
@testable import NotikaPostProcessing

final class PricingTableTests: XCTestCase {

    func test_allEntries_haveCorrectPrices() {
        let expected: [(String, Double, Double)] = [
            ("claude-haiku-4-5",                1.00,  5.00),
            ("claude-sonnet-4-6",               3.00, 15.00),
            ("claude-opus-4-7",                 5.00, 25.00),
            ("gpt-5.4-nano",                    0.20,  1.25),
            ("gpt-5.4-mini",                    0.75,  4.50),
            ("gpt-5.4",                         2.50, 15.00),
            ("gemini-3.1-flash-lite-preview",   0.25,  1.50),
            ("gemini-2.5-flash",                0.30,  2.50),
            ("gemini-3.1-pro-preview",          2.00, 12.00),
        ]
        for (modelID, expectedIn, expectedOut) in expected {
            guard let entry = PricingTable.entry(for: modelID) else {
                XCTFail("Pricing-Eintrag für \(modelID) fehlt")
                continue
            }
            XCTAssertEqual(entry.inputUSDPerMillion,  expectedIn,  accuracy: 0.0001, "Input-Preis falsch für \(modelID)")
            XCTAssertEqual(entry.outputUSDPerMillion, expectedOut, accuracy: 0.0001, "Output-Preis falsch für \(modelID)")
        }
    }

    func test_unknownModel_returnsNil() {
        XCTAssertNil(PricingTable.entry(for: "unbekanntes-modell"))
        XCTAssertNil(PricingTable.entry(for: ""))
    }

    func test_entryCount_matchesSpec() {
        XCTAssertEqual(PricingTable.entries.count, 9, "PricingTable sollte genau 9 Einträge haben (3 pro Cloud-Provider). Wenn das fehlschlägt, wurde ein Modell hinzugefügt/entfernt — Test mit aktualisieren.")
    }
}
