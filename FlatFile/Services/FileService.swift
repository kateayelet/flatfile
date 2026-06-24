//
//  FileService.swift
//  FlatFile
//
//  Files API, folder access, read/write
//

import Foundation

enum FileServiceError: LocalizedError {
    case invalidCSV
    case notText

    var errorDescription: String? {
        switch self {
        case .invalidCSV:
            return "The selected file does not contain a valid CSV header row."
        case .notText:
            return "This file isn't UTF-8 text, so it can't be opened as a CSV."
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

    /// Coordinated read. Strips a UTF-8 BOM if present and rejects non-UTF-8
    /// (binary) input gracefully rather than crashing.
    static func readText(from url: URL) throws -> String {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        var data = Data()
        var readError: Error?
        var coordError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { resolved in
            do { data = try Data(contentsOf: resolved) }
            catch { readError = error }
        }
        if let readError { throw readError }
        if let coordError { throw coordError }

        // Strip a UTF-8 BOM (EF BB BF) — it otherwise prefixes the first header.
        let bom: [UInt8] = [0xEF, 0xBB, 0xBF]
        if data.starts(with: bom) { data.removeFirst(bom.count) }

        guard let text = String(data: data, encoding: .utf8) else {
            throw FileServiceError.notText
        }
        return text
    }

    /// Coordinated, atomic write — an interrupted write never truncates the
    /// file, and iCloud/Files providers see a consistent change. UTF-8, no BOM.
    static func writeText(_ text: String, to url: URL) throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        let data = Data(text.utf8)
        var writeError: Error?
        var coordError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { resolved in
            do { try data.write(to: resolved, options: .atomic) }
            catch { writeError = error }
        }
        if let writeError { throw writeError }
        if let coordError { throw coordError }
    }
}
