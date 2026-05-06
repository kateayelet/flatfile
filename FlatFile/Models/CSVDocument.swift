//
//  CSVDocument.swift
//  FlatFile
//
//  The core data model — a parsed .csv file
//

import Foundation

struct CSVDocument: Identifiable, Hashable {
    let id: UUID
    var name: String
    var headers: [String]
    var rows: [CSVRow]
    var delimiter: Character

    init(
        id: UUID = UUID(),
        name: String,
        headers: [String] = [],
        rows: [CSVRow] = [],
        delimiter: Character = ","
    ) {
        self.id = id
        self.name = name
        self.headers = headers
        self.delimiter = delimiter
        self.rows = rows.map { row in
            CSVRow(id: row.id, values: CSVDocument.normalized(values: row.values, columnCount: headers.count))
        }
    }

    init(name: String, parsedRows: [[String]], delimiter: Character = ",") {
        self.id = UUID()
        self.name = name
        let headers = parsedRows.first ?? []
        self.headers = headers
        self.delimiter = delimiter
        self.rows = parsedRows.dropFirst().map { CSVRow(values: Self.normalized(values: $0, columnCount: headers.count)) }
    }

    var columnCount: Int {
        headers.count
    }

    var rowCount: Int {
        rows.count
    }

    var matrix: [[String]] {
        [headers] + rows.map(\.values)
    }

    var rawCSV: String {
        CSVParser.serialize(matrix, delimiter: delimiter)
    }

    mutating func updateHeader(at index: Int, value: String) {
        guard headers.indices.contains(index) else { return }
        headers[index] = value
    }

    mutating func updateCell(rowID: UUID, columnIndex: Int, value: String) {
        guard let rowIndex = rows.firstIndex(where: { $0.id == rowID }) else { return }
        rows[rowIndex][columnIndex] = value
    }

    mutating func appendRow(_ values: [String]) {
        rows.append(CSVRow(values: Self.normalized(values: values, columnCount: columnCount)))
    }

    mutating func deleteRow(id: UUID) {
        rows.removeAll { $0.id == id }
    }

    mutating func deleteRows(ids: Set<UUID>) {
        rows.removeAll { ids.contains($0.id) }
    }

    mutating func sortByColumn(_ columnIndex: Int, ascending: Bool) {
        guard headers.indices.contains(columnIndex) else { return }
        rows.sort { a, b in
            let lhs = a[columnIndex]
            let rhs = b[columnIndex]
            if let lhsNum = Double(lhs), let rhsNum = Double(rhs) {
                return ascending ? lhsNum < rhsNum : lhsNum > rhsNum
            }
            return ascending
                ? lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                : lhs.localizedCaseInsensitiveCompare(rhs) == .orderedDescending
        }
    }

    private static func normalized(values: [String], columnCount: Int) -> [String] {
        guard columnCount > 0 else { return values }
        if values.count == columnCount {
            return values
        }
        if values.count > columnCount {
            return Array(values.prefix(columnCount))
        }
        return values + Array(repeating: "", count: columnCount - values.count)
    }
}
