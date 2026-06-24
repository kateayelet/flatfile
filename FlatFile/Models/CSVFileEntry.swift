//
//  CSVFileEntry.swift
//  FlatFile
//
//  One .csv file inside a connected folder.
//

import Foundation

struct CSVFileEntry: Identifiable, Hashable {
    let url: URL
    /// True when a same-named `.md` sits next to the `.csv` (FlatNote pairing).
    let hasPairedNote: Bool

    var id: URL { url }

    /// File name with extension, e.g. "expenses.csv".
    var fileName: String { url.lastPathComponent }

    /// Display name without the extension, e.g. "expenses".
    var displayName: String { url.deletingPathExtension().lastPathComponent }
}
