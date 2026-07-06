//
//  CSVRow.swift
//  FlatFile
//
//  A single row
//

import Foundation

nonisolated struct CSVRow: Identifiable, Hashable {
    let id: UUID
    var values: [String]

    init(id: UUID = UUID(), values: [String]) {
        self.id = id
        self.values = values
    }

    subscript(index: Int) -> String {
        get {
            guard values.indices.contains(index) else { return "" }
            return values[index]
        }
        set {
            if values.indices.contains(index) {
                values[index] = newValue
            } else {
                values.append(contentsOf: Array(repeating: "", count: index - values.count + 1))
                values[index] = newValue
            }
        }
    }
}
