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
    private var openBroker = OpenFileBroker.shared
    @State private var isImporting = false
    @State private var isConnectingFolder = false
    @State private var isExporting = false
    @State private var showingError = false
    @State private var showingWorkspace = false
    @State private var showingNewTableSheet = false
    @State private var showingTemplatePicker = false
    @State private var newTableName = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    /// iPhone only: whether the table is pushed on top of the tiles home.
    @State private var isTableOpen = false
    /// Remembers whether the Mac/iPad raw-CSV footer was last left open.
    @AppStorage("flatfileShowRawCSV") private var persistShowRawCSV = false
    // NOTE: columnVisibility only affects the iPad/Mac split layout — iPhone uses
    // a NavigationStack. The sidebar (the sheets list) stays visible so Mac/iPad
    // always show your sheets alongside the open table, like the iPhone home.

    #if DEBUG
    /// Screenshot mode for App Store capture, driven by the FF_SCREENSHOT env var
    /// (passed via SIMCTL_CHILD_FF_SCREENSHOT) or a launch argument. nil in normal use.
    private var screenshotMode: String? {
        if let env = ProcessInfo.processInfo.environment["FF_SCREENSHOT"], !env.isEmpty {
            return env
        }
        if CommandLine.arguments.contains("--screenshot-inspect") { return "inspect" }
        if CommandLine.arguments.contains("--screenshot-demo") { return "demo" }
        return nil
    }
    #endif

    var body: some View {
        Group {
            #if DEBUG
            // In screenshot mode: iOS captures the table directly (compact), while
            // macOS uses the real sidebar+table split so the window looks authentic
            // and fills its width rather than leaving the table alone on the left.
            if screenshotMode != nil {
                #if os(macOS)
                splitLayout
                #else
                compactLayout
                #endif
            } else if horizontalSizeClass == .compact {
                compactLayout
            } else {
                splitLayout
            }
            #else
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                splitLayout
            }
            #endif
        }
        .commands {
            CommandGroup(after: .pasteboard) {
                Button("Paste CSV…") {
                    revealRawCSV()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }
        }
        .onAppear {
            // Restore the inline footer on Mac/iPad. Do not reopen the iPhone
            // sheet on launch — that path is an explicit action.
            if horizontalSizeClass != .compact {
                viewModel.showingRawCSV = persistShowRawCSV
            }
            library.loadConnectedFolders()
            if viewModel.document == nil {
                #if DEBUG
                switch screenshotMode {
                case "demo":
                    viewModel.loadDemoDocument()
                    columnVisibility = .all
                    isTableOpen = true
                case "inspect":
                    viewModel.loadDemoDocument(withIssues: true)
                    columnVisibility = .all
                    viewModel.showingInspect = true
                    isTableOpen = true
                default:
                    // iPhone opens to the tiles home; iPad/Mac keep a table in
                    // the detail pane so the split view is never blank.
                    if horizontalSizeClass != .compact {
                        viewModel.createNewDocument(name: "Untitled")
                    }
                }
                #else
                if horizontalSizeClass != .compact {
                    viewModel.createNewDocument(name: "Untitled")
                }
                #endif
            }
            // A file the OS asked us to open may have arrived before this view
            // existed (cold launch from Finder/Spotlight) — open it now.
            if let url = openBroker.consume() {
                openExternal(url)
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
                    createBlankSheet(name: name, columnCount: columnCount, rowCount: rowCount)
                    newTableName = ""
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
                createTemplateSheet(template, name: name.isEmpty ? template.name : name)
                newTableName = ""
            }
        }
        // Each file panel gets its own anchor view: multiple fileImporter/
        // fileExporter modifiers on one view silently drop all but one panel
        // on macOS.
        .background {
            Color.clear.fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        openExternal(url)
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
        .background {
            Color.clear.fileImporter(
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
        }
        // Files the OS hands us: Finder "Open With"/Spotlight arrive via the
        // app delegate broker (macOS); a Files-app tap arrives via onOpenURL (iOS).
        .onOpenURL { url in
            openExternal(url)
        }
        .onChange(of: openBroker.pendingURL) { _, pending in
            guard pending != nil, let url = openBroker.consume() else { return }
            openExternal(url)
        }
        .background {
            Color.clear.fileExporter(
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
        .onChange(of: viewModel.showingRawCSV) { _, isShowing in
            if horizontalSizeClass != .compact {
                persistShowRawCSV = isShowing
            }
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

    /// Open a file that came from outside the table view — the in-app importer,
    /// Finder/Spotlight (macOS), or a Files-app tap (iOS). Any pending edit in
    /// the current table is flushed first so switching files never loses one.
    private func openExternal(_ url: URL) {
        guard url.isFileURL else { return }
        viewModel.flush()
        viewModel.openDocument(at: url)
        library.recordRecent(at: url)
        columnVisibility = .all
        showingWorkspace = false
        isTableOpen = true // iPhone: push the table over the tiles home
    }

    /// Create a blank sheet and open it. New sheets are real files in FlatFile's
    /// own folder (so they appear in the sheets list and auto-save) on every
    /// platform. Falls back to an in-memory doc only if the file can't be written.
    private func createBlankSheet(name: String, columnCount: Int, rowCount: Int) {
        let c = max(1, columnCount)
        let headers = (1...c).map { "column_\($0)" }
        var matrix = [headers]
        matrix += Array(repeating: Array(repeating: "", count: c), count: max(0, rowCount))
        if let url = library.createSheetFile(name: name, rows: matrix) {
            openExternal(url)
        } else {
            viewModel.createNewDocument(name: name.isEmpty ? "Untitled" : name,
                                        columnCount: columnCount, rowCount: rowCount)
            columnVisibility = .all
        }
    }

    private func createTemplateSheet(_ template: CSVTemplate, name: String) {
        if let url = library.createSheetFile(name: name, rows: [template.headers] + template.exampleRows) {
            openExternal(url)
        } else {
            viewModel.createFromTemplate(template, name: name)
            columnVisibility = .all
        }
    }

    /// Opens the raw-CSV editor as a first-class path (same free tier as Import).
    /// Creates an Untitled sheet if nothing is open yet so paste has a target.
    private func revealRawCSV() {
        if viewModel.document == nil {
            viewModel.createNewDocument(name: "Untitled")
        }
        viewModel.revealRawCSVEditor()
        columnVisibility = .all
        showingWorkspace = false
        isTableOpen = true
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
                // Wide enough that "Connect a folder to browse CSVs." and the
                // Workspace labels fit on one line at default Dynamic Type.
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 440)
        } detail: {
            TableView(viewModel: viewModel, sourceInConnectedFolder: sourceInConnectedFolder)
        }
    }

    private var compactLayout: some View {
        NavigationStack {
            SheetLibraryView(
                library: library,
                currentURL: viewModel.sourceURL,
                onOpen: { url in openExternal(url) },
                onNewSheet: { showingNewTableSheet = true },
                onImport: { isImporting = true },
                onConnectFolder: { isConnectingFolder = true },
                onPasteCSV: { revealRawCSV() }
            )
            .navigationDestination(isPresented: $isTableOpen) {
                TableView(viewModel: viewModel, sourceInConnectedFolder: sourceInConnectedFolder)
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
                library.recordRecent(at: url)
                columnVisibility = .all
            },
            onSave: {
                // Edits persist automatically once the file has a location;
                // this control is now "Save As" (first save, or save a copy).
                isExporting = true
            },
            onPasteCSV: { revealRawCSV() }
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
