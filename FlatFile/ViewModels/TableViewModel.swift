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
    var sourceURL: URL? {
        didSet { pairedMarkdownURL = PaperclipHelper.pairedMarkdownURL(for: sourceURL) }
    }
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

    // Inspect / data quality
    var showingInspect = false

    // MARK: - Sidecar (optional `<name>.flatfile` preferences)

    /// In-memory copy of the optional sidecar for the open file. Loaded on open,
    /// applied to the view (display names, intended types, restored sort), and
    /// written back when the user changes a preference. The `.csv` stays the
    /// source of truth; this is purely additive and may be absent.
    private(set) var sidecar = FlatFileSidecar()

    /// The label to show for a column: the sidecar's display name if set, else
    /// the raw `.csv` header.
    func displayName(forColumn index: Int) -> String {
        guard let document, document.headers.indices.contains(index) else { return "" }
        return sidecar.displayName(for: document.headers[index])
    }

    /// The type to present for a column: the user's intended type from the
    /// sidecar when set, otherwise the value inferred from the data.
    func resolvedType(forColumn index: Int, sample: [String]) -> ColumnType {
        guard let document, document.headers.indices.contains(index) else {
            return ColumnType.infer(from: sample)
        }
        return sidecar.intendedType(for: document.headers[index]) ?? ColumnType.infer(from: sample)
    }

    /// The custom display name stored for a column, or "" when none is set.
    /// Distinct from `displayName(forColumn:)`, which falls back to the header —
    /// this returns empty so an editing field shows a placeholder, not the header.
    func customDisplayName(forColumn index: Int) -> String {
        guard let document, document.headers.indices.contains(index) else { return "" }
        return sidecar.column(for: document.headers[index])?.displayName ?? ""
    }

    /// The intended type explicitly set for a column, if any (nil means "Auto").
    func intendedType(forColumn index: Int) -> ColumnType? {
        guard let document, document.headers.indices.contains(index) else { return nil }
        return sidecar.intendedType(for: document.headers[index])
    }

    func setIntendedType(_ type: ColumnType?, forColumn index: Int) {
        guard let document, document.headers.indices.contains(index) else { return }
        sidecar.setType(type, for: document.headers[index])
        persistSidecar()
    }

    func setDisplayName(_ name: String?, forColumn index: Int) {
        guard let document, document.headers.indices.contains(index) else { return }
        sidecar.setDisplayName(name, for: document.headers[index])
        persistSidecar()
    }

    /// Writes the sidecar next to the `.csv` (or deletes it when empty). Best
    /// effort: a sidecar failure must never interrupt editing the table, so it
    /// is intentionally silent — the `.csv` is unaffected either way.
    private func persistSidecar() {
        guard let sourceURL else { return }
        sidecar.pruneColumns(keepingHeaders: document?.headers ?? [])
        try? SidecarService.save(sidecar, for: sourceURL)
    }

    /// Restores the sort remembered in the sidecar, if its column still exists.
    /// Applied to the in-memory model only — it does not rewrite the file, so
    /// merely opening a table never changes it on disk.
    private func applySidecarSort() {
        guard let sort = sidecar.sort, var document,
              let index = document.headers.firstIndex(of: sort.column) else { return }
        sortColumnIndex = index
        sortAscending = sort.ascending
        document.sortByColumn(index, ascending: sort.ascending)
        self.document = document
    }

    /// Runs the read-only data-quality inspection. Re-reads the source file (if
    /// any) so ragged rows — normalized away in the in-memory model — can be seen.
    func runInspection() -> [InspectionFinding] {
        guard let document else { return [] }
        var rawParsedRows: [[String]]?
        if let sourceURL, let text = try? FileService.readText(from: sourceURL) {
            rawParsedRows = CSVParser.parse(text, delimiter: CSVParser.detectDelimiter(text))
        }
        return InspectService.inspect(document, rawParsedRows: rawParsedRows)
    }

    func columnStats(for columnIndex: Int) -> ColumnStats? {
        guard let document, document.headers.indices.contains(columnIndex) else { return nil }
        let values = document.rows.map { $0[columnIndex] }
        return ColumnStats.compute(values: values)
    }

    // Paperclip — the companion .md next to the .csv, if one exists. Stored (not
    // computed) so it updates reactively and avoids a filesystem stat per redraw;
    // refreshed whenever sourceURL changes (see its didSet) and after we create one.
    var pairedMarkdownURL: URL?

    /// Creates an empty `<name>.md` next to the current `.csv` (same-name pairing)
    /// when none exists yet, and returns its URL. No-op without a saved source.
    @discardableResult
    func createCompanionNote() -> URL? {
        guard let sourceURL, pairedMarkdownURL == nil else { return nil }
        let mdURL = sourceURL.deletingPathExtension().appendingPathExtension("md")
        let seed = "# \(sourceURL.deletingPathExtension().lastPathComponent)\n\n"
        do {
            try FileService.writeText(seed, to: mdURL)
            pairedMarkdownURL = mdURL
            errorMessage = nil
            return mdURL
        } catch {
            errorMessage = "Could not create the companion note. \(error.localizedDescription)"
            return nil
        }
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
        sidecar = FlatFileSidecar()
        errorMessage = nil
    }

    func createFromTemplate(_ template: CSVTemplate, name: String) {
        let rows = template.exampleRows.map { CSVRow(values: $0) }
        document = CSVDocument(name: name, headers: template.headers, rows: rows, delimiter: ",")
        sourceURL = nil
        rawCSVText = document?.rawCSV ?? ""
        sortColumnIndex = nil
        sidecar = FlatFileSidecar()
        errorMessage = nil
    }

    func openDocument(at url: URL) {
        do {
            let loaded = try FileService.loadDocument(from: url)
            document = loaded
            sourceURL = url
            rawCSVText = loaded.rawCSV
            sortColumnIndex = nil
            sortAscending = true
            // Load the optional sidecar (absent/invalid -> clean defaults) and
            // apply its remembered sort. Display names / types are read lazily.
            sidecar = SidecarService.load(for: url) ?? FlatFileSidecar()
            applySidecarSort()
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

        let disk: String
        do {
            disk = try FileService.readText(from: sourceURL)
        } catch {
            errorMessage = "Could not re-read \"\(document.name).csv\". \(error.localizedDescription)"
            return
        }
        guard disk != document.rawCSV else { return }

        let delimiter = CSVParser.detectDelimiter(disk)
        let parsed = CSVParser.parse(disk, delimiter: delimiter)
        guard let headers = parsed.first, !headers.isEmpty else {
            errorMessage = "\"\(document.name).csv\" changed on disk but is no longer valid CSV, so it wasn't reloaded."
            return
        }
        _ = headers
        self.document = CSVDocument(name: document.name, parsedRows: parsed, delimiter: delimiter)
        rawCSVText = self.document?.rawCSV ?? ""
        // Pick up an externally-edited sidecar too, and re-apply its sort.
        sidecar = SidecarService.load(for: sourceURL) ?? FlatFileSidecar()
        applySidecarSort()
        // An external add/remove of the companion .md should show up too.
        pairedMarkdownURL = PaperclipHelper.pairedMarkdownURL(for: sourceURL)
    }

    // MARK: - Mutations

    func updateHeader(at index: Int, value: String) {
        guard var document else { return }
        let oldHeader = document.headers.indices.contains(index) ? document.headers[index] : nil
        document.updateHeader(at: index, value: value)
        self.document = document
        // Keep any sidecar prefs/sort attached to this column through the rename
        // (the sidecar is keyed by header text). Only write when something moved.
        if let oldHeader, sidecar.renameHeader(from: oldHeader, to: value) {
            persistSidecar()
        }
        // Only the macOS raw-CSV editor reads rawCSVText; skip the per-edit
        // whole-document serialize on iOS, where nothing consumes it.
        #if os(macOS)
        rawCSVText = document.rawCSV
        #endif
        scheduleAutosave()
    }

    func updateCell(rowID: UUID, columnIndex: Int, value: String) {
        guard var document else { return }
        document.updateCell(rowID: rowID, columnIndex: columnIndex, value: value)
        self.document = document
        // Only the macOS raw-CSV editor reads rawCSVText; skip the per-edit
        // whole-document serialize on iOS, where nothing consumes it.
        #if os(macOS)
        rawCSVText = document.rawCSV
        #endif
        scheduleAutosave()
    }

    func appendRow(_ values: [String]) {
        guard var document else { return }
        document.appendRow(values)
        self.document = document
        // Only the macOS raw-CSV editor reads rawCSVText; skip the per-edit
        // whole-document serialize on iOS, where nothing consumes it.
        #if os(macOS)
        rawCSVText = document.rawCSV
        #endif
        scheduleAutosave()
    }

    func deleteRow(id: UUID) {
        guard var document else { return }
        document.deleteRow(id: id)
        self.document = document
        // Only the macOS raw-CSV editor reads rawCSVText; skip the per-edit
        // whole-document serialize on iOS, where nothing consumes it.
        #if os(macOS)
        rawCSVText = document.rawCSV
        #endif
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
        // Only the macOS raw-CSV editor reads rawCSVText; skip the per-edit
        // whole-document serialize on iOS, where nothing consumes it.
        #if os(macOS)
        rawCSVText = document.rawCSV
        #endif
        // Remember the sort so it's restored next open.
        if document.headers.indices.contains(columnIndex) {
            sidecar.sort = .init(column: document.headers[columnIndex], ascending: sortAscending)
            persistSidecar()
        }
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
        // Only the macOS raw-CSV editor reads rawCSVText; skip the per-edit
        // whole-document serialize on iOS, where nothing consumes it.
        #if os(macOS)
        rawCSVText = document.rawCSV
        #endif
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
        // Only the macOS raw-CSV editor reads rawCSVText; skip the per-edit
        // whole-document serialize on iOS, where nothing consumes it.
        #if os(macOS)
        rawCSVText = document.rawCSV
        #endif
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
