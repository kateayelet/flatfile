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
    @State private var library = LibraryViewModel()
    @State private var isImporting = false
    @State private var isConnectingFolder = false
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
            library.loadConnectedFolders()
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
        .fileImporter(
            isPresented: $isConnectingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    library.connectFolder(at: url)
                }
            case .failure(let error):
                library.errorMessage = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: CSVFileDocument(text: viewModel.shareText),
            contentType: .commaSeparatedText,
            defaultFilename: viewModel.shareFileName
        ) { result in
            switch result {
            case .success(let url):
                viewModel.sourceURL = url
                // A "Save As" into a connected folder should show up in its list.
                library.refresh()
            case .failure(let error):
                viewModel.errorMessage = "Could not save the file. \(error.localizedDescription)"
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Pick up external edits made while we were away.
                viewModel.reloadIfChanged()
                library.refresh()
            } else {
                // Flush any pending debounced save before leaving the foreground.
                viewModel.flush()
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            showingError = newValue != nil
        }
        .onChange(of: library.errorMessage) { _, newValue in
            // Surface folder/bookmark errors through the same alert, then clear
            // so the same error can re-trigger later.
            if let newValue {
                viewModel.errorMessage = newValue
                library.errorMessage = nil
            }
        }
        .alert("FlatFile Error", isPresented: $showingError, presenting: viewModel.errorMessage) { _ in
            Button("OK") {
                viewModel.dismissError()
            }
        } message: { message in
            Text(message)
        }
    }

    /// The open .csv lives in a connected folder, so we hold a scope that covers
    /// reading/writing its companion .md (gates the companion-note features).
    private var sourceInConnectedFolder: Bool {
        guard let url = viewModel.sourceURL else { return false }
        return library.contains(url)
    }

    private var splitLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            workspaceView
        } detail: {
            TableView(viewModel: viewModel, sourceInConnectedFolder: sourceInConnectedFolder)
        }
    }

    private var compactLayout: some View {
        NavigationStack {
            TableView(viewModel: viewModel, sourceInConnectedFolder: sourceInConnectedFolder)
                .toolbar {
                    // `compactLayout` only runs on iOS at runtime (Mac uses the
                    // split layout), but it must still compile for macOS, where
                    // `.topBarLeading` is unavailable.
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingWorkspace = true
                        } label: {
                            Label("Workspace", systemImage: "sidebar.left")
                        }
                    }
                    #endif
                }
        }
    }

    private var workspaceView: some View {
        TableListView(
            library: library,
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
            onConnectFolder: {
                showingWorkspace = false
                isConnectingFolder = true
            },
            onOpenFile: { url in
                showingWorkspace = false
                viewModel.openDocument(at: url)
                columnVisibility = .detailOnly
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

// MARK: - Cross-platform modifiers
// A handful of SwiftUI modifiers are iOS-only. These wrappers apply them on iOS
// and become no-ops on macOS so the universal target compiles for both.
extension View {
    /// Inline navigation bar title on iOS; no-op on macOS where it is unavailable.
    @ViewBuilder
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Medium/large sheet detents on iOS; no-op on macOS where detents are unavailable.
    @ViewBuilder
    func mediumLargeSheetDetents() -> some View {
        #if os(iOS)
        presentationDetents([.medium, .large])
        #else
        self
        #endif
    }
}
