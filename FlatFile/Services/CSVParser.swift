//
//  CSVParser.swift
//  FlatFile
//
//  RFC 4180 compliant CSV parser and serializer.
//  Supports auto-detection of delimiters (comma, tab, semicolon, pipe).
//

import Foundation

enum CSVParser {

    // MARK: - Delimiter Detection

    static func detectDelimiter(_ csv: String) -> Character {
        let candidates: [Character] = [",", "\t", ";", "|"]
        let firstLine = csv.prefix(while: { $0 != "\n" && $0 != "\r" })
        var best: Character = ","
        var bestCount = 0
        for d in candidates {
            let count = firstLine.filter { $0 == d }.count
            if count > bestCount {
                bestCount = count
                best = d
            }
        }
        return best
    }

    // MARK: - Parsing

    static func parse(_ csv: String, delimiter: Character = ",") -> [[String]] {
        guard !csv.isEmpty else { return [] }

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""

        enum State {
            case fieldStart
            case unquoted
            case quoted
            case afterQuote
        }

        var state: State = .fieldStart
        let chars = Array(csv)
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            switch state {

            case .fieldStart:
                if ch == "\"" {
                    state = .quoted
                } else if ch == delimiter {
                    currentRow.append(currentField)
                    currentField = ""
                } else if ch == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    if i + 1 < chars.count && chars[i + 1] == "\n" {
                        i += 1
                    }
                } else if ch == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                } else {
                    currentField.append(ch)
                    state = .unquoted
                }

            case .unquoted:
                if ch == delimiter {
                    currentRow.append(currentField)
                    currentField = ""
                    state = .fieldStart
                } else if ch == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    if i + 1 < chars.count && chars[i + 1] == "\n" {
                        i += 1
                    }
                    state = .fieldStart
                } else if ch == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    state = .fieldStart
                } else {
                    currentField.append(ch)
                }

            case .quoted:
                if ch == "\"" {
                    state = .afterQuote
                } else {
                    currentField.append(ch)
                }

            case .afterQuote:
                if ch == "\"" {
                    currentField.append("\"")
                    state = .quoted
                } else if ch == delimiter {
                    currentRow.append(currentField)
                    currentField = ""
                    state = .fieldStart
                } else if ch == "\r" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    if i + 1 < chars.count && chars[i + 1] == "\n" {
                        i += 1
                    }
                    state = .fieldStart
                } else if ch == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    state = .fieldStart
                } else {
                    currentField.append("\"")
                    currentField.append(ch)
                    state = .unquoted
                }
            }

            i += 1
        }

        switch state {
        case .quoted, .afterQuote:
            currentRow.append(currentField)
        default:
            currentRow.append(currentField)
        }

        let isBlank = currentRow.count == 1 && currentRow[0].isEmpty
        if !isBlank {
            rows.append(currentRow)
        }

        while let last = rows.last, last.count == 1, last[0].isEmpty {
            rows.removeLast()
        }

        return rows
    }

    // MARK: - Serialization

    static func serialize(_ rows: [[String]], delimiter: Character = ",") -> String {
        let delimStr = String(delimiter)
        let lines = rows.map { row in
            row.map { field in
                escapeField(field, delimiter: delimiter)
            }.joined(separator: delimStr)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escapeField(_ field: String, delimiter: Character = ",") -> String {
        let needsQuoting = field.contains(String(delimiter))
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")

        if needsQuoting {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }

        return field
    }
}
