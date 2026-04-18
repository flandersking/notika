import Foundation
import NotikaCore

public enum DictionaryCSV {
    public enum Row: Sendable, Equatable {
        case ok(term: String, language: Language, category: DictionaryCategory)
        case skip(line: Int, reason: String)
    }

    /// Export im Format:
    /// ```
    /// term;language;category
    /// Mdymny;de;names
    /// ```
    public static func export(terms: [DictionaryTerm], to url: URL) throws {
        var lines: [String] = ["term;language;category"]
        for t in terms {
            let term = escape(t.term)
            let lang = t.languageRawValue
            let cat = t.categoryRawValue
            lines.append("\(term);\(lang);\(cat)")
        }
        let csv = lines.joined(separator: "\n")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw DictionaryError.fileWriteFailed
        }
    }

    public static func importRows(from url: URL) throws -> [Row] {
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Fallback Latin-1 (Windows/Excel-DE)
            if let fallback = try? String(contentsOf: url, encoding: .isoLatin1) {
                content = fallback
            } else {
                throw DictionaryError.fileReadFailed
            }
        }
        return parse(content)
    }

    /// Exposed für Tests.
    public static func parse(_ content: String) -> [Row] {
        let lines = content.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" }).map(String.init)
        guard !lines.isEmpty else { return [] }

        // Erste Zeile = Header. Wir prüfen nicht streng, aber skippen sie.
        var result: [Row] = []
        let delimiter = detectDelimiter(lines.first ?? "")

        for (index, line) in lines.enumerated() {
            if index == 0 { continue }   // Header skip
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let parts = splitCSVLine(trimmed, delimiter: delimiter)
            let lineNo = index + 1
            guard parts.count == 3 else {
                result.append(.skip(line: lineNo, reason: "Falsche Anzahl Spalten"))
                continue
            }
            let rawTerm = unescape(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawLang = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let rawCat = parts[2].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            guard !rawTerm.isEmpty else {
                result.append(.skip(line: lineNo, reason: "Leerer Begriff"))
                continue
            }
            guard let language = Language(rawValue: rawLang) else {
                result.append(.skip(line: lineNo, reason: "Unbekannte Sprache"))
                continue
            }
            let category = DictionaryCategory(rawValue: rawCat) ?? .general
            result.append(.ok(term: rawTerm, language: language, category: category))
        }
        return result
    }

    /// Splittet eine CSV-Zeile quote-aware: Delimiter innerhalb von "..."-Feldern werden ignoriert.
    /// `""` innerhalb eines quoted-Feldes bleibt als `""` stehen (wird von `unescape` entfernt).
    private static func splitCSVLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if c == "\"" {
                // Lookahead: doppelt-Quote innerhalb eines quoted-Feldes = escaped Quote
                let next = line.index(after: i)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    current.append("\"")
                    current.append("\"")
                    i = line.index(after: next)
                    continue
                }
                current.append(c)
                inQuotes.toggle()
            } else if c == delimiter, !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(c)
            }
            i = line.index(after: i)
        }
        fields.append(current)
        return fields
    }

    private static func detectDelimiter(_ header: String) -> Character {
        // Semikolon bevorzugt (Excel-DE), Komma als Fallback.
        return header.contains(";") ? ";" : ","
    }

    private static func escape(_ s: String) -> String {
        if s.contains(";") || s.contains(",") || s.contains("\"") || s.contains("\n") {
            let inner = s.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(inner)\""
        }
        return s
    }

    private static func unescape(_ s: String) -> String {
        var t = s
        if t.hasPrefix("\"") && t.hasSuffix("\"") && t.count >= 2 {
            t = String(t.dropFirst().dropLast())
            t = t.replacingOccurrences(of: "\"\"", with: "\"")
        }
        return t
    }
}
