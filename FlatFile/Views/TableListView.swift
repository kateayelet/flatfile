//
//  TableListView.swift
//  FlatFile
//
//  Workspace sidebar: actions, connected folders + their .csv files, current file.
//

import SwiftUI

struct TableListView: View {
    let library: LibraryViewModel
    let document: CSVDocument?
    let sourceURL: URL?
    let pairedMarkdownURL: URL?
    let onNewTable: () -> Void
    let onImport: () -> Void
    let onConnectFolder: () -> Void
    let onOpenFile: (URL) -> Void
    let onSave: () -> Void

    var body: some View {
        List {
            Section("Workspace") {
                Button("New Table", action: onNewTable)
                Button("Import CSV", action: onImport)
                Button("Connect Folder", action: onConnectFolder)
                Button("Save As…", action: onSave)
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

            if library.folders.isEmpty {
                Section("Folders") {
                    Text("Connect a folder to browse all its CSV files here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(library.folders) { folder in
                    folderSection(folder)
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
                        PairedNoteButton(url: pairedMarkdownURL) {
                            Label("Open \(pairedMarkdownURL.lastPathComponent)", systemImage: "paperclip")
                        }
                    }
                }
            }
        }
        .navigationTitle("FlatFile")
    }

    @ViewBuilder
    private func folderSection(_ folder: LibraryViewModel.Folder) -> some View {
        Section {
            if folder.entries.isEmpty {
                Text("No CSV files")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(folder.entries) { entry in
                    Button {
                        onOpenFile(entry.url)
                    } label: {
                        HStack {
                            Image(systemName: "tablecells")
                                .foregroundStyle(.secondary)
                            Text(entry.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if entry.hasPairedNote {
                                Image(systemName: "paperclip")
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Has paired note")
                            }
                            if entry.url == sourceURL {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .accessibilityLabel("Currently open")
                            }
                        }
                    }
                }
            }
        } header: {
            HStack {
                Label(folder.name, systemImage: "folder")
                Spacer()
                Button(role: .destructive) {
                    library.removeFolder(folder)
                } label: {
                    Image(systemName: "minus.circle")
                        .accessibilityLabel("Disconnect \(folder.name)")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
