//
//  TableViewModel.swift
//  FlatFile
//
//  Drives TableView, owns file read/write
//

import Foundation
import Observation

@MainActor
@Observable
final class TableViewModel {
    var document: CSVDocument?
    var sourceURL: URL?
    var rawCSVText = ""
    var errorMessage: String?
    var sortColumnIndex: Int?
    var sortAscending = true

    // Search / filter
    var searchQuery = ""
    var filteredRows: [CSVRow] {
        guard let document, !searchQuery.isEmpty else {
            return document?.rows ?? []
        }
        let q = searchQuery.lowercased()
        return document.rows.filter { row in
            row.values.contains { $0.lowercased().contains(q) }
        }
    }
    var matchedRowCount: Int { filteredRows.count }

    // Find & replace
    var findQuery = ""
    var replaceQuery = ""
    var showingFindReplace = false

    var findMatchCount: Int {
        guard let document, !findQuery.isEmpty else { return 0 }
        let q = findQuery.lowercased()
        return document.rows.filter { row in
            row.values.contains { $0.lowercased().contains(q) }
        }.count
    }

    // Column stats
    var statsColumnIndex: Int?
    var showingColumnStats = false

    func columnStats(for columnIndex: Int) -> ColumnStats? {
        guard let document, document.headers.indices.contains(columnIndex) else { return nil }
        let values = document.rows.map { $0[columnIndex] }
        return ColumnStats.compute(values: values)
    }

    // Paperclip
    var pairedMarkdownURL: URL? {
        PaperclipHelper.pairedMarkdownURL(for: sourceURL)
    }

    // MARK: - Document lifecycle

    func createNewDocument(name: String, columnCount: Int = 3, rowCount: Int = 0) {
        let safeColumnCount = max(1, columnCount)
        let safeRowCount = max(0, rowCount)
        let headers = (1...safeColumnCount).map { "column_\($0)" }
        let rows = (0..<safeRowCount).map { _ in
            CSVRow(values: Array(repeating: "", count: safeColumnCount))
        }
        document = CSVDocument(name: name, headers: headers, rows: rows, delimiter: ",")
        sourceURL = nil
        rawCSVText = document?.rawCSV ?? ""
        sortColumnIndex = nil
        errorMessage = nil
    }

    func createFromTemplate(_ template: CSVTemplate, name: String) {
        let rows = template.exampleRows.map { CSVRow(values: $0) }
        document = CSVDocument(name: name, headers: template.headers, rows: rows, delimiter: ",")
        sourceURL = nil
        rawCSVText = document?.rawCSV ?? ""
        sortColumnIndex = nil
        errorMessage = nil
    }

    func openDocument(at url: URL) {
        do {
            let loaded = try FileService.loadDocument(from: url)
            document = loaded
            sourceURL = url
            rawCSVText = loaded.rawCSV
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveDocument() {
        guard let document, let sourceURL else { return }

        do {
            try FileService.saveDocument(document, to: sourceURL)
            rawCSVText = document.rawCSV
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Autosave

    private var saveTask: Task<Void, Never>?

    /// Debounced write to disk after an edit. No-op until the document has a
    /// destination (a brand-new table must be saved once via "Save As" first).
    private func scheduleAutosave() {
        guard sourceURL != nil else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.persistNow()
        }
    }

    /// Writes any pending edit to disk immediately. Safe to call repeatedly.
    func persistNow() {
        saveTask?.cancel()
        guard let document, let sourceURL else { return }
        do {
            try FileService.saveDocument(document, to: sourceURL)
            errorMessage = nil
        } catch {
            errorMessage = "Could not save \"\(document.name).csv\". \(error.localizedDescription)"
        }
    }

    /// Flush before the app backgrounds or the view goes away, so no edit is lost.
    func flush() { persistNow() }

    /// On return to the foreground, pick up edits made to the file elsewhere
    /// (Files app, another device via iCloud), but never clobber an in-progress
    /// edit: if a save is still pending, the user's version wins.
    func reloadIfChanged() {
        guard let sourceURL, saveTask == nil, let document else { return }
        guard let disk = try? FileService.readText(from: sourceURL), disk != document.rawCSV else { return }
        let delimiter = CSVParser.detectDelimiter(disk)
        let parsed = CSVParser.parse(disk, delimiter: delimiter)
        guard let headers = parsed.first, !headers.isEmpty else { return }
        _ = headers
        self.document = CSVDocument(name: document.name, parsedRows: parsed, delimiter: delimiter)
        rawCSVText = self.document?.rawCSV ?? ""
    }

    // MARK: - Mutations

    func updateHeader(at index: Int, value: String) {
        guard var document else { return }
        document.updateHeader(at: index, value: value)
        self.document = document
        rawCSVText = document.rawCSV
        scheduleAutosave()
    }

    func updateCell(rowID: UUID, columnIndex: Int, value: String) {
        guard var document else { return }
        document.updateCell(rowID: rowID, columnIndex: columnIndex, value: value)
        self.document = document
        rawCSVText = document.rawCSV
        scheduleAutosave()
    }

    func appendRow(_ values: [String]) {
        guard var document else { return }
        document.appendRow(values)
        self.document = document
        rawCSVText = document.rawCSV
        scheduleAutosave()
    }

    func deleteRow(id: UUID) {
        guard var document else { return }
        document.deleteRow(id: id)
        self.document = document
        rawCSVText = document.rawCSV
        scheduleAutosave()
    }

    func sortByColumn(_ columnIndex: Int) {
        guard var document else { return }
        if sortColumnIndex == columnIndex {
            sortAscending.toggle()
        } else {
            sortColumnIndex = columnIndex
            sortAscending = true
        }
        document.sortByColumn(columnIndex, ascending: sortAscending)
        self.document = document
        rawCSVText = document.rawCSV
        scheduleAutosave()
    }

    // MARK: - Find & Replace

    func replaceOne() {
        guard var document, !findQuery.isEmpty else { return }
        let q = findQuery.lowercased()
        var replaced = false
        for rowIndex in document.rows.indices {
            if replaced { break }
            for colIndex in document.rows[rowIndex].values.indices {
                if replaced { break }
                let cell = document.rows[rowIndex].values[colIndex]
                if cell.lowercased().contains(q) {
                    if let range = cell.range(of: findQuery, options: .caseInsensitive) {
                        document.rows[rowIndex].values[colIndex] = cell.replacingCharacters(in: range, with: replaceQuery)
                        replaced = true
                    }
                }
            }
        }
        self.document = document
        rawCSVText = document.rawCSV
        scheduleAutosave()
    }

    func replaceAll() {
        guard var document, !findQuery.isEmpty else { return }
        for rowIndex in document.rows.indices {
            for colIndex in document.rows[rowIndex].values.indices {
                let cell = document.rows[rowIndex].values[colIndex]
                if cell.lowercased().contains(findQuery.lowercased()) {
                    document.rows[rowIndex].values[colIndex] = cell.replacingOccurrences(
                        of: findQuery,
                        with: replaceQuery,
                        options: .caseInsensitive
                    )
                }
            }
        }
        self.document = document
        rawCSVText = document.rawCSV
        scheduleAutosave()
    }

    // MARK: - Share

    var shareText: String {
        document?.rawCSV ?? ""
    }

    var shareFileName: String {
        (document?.name ?? "export") + ".csv"
    }

    // MARK: - Raw CSV

    func applyRawCSVChanges() {
        let delimiter = CSVParser.detectDelimiter(rawCSVText)
        let parsed = CSVParser.parse(rawCSVText, delimiter: delimiter)
        guard let headers = parsed.first, !headers.isEmpty else {
            errorMessage = FileServiceError.invalidCSV.localizedDescription
            return
        }

        _ = headers
        let currentName = document?.name ?? sourceURL?.deletingPathExtension().lastPathComponent ?? "Imported CSV"
        document = CSVDocument(name: currentName, parsedRows: parsed, delimiter: delimiter)
        errorMessage = nil
        scheduleAutosave()
    }

    func dismissError() {
        errorMessage = nil
    }
}
