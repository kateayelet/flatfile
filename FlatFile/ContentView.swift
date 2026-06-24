//
//  ContentView.swift
//  FlatFile
//
//  Created by Kate Ayelet Benediktsson on 4/6/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = TableViewModel()
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var showingError = false
    @State private var showingWorkspace = false
    @State private var showingNewTableSheet = false
    @State private var showingTemplatePicker = false
    @State private var newTableName = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                splitLayout
            }
        }
        .onAppear {
            if viewModel.document == nil {
                viewModel.createNewDocument(name: "Untitled")
            }
        }
        .sheet(isPresented: $showingWorkspace) {
            NavigationStack {
                workspaceView
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showingWorkspace = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingNewTableSheet) {
            NewTableSheetView(
                tableName: $newTableName,
                onCreateBlank: { name, columnCount, rowCount in
                    viewModel.createNewDocument(name: name, columnCount: columnCount, rowCount: rowCount)
                    newTableName = ""
                    columnVisibility = .detailOnly
                },
                onChooseTemplate: { draftName in
                    newTableName = draftName
                    showingTemplatePicker = true
                }
            )
        }
        .sheet(isPresented: $showingTemplatePicker) {
            TemplatePickerView { template in
                let name = newTableName.trimmingCharacters(in: .whitespaces)
                viewModel.createFromTemplate(template, name: name.isEmpty ? template.name : name)
                newTableName = ""
                columnVisibility = .detailOnly
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.openDocument(at: url)
                    columnVisibility = .detailOnly
                }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: CSVFileDocument(text: viewModel.shareText),
            contentType: .commaSeparatedText,
            defaultFilename: viewModel.shareFileName
        ) { result in
            if case .success(let url) = result {
                viewModel.sourceURL = url
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Pick up external edits made while we were away.
                viewModel.reloadIfChanged()
            } else {
                // Flush any pending debounced save before leaving the foreground.
                viewModel.flush()
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
        .alert("FlatFile Error", isPresented: $showingError, presenting: viewModel.errorMessage) { _ in
            Button("OK") {
                viewModel.dismissError()
            }
        } message: { message in
            Text(message)
        }
    }

    private var splitLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            workspaceView
        } detail: {
            TableView(viewModel: viewModel)
        }
    }

    private var compactLayout: some View {
        NavigationStack {
            TableView(viewModel: viewModel)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingWorkspace = true
                        } label: {
                            Label("Workspace", systemImage: "sidebar.left")
                        }
                    }
                }
        }
    }

    private var workspaceView: some View {
        TableListView(
            document: viewModel.document,
            sourceURL: viewModel.sourceURL,
            pairedMarkdownURL: viewModel.pairedMarkdownURL,
            onNewTable: {
                showingWorkspace = false
                showingNewTableSheet = true
            },
            onImport: {
                showingWorkspace = false
                isImporting = true
            },
            onSave: {
                // Edits persist automatically once the file has a location;
                // this control is now "Save As" (first save, or save a copy).
                isExporting = true
            }
        )
    }
}

struct CSVFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
