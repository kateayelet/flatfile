//
//  InspectService.swift
//  FlatFile
//
//  Read-only data-quality inspection. Surfaces oddities that spreadsheet apps
//  silently "fix" (and thereby corrupt). FlatFile never guesses or rewrites —
//  it just points. Pure functions over the document; no mutation.
//

import Foundation

nonisolated enum InspectService {
    private static let maxSamples = 5

    /// `rawParsedRows` is the file re-parsed without width normalization (header
    /// row included), used only for ragged-row detection — the one check that
    /// can't be made from the in-memory model, which pads/truncates on load.
    static func inspect(_ document: CSVDocument, rawParsedRows: [[String]]?) -> [InspectionFinding] {
        var findings: [InspectionFinding] = []
        if let f = raggedRows(document, rawParsedRows: rawParsedRows) { findings.append(f) }
        if let f = duplicateRows(document) { findings.append(f) }
        if let f = emptyInFullColumn(document) { findings.append(f) }
        if let f = spreadsheetUnsafe(document) { findings.append(f) }
        if let f = mixedDateFormats(document) { findings.append(f) }
        if let f = untrimmedWhitespace(document) { findings.append(f) }
        return findings
    }

    // MARK: - Checks

    private static func raggedRows(_ document: CSVDocument, rawParsedRows: [[String]]?) -> InspectionFinding? {
        guard let raw = rawParsedRows, let header = raw.first else { return nil }
        let width = header.count
        var shortRows: [String] = []
        var longRows: [String] = []
        for (offset, row) in raw.dropFirst().enumerated() {
            if row.count < width { shortRows.append("Row \(offset + 1)") }
            else if row.count > width { longRows.append("Row \(offset + 1)") }
        }
        let total = shortRows.count + longRows.count
        guard total > 0 else { return nil }
        var summary = "\(total) row\(total == 1 ? " has" : "s have") a different number of fields than the \(width)-column header."
        if !longRows.isEmpty {
            summary += " Rows with extra fields were truncated to \(width) columns on open — check those before saving."
        }
        return InspectionFinding(
            kind: .raggedRows,
            title: "Ragged rows",
            summary: summary,
            samples: Array((longRows + shortRows).prefix(maxSamples))
        )
    }

    private static func duplicateRows(_ document: CSVDocument) -> InspectionFinding? {
        var seen: [String: Int] = [:]
        var dupes: [String] = []
        for (index, row) in document.rows.enumerated() {
            let key = row.values.joined(separator: "\u{0}")
            if let first = seen[key] {
                _ = first
                dupes.append("Row \(index + 1)")
            } else {
                seen[key] = index
            }
        }
        guard !dupes.isEmpty else { return nil }
        return InspectionFinding(
            kind: .duplicateRows,
            title: "Duplicate rows",
            summary: "\(dupes.count) row\(dupes.count == 1 ? " is an exact duplicate" : "s are exact duplicates") of an earlier row.",
            samples: Array(dupes.prefix(maxSamples))
        )
    }

    private static func emptyInFullColumn(_ document: CSVDocument) -> InspectionFinding? {
        var columns: [String] = []
        for (col, name) in document.headers.enumerated() {
            var empties = 0
            var nonEmpties = 0
            for row in document.rows {
                if row[col].trimmingCharacters(in: .whitespaces).isEmpty { empties += 1 }
                else { nonEmpties += 1 }
            }
            if empties > 0 && nonEmpties > 0 {
                columns.append("Column \"\(columnLabel(name, col))\" (\(empties) blank)")
            }
        }
        guard !columns.isEmpty else { return nil }
        return InspectionFinding(
            kind: .emptyInFullColumn,
            title: "Blank cells in populated columns",
            summary: "\(columns.count) column\(columns.count == 1 ? " has" : "s have") blank cells while the rest of the column has values.",
            samples: Array(columns.prefix(maxSamples))
        )
    }

    private static func spreadsheetUnsafe(_ document: CSVDocument) -> InspectionFinding? {
        var samples: [String] = []
        var count = 0
        for (index, row) in document.rows.enumerated() {
            for (col, value) in row.values.enumerated() {
                let v = value.trimmingCharacters(in: .whitespaces)
                guard isLeadingZeroNumber(v) || isLongDigitString(v) else { continue }
                count += 1
                if samples.count < maxSamples {
                    let name = document.headers.indices.contains(col) ? document.headers[col] : ""
                    samples.append("Row \(index + 1), \"\(columnLabel(name, col))\": \(value)")
                }
            }
        }
        guard count > 0 else { return nil }
        return InspectionFinding(
            kind: .spreadsheetUnsafe,
            title: "Numbers other apps would alter",
            summary: "\(count) cell\(count == 1 ? " looks" : "s look") numeric with leading zeros or very long digit runs (ZIPs, IDs, card numbers). Spreadsheets drop the zeros or switch to scientific notation. FlatFile keeps them as text.",
            samples: samples
        )
    }

    private static func mixedDateFormats(_ document: CSVDocument) -> InspectionFinding? {
        var columns: [String] = []
        for (col, name) in document.headers.enumerated() {
            var signatures: Set<String> = []
            for row in document.rows {
                let v = row[col].trimmingCharacters(in: .whitespaces)
                if let sig = dateSignature(v) { signatures.insert(sig) }
            }
            if signatures.count >= 2 {
                columns.append("Column \"\(columnLabel(name, col))\": \(signatures.sorted().joined(separator: ", "))")
            }
        }
        guard !columns.isEmpty else { return nil }
        return InspectionFinding(
            kind: .mixedDateFormats,
            title: "Mixed date formats",
            summary: "\(columns.count) column\(columns.count == 1 ? " mixes" : "s mix") two or more date layouts. FlatFile leaves them as written; it won't reformat.",
            samples: Array(columns.prefix(maxSamples))
        )
    }

    private static func untrimmedWhitespace(_ document: CSVDocument) -> InspectionFinding? {
        var samples: [String] = []
        var count = 0
        for (index, row) in document.rows.enumerated() {
            for (col, value) in row.values.enumerated() {
                guard !value.isEmpty, value != value.trimmingCharacters(in: .whitespaces) else { continue }
                count += 1
                if samples.count < maxSamples {
                    let name = document.headers.indices.contains(col) ? document.headers[col] : ""
                    samples.append("Row \(index + 1), \"\(columnLabel(name, col))\"")
                }
            }
        }
        guard count > 0 else { return nil }
        return InspectionFinding(
            kind: .untrimmedWhitespace,
            title: "Leading or trailing spaces",
            summary: "\(count) cell\(count == 1 ? " has" : "s have") surrounding whitespace. Spreadsheets often trim it silently; FlatFile preserves it.",
            samples: samples
        )
    }

    // MARK: - Helpers

    private static func columnLabel(_ name: String, _ index: Int) -> String {
        name.isEmpty ? "Column \(index + 1)" : name
    }

    private static func isLeadingZeroNumber(_ s: String) -> Bool {
        s.count >= 2 && s.first == "0" && s.allSatisfy(\.isNumber)
    }

    private static func isLongDigitString(_ s: String) -> Bool {
        s.count >= 16 && s.allSatisfy(\.isNumber)
    }

    private static func dateSignature(_ s: String) -> String? {
        let patterns: [(String, String)] = [
            (#"^\d{4}-\d{1,2}-\d{1,2}$"#, "YYYY-MM-DD"),
            (#"^\d{1,2}/\d{1,2}/\d{4}$"#, "M/D/YYYY"),
            (#"^\d{1,2}/\d{1,2}/\d{2}$"#, "M/D/YY"),
            (#"^\d{1,2}-\d{1,2}-\d{4}$"#, "M-D-YYYY"),
            (#"^\d{1,2}\.\d{1,2}\.\d{4}$"#, "D.M.YYYY"),
            (#"^\d{4}/\d{1,2}/\d{1,2}$"#, "YYYY/M/D")
        ]
        for (pattern, signature) in patterns {
            if s.range(of: pattern, options: .regularExpression) != nil { return signature }
        }
        return nil
    }
}
