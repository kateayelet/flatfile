//
//  FlatFileTests.swift
//  FlatFileTests
//
//  Created by Kate Ayelet Benediktsson on 4/6/26.
//

import Testing
import Foundation
@testable import FlatFile

// MARK: - CSVParser Tests

struct CSVParserTests {

    // MARK: parse()

    @Test func parseBasicCSV() {
        let rows = CSVParser.parse("name,age,city\nAlice,30,NYC\nBob,25,LA\n")
        #expect(rows.count == 3)
        #expect(rows[0] == ["name", "age", "city"])
        #expect(rows[1] == ["Alice", "30", "NYC"])
        #expect(rows[2] == ["Bob", "25", "LA"])
    }

    @Test func parseQuotedFieldsWithCommas() {
        let rows = CSVParser.parse("name,address\nAlice,\"123 Main St, Apt 4\"\n")
        #expect(rows.count == 2)
        #expect(rows[1][1] == "123 Main St, Apt 4")
    }

    @Test func parseEscapedDoubleQuotes() {
        let rows = CSVParser.parse("name,note\nAlice,\"She said \"\"hello\"\"\"\n")
        #expect(rows.count == 2)
        #expect(rows[1][1] == "She said \"hello\"")
    }

    @Test func parseNewlinesInsideQuotedFields() {
        let rows = CSVParser.parse("name,bio\nAlice,\"Line one\nLine two\"\n")
        #expect(rows.count == 2)
        #expect(rows[1][1] == "Line one\nLine two")
    }

    @Test func parseIgnoresTrailingBlankLines() {
        let rows = CSVParser.parse("a,b\n1,2\n\n\n")
        #expect(rows.count == 2)
    }

    @Test func parseCRLFLineEndings() {
        let rows = CSVParser.parse("a,b\r\n1,2\r\n")
        #expect(rows.count == 2)
        #expect(rows[1] == ["1", "2"])
    }

    @Test func parseEmptyString() {
        let rows = CSVParser.parse("")
        #expect(rows.isEmpty)
    }

    @Test func parseEmptyFields() {
        let rows = CSVParser.parse("a,,c\n,2,\n")
        #expect(rows[0] == ["a", "", "c"])
        #expect(rows[1] == ["", "2", ""])
    }

    @Test func parseMalformedUnterminatedQuote() {
        // Should not crash; graceful degradation
        let rows = CSVParser.parse("a,b\n\"unterminated,field")
        #expect(rows.count == 2)
    }

    @Test func parseNoTrailingNewline() {
        let rows = CSVParser.parse("a,b\n1,2")
        #expect(rows.count == 2)
        #expect(rows[1] == ["1", "2"])
    }

    @Test func parseSingleColumn() {
        let rows = CSVParser.parse("name\nAlice\nBob\n")
        #expect(rows.count == 3)
        #expect(rows[0] == ["name"])
        #expect(rows[2] == ["Bob"])
    }

    @Test func parseQuotedFieldWithCRLF() {
        let rows = CSVParser.parse("a,b\n\"line1\r\nline2\",val\n")
        #expect(rows.count == 2)
        #expect(rows[1][0] == "line1\r\nline2")
    }

    @Test func detectDelimiterPrefersTabWhenPresent() {
        let delimiter = CSVParser.detectDelimiter("name\tage\tcity\nAlice\t30\tNYC\n")
        #expect(delimiter == "\t")
    }

    @Test func parseTabSeparatedValues() {
        let rows = CSVParser.parse("name\tage\nAlice\t30\n", delimiter: "\t")
        #expect(rows == [["name", "age"], ["Alice", "30"]])
    }

    // MARK: serialize()

    @Test func serializeBasicCSV() {
        let csv = CSVParser.serialize([["name", "age"], ["Alice", "30"]])
        #expect(csv == "name,age\nAlice,30\n")
    }

    @Test func serializeQuotesFieldsWithCommas() {
        let csv = CSVParser.serialize([["name", "addr"], ["Al", "123 Main, Apt 4"]])
        #expect(csv.contains("\"123 Main, Apt 4\""))
    }

    @Test func serializeEscapesDoubleQuotes() {
        let csv = CSVParser.serialize([["note"], ["She said \"hi\""]])
        #expect(csv.contains("\"She said \"\"hi\"\"\""))
    }

    @Test func serializeQuotesFieldsWithNewlines() {
        let csv = CSVParser.serialize([["bio"], ["line1\nline2"]])
        #expect(csv.contains("\"line1\nline2\""))
    }

    // MARK: Round-trip

    @Test func roundTripPreservesData() {
        let original = [
            ["name", "score", "note"],
            ["Alice", "95", "Great, excellent"],
            ["Bob", "80", "Said \"hi\""]
        ]
        let csv = CSVParser.serialize(original)
        let reparsed = CSVParser.parse(csv)
        #expect(reparsed == original)
    }

    @Test func roundTripWithMultilineFields() {
        let original = [
            ["title", "body"],
            ["Entry 1", "First line\nSecond line\nThird line"]
        ]
        let csv = CSVParser.serialize(original)
        let reparsed = CSVParser.parse(csv)
        #expect(reparsed == original)
    }
}

// MARK: - CSVDocument Tests

struct CSVDocumentTests {
    @Test func appendRowPadsMissingColumns() {
        var document = CSVDocument(
            name: "People",
            headers: ["name", "age", "city"]
        )

        document.appendRow(["Alice", "30"])

        #expect(document.rows.count == 1)
        #expect(document.rows[0].values == ["Alice", "30", ""])
    }

    @Test func parsedInitializerTreatsFirstRowAsHeaders() {
        let document = CSVDocument(
            name: "People",
            parsedRows: [
                ["name", "age"],
                ["Alice", "30"]
            ]
        )

        #expect(document.headers == ["name", "age"])
        #expect(document.rows.count == 1)
        #expect(document.rows[0].values == ["Alice", "30"])
    }

    @Test func rawCSVUsesDocumentDelimiter() {
        let document = CSVDocument(
            name: "People",
            headers: ["name", "age"],
            rows: [CSVRow(values: ["Alice", "30"])],
            delimiter: "\t"
        )

        #expect(document.rawCSV == "name\tage\nAlice\t30\n")
    }
}

// MARK: - ColumnType and Stats Tests

struct ColumnAnalysisTests {
    @Test func infersNumberColumn() {
        let type = ColumnType.infer(from: ["1", "2.5", "3"])
        #expect(type == .number)
    }

    @Test func infersBooleanColumn() {
        let type = ColumnType.infer(from: ["yes", "no", "true", "false"])
        #expect(type == .boolean)
    }

    @Test func infersDateColumn() {
        let type = ColumnType.infer(from: ["2026-01-15", "2026/01/16"])
        #expect(type == .date)
    }

    @Test func infersURLColumn() {
        let type = ColumnType.infer(from: ["https://example.com", "http://openai.com"])
        #expect(type == .url)
    }

    @Test func computesNumericColumnStats() {
        let stats = ColumnStats.compute(values: ["10", "", "20", "10"])

        #expect(stats.type == .number)
        #expect(stats.total == 4)
        #expect(stats.filled == 3)
        #expect(stats.empty == 1)
        #expect(stats.unique == 2)
        #expect(stats.topValue == "10")
        #expect(stats.topCount == 2)
        #expect(stats.min == 10)
        #expect(stats.max == 20)
        #expect(stats.sum == 40)
        #expect(stats.avg == (40.0 / 3.0))
    }
}

// MARK: - Template Tests

struct CSVTemplateTests {
    @Test func builtInTemplatesContainExpectedDefaults() {
        #expect(CSVTemplate.builtIn.count == 6)
        #expect(CSVTemplate.builtIn.map(\.name) == [
            "Blank",
            "Contact List",
            "Budget Tracker",
            "Research Log",
            "Task List",
            "Inventory"
        ])
    }
}

// MARK: - FlatFileSidecar Model Tests (AFTR-352)

struct FlatFileSidecarModelTests {
    @Test func setTypeCreatesAndResolvesEntry() {
        var sidecar = FlatFileSidecar()
        sidecar.setType(.number, for: "amount")
        #expect(sidecar.intendedType(for: "amount") == .number)
        #expect(sidecar.columns.count == 1)
    }

    @Test func clearingTypePrunesNowEmptyEntry() {
        var sidecar = FlatFileSidecar()
        sidecar.setType(.number, for: "amount")
        sidecar.setType(nil, for: "amount")
        #expect(sidecar.intendedType(for: "amount") == nil)
        #expect(sidecar.columns.isEmpty)
    }

    @Test func displayNameFallsBackToHeaderWhenUnset() {
        var sidecar = FlatFileSidecar()
        #expect(sidecar.displayName(for: "col_1") == "col_1")
        sidecar.setDisplayName("Amount (USD)", for: "col_1")
        #expect(sidecar.displayName(for: "col_1") == "Amount (USD)")
    }

    @Test func blankDisplayNameIsTreatedAsUnset() {
        var sidecar = FlatFileSidecar()
        sidecar.setDisplayName("   ", for: "col_1")
        #expect(sidecar.displayName(for: "col_1") == "col_1")
        #expect(sidecar.columns.isEmpty)
    }

    @Test func displayNameAndTypeCoexistOnOneColumn() {
        var sidecar = FlatFileSidecar()
        sidecar.setDisplayName("Price", for: "p")
        sidecar.setType(.number, for: "p")
        #expect(sidecar.columns.count == 1)
        // Clearing only the type keeps the entry alive for the display name.
        sidecar.setType(nil, for: "p")
        #expect(sidecar.columns.count == 1)
        #expect(sidecar.displayName(for: "p") == "Price")
    }

    @Test func invalidStoredTypeResolvesToNil() {
        let sidecar = FlatFileSidecar(columns: [.init(header: "x", type: "rainbow")])
        #expect(sidecar.intendedType(for: "x") == nil)
    }

    @Test func isEmptyReflectsContent() {
        var sidecar = FlatFileSidecar()
        #expect(sidecar.isEmpty)
        sidecar.sort = .init(column: "a", ascending: true)
        #expect(!sidecar.isEmpty)
    }

    @Test func renameHeaderMigratesPrefsAndSort() {
        var sidecar = FlatFileSidecar()
        sidecar.setDisplayName("Price", for: "amount")
        sidecar.setType(.number, for: "amount")
        sidecar.sort = .init(column: "amount", ascending: true)

        let moved = sidecar.renameHeader(from: "amount", to: "cost")
        #expect(moved)
        #expect(sidecar.displayName(for: "cost") == "Price")
        #expect(sidecar.intendedType(for: "cost") == .number)
        #expect(sidecar.sort?.column == "cost")
        #expect(sidecar.column(for: "amount") == nil)
        // A no-op rename reports no change.
        #expect(sidecar.renameHeader(from: "cost", to: "cost") == false)
    }

    @Test func renamePreservesPrefsAcrossPrune() {
        // The real-world bug: rename then prune against the new header set.
        var sidecar = FlatFileSidecar()
        sidecar.setType(.date, for: "old")
        sidecar.renameHeader(from: "old", to: "new")
        sidecar.pruneColumns(keepingHeaders: ["new"])
        #expect(sidecar.intendedType(for: "new") == .date)
    }

    @Test func pruneDropsStaleColumnsAndSort() {
        var sidecar = FlatFileSidecar()
        sidecar.setType(.number, for: "kept")
        sidecar.setType(.text, for: "removed")
        sidecar.sort = .init(column: "removed", ascending: true)
        sidecar.pruneColumns(keepingHeaders: ["kept"])
        #expect(sidecar.intendedType(for: "kept") == .number)
        #expect(sidecar.column(for: "removed") == nil)
        #expect(sidecar.sort == nil)
    }

    @Test func codableRoundTripPreservesEverything() throws {
        var original = FlatFileSidecar()
        original.setDisplayName("Amount", for: "amt")
        original.setType(.number, for: "amt")
        original.setFormat("USD", for: "amt")
        original.sort = .init(column: "amt", ascending: false)

        let data = try JSONEncoder().encode(original)
        let restored = try JSONDecoder().decode(FlatFileSidecar.self, from: data)
        #expect(restored == original)
    }

    @Test func decodeIgnoresUnknownFields() throws {
        // Forward-compat: a future field shouldn't break today's decoder.
        let json = """
        {"version":1,"columns":[{"header":"a","type":"number","futureField":42}],"sort":{"column":"a","ascending":true}}
        """
        let data = Data(json.utf8)
        let sidecar = try JSONDecoder().decode(FlatFileSidecar.self, from: data)
        #expect(sidecar.intendedType(for: "a") == .number)
        #expect(sidecar.sort?.ascending == true)
    }
}

// MARK: - SidecarService Codec Tests (AFTR-352)

struct SidecarServiceTests {
    /// A throwaway `.csv` URL in a unique temp dir; the sidecar lands beside it.
    private func tempCSVURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("flatfile-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("table.csv")
    }

    @Test func sidecarURLSwapsExtension() {
        let csv = URL(fileURLWithPath: "/tmp/data.csv")
        #expect(SidecarService.sidecarURL(for: csv).lastPathComponent == "data.flatfile")
    }

    @Test func saveThenLoadRoundTrips() throws {
        let csv = tempCSVURL()
        defer { try? FileManager.default.removeItem(at: csv.deletingLastPathComponent()) }

        var sidecar = FlatFileSidecar()
        sidecar.setDisplayName("Price", for: "p")
        sidecar.setType(.number, for: "p")
        sidecar.sort = .init(column: "p", ascending: false)
        try SidecarService.save(sidecar, for: csv)

        let loaded = SidecarService.load(for: csv)
        #expect(loaded == sidecar)
    }

    @Test func loadMissingReturnsNil() {
        let csv = tempCSVURL()
        defer { try? FileManager.default.removeItem(at: csv.deletingLastPathComponent()) }
        #expect(SidecarService.load(for: csv) == nil)
    }

    @Test func savingEmptySidecarWritesNoFile() throws {
        let csv = tempCSVURL()
        defer { try? FileManager.default.removeItem(at: csv.deletingLastPathComponent()) }
        try SidecarService.save(FlatFileSidecar(), for: csv)
        let url = SidecarService.sidecarURL(for: csv)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func savingEmptySidecarDeletesAnExistingOne() throws {
        let csv = tempCSVURL()
        defer { try? FileManager.default.removeItem(at: csv.deletingLastPathComponent()) }

        var sidecar = FlatFileSidecar()
        sidecar.setType(.date, for: "when")
        try SidecarService.save(sidecar, for: csv)
        #expect(FileManager.default.fileExists(atPath: SidecarService.sidecarURL(for: csv).path))

        // Clearing the only preference makes it empty -> the file is removed.
        sidecar.setType(nil, for: "when")
        try SidecarService.save(sidecar, for: csv)
        #expect(!FileManager.default.fileExists(atPath: SidecarService.sidecarURL(for: csv).path))
        #expect(SidecarService.load(for: csv) == nil)
    }

    @Test func loadGarbageReturnsNil() throws {
        let csv = tempCSVURL()
        defer { try? FileManager.default.removeItem(at: csv.deletingLastPathComponent()) }
        try "not json at all {{{".write(to: SidecarService.sidecarURL(for: csv), atomically: true, encoding: .utf8)
        #expect(SidecarService.load(for: csv) == nil)
    }
}

// MARK: - TableViewModel Sidecar Integration (AFTR-352 invariants)

@MainActor
struct TableViewModelSidecarTests {
    private func makeCSV(_ contents: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ff-vm-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("table.csv")
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @Test func openingFileWithoutSidecarClearsPriorPrefs() {
        let vm = TableViewModel()
        let a = makeCSV("name,amount\nAl,5\n")
        defer { try? FileManager.default.removeItem(at: a.deletingLastPathComponent()) }
        vm.openDocument(at: a)
        vm.setIntendedType(.number, forColumn: 1)
        #expect(vm.intendedType(forColumn: 1) == .number)

        let b = makeCSV("name,amount\nBo,9\n")
        defer { try? FileManager.default.removeItem(at: b.deletingLastPathComponent()) }
        vm.openDocument(at: b)
        // B has no sidecar — A's preference must not bleed through.
        #expect(vm.intendedType(forColumn: 1) == nil)
    }

    @Test func openingDoesNotRewriteTheCSV() throws {
        let original = "name,amount\nBo,9\nAl,5\n"
        let url = makeCSV(original)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        // A sidecar that remembers a sort — opening should apply it in memory only.
        var sidecar = FlatFileSidecar()
        sidecar.sort = .init(column: "amount", ascending: true)
        try SidecarService.save(sidecar, for: url)

        let vm = TableViewModel()
        vm.openDocument(at: url)
        #expect(vm.sortColumnIndex == 1)              // sort was restored
        #expect(vm.document?.rows.first?.values == ["Al", "5"]) // reordered in memory

        let onDisk = try String(contentsOf: url, encoding: .utf8)
        #expect(onDisk == original)                   // ...but the file is untouched
    }
}

// MARK: - InspectService Tests (AFTR-359 coverage for the data-quality engine)

struct InspectServiceTests {
    private func document(headers: [String], rows: [[String]]) -> CSVDocument {
        CSVDocument(name: "t", headers: headers, rows: rows.map { CSVRow(values: $0) })
    }

    private func kinds(_ findings: [InspectionFinding]) -> Set<InspectionFinding.Kind> {
        Set(findings.map(\.kind))
    }

    @Test func cleanDocumentHasNoFindings() {
        let doc = document(headers: ["a", "b"], rows: [["1", "x"], ["2", "y"]])
        let findings = InspectService.inspect(doc, rawParsedRows: [["a", "b"], ["1", "x"], ["2", "y"]])
        #expect(findings.isEmpty)
    }

    @Test func detectsRaggedRowsFromRawParse() {
        // The in-memory model normalizes width, so ragged detection needs the raw parse.
        let doc = document(headers: ["a", "b", "c"], rows: [["1", "2", "3"]])
        let raw = [["a", "b", "c"], ["1", "2"], ["1", "2", "3", "4"]]
        let findings = InspectService.inspect(doc, rawParsedRows: raw)
        #expect(kinds(findings).contains(.raggedRows))
    }

    @Test func detectsDuplicateRows() {
        let doc = document(headers: ["a"], rows: [["dup"], ["dup"], ["unique"]])
        let findings = InspectService.inspect(doc, rawParsedRows: nil)
        #expect(kinds(findings).contains(.duplicateRows))
    }

    @Test func detectsBlankCellsInOtherwiseFullColumn() {
        let doc = document(headers: ["name", "city"], rows: [["Al", "NYC"], ["Bo", ""]])
        let findings = InspectService.inspect(doc, rawParsedRows: nil)
        #expect(kinds(findings).contains(.emptyInFullColumn))
    }

    @Test func detectsSpreadsheetUnsafeNumbers() {
        // Leading-zero ZIP and a 16-digit card-like run other apps would mangle.
        let doc = document(headers: ["zip", "card"], rows: [["02134", "4111111111111111"]])
        let findings = InspectService.inspect(doc, rawParsedRows: nil)
        #expect(kinds(findings).contains(.spreadsheetUnsafe))
    }

    @Test func detectsMixedDateFormats() {
        let doc = document(headers: ["when"], rows: [["2026-01-15"], ["01/16/2026"]])
        let findings = InspectService.inspect(doc, rawParsedRows: nil)
        #expect(kinds(findings).contains(.mixedDateFormats))
    }

    @Test func detectsUntrimmedWhitespace() {
        let doc = document(headers: ["a"], rows: [[" leading"], ["trailing "]])
        let findings = InspectService.inspect(doc, rawParsedRows: nil)
        #expect(kinds(findings).contains(.untrimmedWhitespace))
    }

    @Test func consistentDatesDoNotTriggerMixedFormats() {
        let doc = document(headers: ["when"], rows: [["2026-01-15"], ["2026-02-20"]])
        let findings = InspectService.inspect(doc, rawParsedRows: nil)
        #expect(!kinds(findings).contains(.mixedDateFormats))
    }
}
