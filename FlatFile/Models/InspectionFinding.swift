//
//  InspectionFinding.swift
//  FlatFile
//
//  One data-quality observation surfaced by the Inspect view. FlatFile reports;
//  it never auto-fixes. Every cell stays exactly as the user wrote it.
//

import Foundation

struct InspectionFinding: Identifiable {
    enum Kind {
        case raggedRows          // rows whose field count differs from the header (in the file)
        case duplicateRows       // exact-duplicate data rows
        case emptyInFullColumn   // blank cells in a column that is otherwise populated
        case spreadsheetUnsafe   // leading-zero or very long numerics other apps would mangle
        case mixedDateFormats    // a column mixing two or more date layouts
        case untrimmedWhitespace // cells with leading/trailing whitespace

        var symbol: String {
            switch self {
            case .raggedRows: return "rectangle.split.3x1"
            case .duplicateRows: return "doc.on.doc"
            case .emptyInFullColumn: return "square.dashed"
            case .spreadsheetUnsafe: return "0.square"
            case .mixedDateFormats: return "calendar.badge.exclamationmark"
            case .untrimmedWhitespace: return "space"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let summary: String
    /// Human-readable sample locations, e.g. ["Row 5", "Row 12", "Column \"date\""].
    let samples: [String]
}
