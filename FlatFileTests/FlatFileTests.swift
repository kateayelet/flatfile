//
//  FlatFileTests.swift
//  FlatFileTests
//
//  Created by Kate Ayelet Benediktsson on 4/6/26.
//

import Testing
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
