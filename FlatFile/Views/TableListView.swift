//
//  TableListView.swift
//  FlatFile
//
//  List of .csv files in connected folder
//

import SwiftUI

struct TableListView: View {
    let document: CSVDocument?
    let sourceURL: URL?
    let pairedMarkdownURL: URL?
    let onNewTable: () -> Void
    let onImport: () -> Void
    let onSave: () -> Void

    var body: some View {
        List {
            Section("Workspace") {
                Button("New Table", action: onNewTable)
                Button("Import CSV", action: onImport)
                Button("Save Changes", action: onSave)
                    .disabled(document == nil)
                if let document {
                    ShareLink(
                        item: document.rawCSV,
                        subject: Text(document.name),
                        message: Text("")
                    ) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                }
            }

            if let document {
                Section("Current File") {
                    LabeledContent("Name", value: document.name)
                    LabeledContent("Columns", value: "\(document.columnCount)")
                    LabeledContent("Rows", value: "\(document.rowCount)")
                    if let sourceURL {
                        LabeledContent("Path", value: sourceURL.lastPathComponent)
                    }
                    if let pairedMarkdownURL {
                        LabeledContent("Paired Note", value: pairedMarkdownURL.lastPathComponent)
                    }
                }
            }
        }
        .navigationTitle("FlatFile")
    }
}
