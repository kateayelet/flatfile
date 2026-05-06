//
//  FileService.swift
//  FlatFile
//
//  Files API, folder access, read/write
//

import Foundation

enum FileServiceError: LocalizedError {
    case invalidCSV

    var errorDescription: String? {
        switch self {
        case .invalidCSV:
            return "The selected file does not contain a valid CSV header row."
        }
    }
}

enum FileService {
    static func loadDocument(from url: URL) throws -> CSVDocument {
        let csv = try readText(from: url)
        let delimiter = CSVParser.detectDelimiter(csv)
        let parsed = CSVParser.parse(csv, delimiter: delimiter)
        guard let headers = parsed.first, !headers.isEmpty else {
            throw FileServiceError.invalidCSV
        }

        _ = headers
        return CSVDocument(
            name: url.deletingPathExtension().lastPathComponent,
            parsedRows: parsed,
            delimiter: delimiter
        )
    }

    static func saveDocument(_ document: CSVDocument, to url: URL) throws {
        try writeText(document.rawCSV, to: url)
    }

    static func saveRawCSV(_ rawCSV: String, to url: URL) throws {
        try writeText(rawCSV, to: url)
    }

    static func readText(from url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    static func writeText(_ text: String, to url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
