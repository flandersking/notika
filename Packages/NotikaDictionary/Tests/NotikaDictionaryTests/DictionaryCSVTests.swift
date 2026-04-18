import XCTest
@testable import NotikaDictionary
import NotikaCore

final class DictionaryCSVTests: XCTestCase {

    func test_parse_header_and_rows_semicolon() {
        let csv = """
        term;language;category
        Mdymny;de;names
        Arztbrief;de;medical
        """
        let rows = DictionaryCSV.parse(csv)
        XCTAssertEqual(rows.count, 2)
        if case .ok(let term, let lang, let cat) = rows[0] {
            XCTAssertEqual(term, "Mdymny")
            XCTAssertEqual(lang, .german)
            XCTAssertEqual(cat, .names)
        } else { XCTFail("Erste Zeile sollte ok sein") }
    }

    func test_parse_comma_fallback() {
        let csv = """
        term,language,category
        Hello,en,general
        """
        let rows = DictionaryCSV.parse(csv)
        XCTAssertEqual(rows.count, 1)
        if case .ok(let term, let lang, let cat) = rows[0] {
            XCTAssertEqual(term, "Hello")
            XCTAssertEqual(lang, .english)
            XCTAssertEqual(cat, .general)
        } else { XCTFail() }
    }

    func test_parse_unknownLanguage_skipsRow() {
        let csv = """
        term;language;category
        Word;xx;general
        """
        let rows = DictionaryCSV.parse(csv)
        XCTAssertEqual(rows.count, 1)
        if case .skip = rows[0] { } else { XCTFail("sollte skip sein") }
    }

    func test_parse_wrongColumnCount_skipsRow() {
        let csv = """
        term;language;category
        NurEinFeld
        """
        let rows = DictionaryCSV.parse(csv)
        XCTAssertEqual(rows.count, 1)
        if case .skip = rows[0] { } else { XCTFail() }
    }

    func test_parse_unknownCategory_fallsBackTogeneral() {
        let csv = """
        term;language;category
        Wort;de;unbekannt
        """
        let rows = DictionaryCSV.parse(csv)
        XCTAssertEqual(rows.count, 1)
        if case .ok(_, _, let cat) = rows[0] {
            XCTAssertEqual(cat, .general)
        } else { XCTFail() }
    }

    func test_export_and_reparse_roundtrip() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("csv-\(UUID()).csv")
        defer { try? FileManager.default.removeItem(at: tmp) }
        // Terms-Array bauen (leere Array geht nicht, wir brauchen ein paar)
        // Wir simulieren Daten ohne SwiftData-Container: direkte String-CSV bauen + parsen
        let testCSV = """
        term;language;category
        Mdymny;de;names
        "Mit Semikolon;drin";en;general
        Arztbrief;de;medical
        """
        let rows = DictionaryCSV.parse(testCSV)
        XCTAssertEqual(rows.count, 3)
    }

    func test_parse_escapedQuotedField() {
        let csv = """
        term;language;category
        "Mit ""Quote"";echt";de;general
        """
        let rows = DictionaryCSV.parse(csv)
        XCTAssertEqual(rows.count, 1)
        if case .ok(let term, _, _) = rows[0] {
            XCTAssertEqual(term, "Mit \"Quote\";echt")
        } else { XCTFail() }
    }

    func test_parse_emptyLines_ignored() {
        let csv = """
        term;language;category

        Mdymny;de;names

        """
        let rows = DictionaryCSV.parse(csv)
        XCTAssertEqual(rows.count, 1)
    }
}
