//
//  TableView.swift
//  FlatFile
//
//  Main rendered table view
//

import SwiftUI
import Observation

struct TableView: View {
    @Bindable var viewModel: TableViewModel
    /// Whether the open .csv is inside a connected folder — i.e. we hold a
    /// security scope that lets us read/write a companion .md and its siblings.
    /// Companion controls are hidden otherwise (the writes would fail).
    var sourceInConnectedFolder = false
    @Environment(StoreManager.self) private var store
    @State private var rowToDelete: CSVRow?
    @State private var showingPaywall = false
    @State private var paywallTeaser: String?
    /// True while the paywall on screen was opened from Inspect, so a purchase
    /// keeps its promise: the results sheet opens as soon as the paywall closes.
    @State private var pendingInspectAfterUnlock = false

    /// Fixed cell metrics keep the pinned header aligned with virtualized rows
    /// and give the tight, gridline look of a real spreadsheet.
    private let cellWidth: CGFloat = 150
    private let cellHeight: CGFloat = 30
    private let headerHeight: CGFloat = 44
    private let gutterWidth: CGFloat = 46
    private static let largeFileThreshold = 2000

    // Adaptive spreadsheet palette: pure-white cells, a faint gray gutter/header,
    // and hairline separators — clean and neutral, not cream.
    private var cellFill: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
    private var gutterFill: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
    // Adaptive and actually visible on white — the semantic separators wash out.
    private var gridLine: Color { Color.primary.opacity(0.16) }

    /// Excel-style column label: 0 -> A, 25 -> Z, 26 -> AA.
    private func columnLetter(_ index: Int) -> String {
        var n = index, s = ""
        repeat { s = String(UnicodeScalar(65 + n % 26)!) + s; n = n / 26 - 1 } while n >= 0
        return s
    }
    @State private var showingNotePane = false
    @Environment(\.openURL) private var openURL
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    /// Wide layouts (iPad regular width, Mac) get the table + note side by side;
    /// iPhone (compact) keeps the cross-launch handoff.
    private var isWide: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    /// Mac and iPad keep the raw editor under the grid. iPhone uses a sheet
    /// so the editor is not a tiny disclosure under a compact table.
    private var usesInlineRawCSV: Bool { isWide }

    /// iPhone-only binding: the sheet is up when the editor was asked to open
    /// on a compact layout. Closing the sheet clears `showingRawCSV`.
    private var iphoneRawCSVPresented: Binding<Bool> {
        Binding(
            get: { !usesInlineRawCSV && viewModel.showingRawCSV },
            set: { if !$0 { viewModel.showingRawCSV = false } }
        )
    }

    var body: some View {
        if let document = viewModel.document {
            tableChrome(for: document)
        } else {
            ContentUnavailableView(
                "No CSV Selected",
                systemImage: "tablecells",
                description: Text("Import a CSV file to start editing.")
            )
        }
    }

    /// Document canvas plus chrome, staged so the toolbar/sheet chain does not
    /// overwhelm the macOS type checker (the same timeout as ContentView.body).
    private func tableChrome(for document: CSVDocument) -> some View {
        withTableSheets(
            withTableDialog(
                withTableToolbar(tableCanvas(for: document), document: document)
            )
        )
    }

    private func tableCanvas(for document: CSVDocument) -> some View {
        content(for: document)
            .navigationTitle(document.name)
            // Reset the note pane per document: tears it down (flushing its edits
            // via onDisappear) and clears the toggle so it never leaks across files.
            .onChange(of: viewModel.sourceURL) { _, _ in showingNotePane = false }
            .searchable(text: $viewModel.searchQuery, prompt: "Filter rows...")
    }

    private func withTableToolbar<V: View>(_ content: V, document: CSVDocument) -> some View {
        content.toolbar {
            ToolbarItem(placement: .primaryAction) {
                tableToolbarItems(for: document)
            }
        }
    }

    private func tableToolbarItems(for document: CSVDocument) -> some View {
        HStack(spacing: 12) {
            undoButton
            redoButton
            companionControls()
            compactRawCSVButton
            findReplaceButton
            inspectButton
            shareControl(for: document)
        }
        .fontWeight(.light)
        .symbolRenderingMode(.hierarchical)
    }

    private var undoButton: some View {
        Button {
            viewModel.undo()
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
        }
        .disabled(!viewModel.canUndo)
        .keyboardShortcut("z", modifiers: .command)
    }

    private var redoButton: some View {
        Button {
            viewModel.redo()
        } label: {
            Label("Redo", systemImage: "arrow.uturn.forward")
        }
        .disabled(!viewModel.canRedo)
        .keyboardShortcut("z", modifiers: [.command, .shift])
    }

    @ViewBuilder
    private var compactRawCSVButton: some View {
        #if os(iOS)
        if !isWide {
            Button {
                viewModel.revealRawCSVEditor()
            } label: {
                Label("Raw CSV", systemImage: "doc.plaintext")
            }
            .help("Paste or type comma-separated values")
        }
        #else
        EmptyView()
        #endif
    }

    private var findReplaceButton: some View {
        Button {
            gatePro { viewModel.showingFindReplace.toggle() }
        } label: {
            proLabel("Find & Replace", systemImage: "magnifyingglass")
        }
    }

    private var inspectButton: some View {
        Button {
            openInspectOrPaywall()
        } label: {
            proLabel("Inspect", systemImage: "checkmark.seal")
        }
    }

    /// Share the .csv as a real file, so emailing it (Mail, Gmail, etc.)
    /// attaches "name.csv" instead of pasting the raw text into the body.
    @ViewBuilder
    private func shareControl(for document: CSVDocument) -> some View {
        if let shareURL = viewModel.shareURL {
            ShareLink(
                item: shareURL,
                subject: Text(document.name),
                message: Text("")
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func openInspectOrPaywall() {
        if store.isPro {
            viewModel.showingInspect = true
        } else {
            // Free taps still run the checks, so the paywall can speak to
            // this file; only the details are paid. The paywall opens
            // immediately; the teaser line fills in when the scan finishes
            // off-main.
            paywallTeaser = nil
            pendingInspectAfterUnlock = true
            showingPaywall = true
            let snapshot = viewModel.document
            Task.detached(priority: .userInitiated) {
                let teaser = TableView.inspectTeaser(for: snapshot)
                await MainActor.run { paywallTeaser = teaser }
            }
        }
    }

    private func withTableDialog<V: View>(_ content: V) -> some View {
        content.confirmationDialog(
            "Delete this row?",
            isPresented: rowDeletePresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let row = rowToDelete {
                    viewModel.deleteRow(id: row.id)
                    rowToDelete = nil
                }
            }
        }
    }

    private var rowDeletePresented: Binding<Bool> {
        Binding(
            get: { rowToDelete != nil },
            set: { if !$0 { rowToDelete = nil } }
        )
    }

    private func withTableSheets<V: View>(_ content: V) -> some View {
        content
            .sheet(isPresented: $viewModel.showingInspect) {
                inspectSheet
            }
            .sheet(isPresented: $viewModel.showingColumnStats) {
                columnStatsSheet
            }
            .iphoneRawCSVSheet(isPresented: iphoneRawCSVPresented, viewModel: viewModel)
            .sheet(isPresented: $showingPaywall, onDismiss: handlePaywallDismiss) {
                PaywallView(teaser: paywallTeaser)
            }
    }

    private var inspectSheet: some View {
        InspectView(findings: viewModel.runInspection()) {
            viewModel.showingInspect = false
        }
    }

    @ViewBuilder
    private var columnStatsSheet: some View {
        if let index = viewModel.statsColumnIndex,
           let document = viewModel.document,
           document.headers.indices.contains(index),
           let stats = viewModel.columnStats(for: index) {
            ColumnStatsView(
                viewModel: viewModel,
                columnIndex: index,
                headerName: document.headers[index],
                stats: stats
            )
            .mediumLargeSheetDetents()
        }
    }

    private func handlePaywallDismiss() {
        let openInspect = pendingInspectAfterUnlock && store.isPro
        pendingInspectAfterUnlock = false
        if openInspect { viewModel.showingInspect = true }
    }

    /// Runs a Pro-only action, or opens the paywall when the app isn't unlocked.
    /// The gate for Find & Replace and Column Stats; Inspect gates inline above
    /// so it can attach a file-specific teaser to the paywall.
    private func gatePro(_ action: () -> Void) {
        if store.isPro {
            action()
        } else {
            paywallTeaser = nil
            pendingInspectAfterUnlock = false
            showingPaywall = true
        }
    }

    /// One sentence about what Inspect just found in the open file, for the
    /// paywall. Names the finding categories but keeps counts and locations
    /// paid. Scans the in-memory table only, never the file on disk, so the
    /// ragged-rows check is skipped here; the paid Inspect view includes it.
    private nonisolated static func inspectTeaser(for document: CSVDocument?) -> String {
        guard let document else {
            return "Inspect checks every table for data-quality issues before they spread."
        }
        let findings = InspectService.inspect(document, rawParsedRows: nil)
        let name = "\"\(document.name)\""
        guard !findings.isEmpty else {
            return "Inspect checked \(name) and found no issues today."
        }
        let clauses = findings.map { clause(for: $0.kind) }
        let listed: String
        switch clauses.count {
        case 1:
            listed = clauses[0]
        case 2:
            listed = "\(clauses[0]) and \(clauses[1])"
        default:
            listed = "\(clauses[0]), \(clauses[1]), and \(clauses.count - 2) more issue\(clauses.count == 3 ? "" : "s")"
        }
        return "Inspect found \(listed) in \(name). Unlock Pro to see the details."
    }

    /// Finding categories phrased as clauses so they read inside a sentence
    /// (the InspectionFinding titles are headings and do not).
    private nonisolated static func clause(for kind: InspectionFinding.Kind) -> String {
        switch kind {
        case .raggedRows: return "ragged rows"
        case .duplicateRows: return "duplicate rows"
        case .emptyInFullColumn: return "blank cells in populated columns"
        case .spreadsheetUnsafe: return "numbers spreadsheets would corrupt"
        case .mixedDateFormats: return "mixed date formats"
        case .untrimmedWhitespace: return "stray leading or trailing spaces"
        }
    }

    /// Locked tools keep their real icon and pick up a small PRO capsule, so
    /// they read as purchasable power tools rather than unavailable actions.
    @ViewBuilder
    private func proLabel(_ title: String, systemImage: String) -> some View {
        if store.isPro {
            Label(title, systemImage: systemImage)
                .fontWeight(.light)
                .symbolRenderingMode(.hierarchical)
        } else {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .fontWeight(.light)
                    .symbolRenderingMode(.hierarchical)
                proBadge
            }
            .accessibilityLabel("\(title) (Pro)")
        }
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(.tint)
    }

    /// Table alone, or table + companion note pane side by side on wide layouts.
    @ViewBuilder
    private func content(for document: CSVDocument) -> some View {
        if isWide, showingNotePane, sourceInConnectedFolder, let mdURL = viewModel.pairedMarkdownURL {
            HStack(spacing: 0) {
                tableContent(for: document)
                Divider()
                CompanionNotePane(url: mdURL)
                    .frame(minWidth: 280, idealWidth: 340, maxWidth: 460)
            }
        } else {
            tableContent(for: document)
        }
    }

    private func tableContent(for document: CSVDocument) -> some View {
        VStack(spacing: 0) {
            if viewModel.showingFindReplace {
                FindReplaceBar(
                    findQuery: $viewModel.findQuery,
                    replaceQuery: $viewModel.replaceQuery,
                    isVisible: $viewModel.showingFindReplace,
                    matchCount: viewModel.findMatchCount,
                    totalRows: document.rowCount,
                    onReplaceOne: { viewModel.replaceOne() },
                    onReplaceAll: { viewModel.replaceAll() }
                )
                Divider()
            }

            if document.rowCount > Self.largeFileThreshold {
                Text("Large file — \(document.rowCount) rows. Rows are virtualized for smooth scrolling.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                Divider()
            }

            virtualTable(for: document)

            if usesInlineRawCSV {
                Divider()
                rawCSVFooter
            }
        }
    }

    /// Always-visible footer: title + hint + chevron, then the editor when open.
    /// The collapsed state is the entry point — not a tiny unlabeled disclosure.
    private var rawCSVFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            rawCSVToggle
            if viewModel.showingRawCSV {
                RawCSVView(viewModel: viewModel, showsHeader: false, autoFocus: true)
                    .frame(minHeight: 220)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var rawCSVToggle: some View {
        Button {
            toggleRawCSVFooter()
        } label: {
            rawCSVToggleLabel
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Raw CSV")
        .accessibilityHint("Paste or type comma-separated values")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(viewModel.showingRawCSV ? "Expanded" : "Collapsed")
    }

    private var rawCSVToggleLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(viewModel.showingRawCSV ? 90 : 0))
            VStack(alignment: .leading, spacing: 2) {
                Text("Raw CSV")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Paste or type comma-separated values")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
        }
        .contentShape(Rectangle())
    }

    private func toggleRawCSVFooter() {
        if viewModel.showingRawCSV {
            viewModel.showingRawCSV = false
            viewModel.wantsRawCSVFocus = false
        } else {
            viewModel.revealRawCSVEditor()
        }
    }

    /// Toolbar paperclip: toggle the side-by-side note (wide), cross-launch
    /// FlatNote (iPhone), or offer to create a companion when none exists.
    @ViewBuilder
    private func companionControls() -> some View {
        if !sourceInConnectedFolder {
            EmptyView()
        } else if let mdURL = viewModel.pairedMarkdownURL {
            if isWide {
                Button {
                    showingNotePane.toggle()
                } label: {
                    Label("Companion Note", systemImage: "note.text")
                }
            } else {
                PairedNoteButton(url: mdURL) {
                    Label("Open Paired Note", systemImage: "paperclip")
                }
            }
        } else if viewModel.sourceURL != nil {
            Button {
                addCompanion()
            } label: {
                Label("Add Companion Note", systemImage: "doc.badge.plus")
            }
        }
    }

    private func addCompanion() {
        guard let url = viewModel.createCompanionNote() else { return }
        #if os(macOS)
        showingNotePane = true
        #else
        if isWide {
            showingNotePane = true
        } else if let link = PaperclipHelper.flatNoteOpenURL(for: url) {
            openURL(link)
        }
        #endif
    }

    /// Virtualized table: one 2-axis ScrollView + LazyVStack so only on-screen
    /// rows are materialized (a 5k-row CSV scrolls smoothly), with the header
    /// pinned and columns fixed-width so they stay aligned during horizontal pan.
    private func virtualTable(for document: CSVDocument) -> some View {
        let rows = viewModel.searchQuery.isEmpty ? document.rows : viewModel.filteredRows
        // Outer horizontal scroll pans the whole table; the header sits above the
        // inner vertical scroll so it stays frozen while rows scroll. The inner
        // vertical ScrollView has a bounded height, so its LazyVStack genuinely
        // virtualizes (only on-screen rows are built).
        return ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow(for: document)
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            rowView(row, rowNumber: index + 1, document: document)
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    /// The frozen header: a corner cell over the row-number gutter, then a
    /// lettered, editable cell per column — the top edge of the spreadsheet.
    private func headerRow(for document: CSVDocument) -> some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: gutterWidth, height: headerHeight)
                .background(gutterFill)
                .gridCell(line: gridLine, edges: [.top, .leading, .trailing, .bottom])
            ForEach(Array(document.headers.enumerated()), id: \.offset) { index, _ in
                headerCell(index: index, document: document)
            }
        }
    }

    private func headerCell(index: Int, document: CSVDocument) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            headerMetaRow(index: index, document: document)
            TextField("Column \(index + 1)", text: headerBinding(columnIndex: index))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(width: cellWidth, height: headerHeight, alignment: .leading)
        .background(gutterFill)
        .gridCell(line: gridLine, edges: [.top, .trailing, .bottom])
        .contextMenu {
            headerContextMenu(index: index)
        }
    }

    private func headerMetaRow(index: Int, document: CSVDocument) -> some View {
        let sorted = viewModel.sortColumnIndex == index
        return HStack(spacing: 3) {
            // Column letter — click to sort by this column.
            Text(columnLetter(index))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(sorted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .onTapGesture { viewModel.sortByColumn(index) }
            if sorted {
                Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8))
                    .foregroundStyle(.tint)
            }
            Spacer(minLength: 0)
            headerTypeIcon(index: index, document: document)
        }
    }

    private func headerTypeIcon(index: Int, document: CSVDocument) -> some View {
        let icon = viewModel.resolvedType(
            forColumn: index,
            sample: document.rows.prefix(50).map { $0[index] }
        ).icon
        return Image(systemName: icon)
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func headerContextMenu(index: Int) -> some View {
        Button { viewModel.sortByColumn(index) } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        Button {
            gatePro {
                viewModel.statsColumnIndex = index
                viewModel.showingColumnStats = true
            }
        } label: {
            Label("Column Stats", systemImage: "chart.bar")
        }
    }

    private func rowView(_ row: CSVRow, rowNumber: Int, document: CSVDocument) -> some View {
        HStack(spacing: 0) {
            // Row-number gutter (right-click to delete the row).
            Text("\(rowNumber)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: gutterWidth, height: cellHeight)
                .background(gutterFill)
                .gridCell(line: gridLine, edges: [.leading, .trailing, .bottom])
                .contextMenu {
                    Button(role: .destructive) { rowToDelete = row } label: {
                        Label("Delete Row", systemImage: "trash")
                    }
                }
            ForEach(Array(document.headers.indices), id: \.self) { columnIndex in
                TextField("", text: cellBinding(row: row, columnIndex: columnIndex))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .frame(width: cellWidth, height: cellHeight, alignment: .leading)
                    .background(cellFill)
                    .gridCell(line: gridLine, edges: [.trailing, .bottom])
            }
        }
        .contextMenu {
            Button(role: .destructive) { rowToDelete = row } label: {
                Label("Delete Row", systemImage: "trash")
            }
        }
    }

    /// Binds against the row value already in hand (from ForEach), so the getter
    /// is O(1) — no per-cell scan of all rows on every render pass.
    private func cellBinding(row: CSVRow, columnIndex: Int) -> Binding<String> {
        Binding(
            get: { row.values.indices.contains(columnIndex) ? row.values[columnIndex] : "" },
            set: { viewModel.updateCell(rowID: row.id, columnIndex: columnIndex, value: $0) }
        )
    }

    private func headerBinding(columnIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard let document = viewModel.document,
                      document.headers.indices.contains(columnIndex) else {
                    return ""
                }
                return document.headers[columnIndex]
            },
            set: { viewModel.updateHeader(at: columnIndex, value: $0) }
        )
    }
}

/// Hairline borders on chosen edges of a cell, so adjacent cells share single
/// gridlines — the tight grid look of a spreadsheet.
private struct GridCellBorders: ViewModifier {
    let line: Color
    let edges: Edge.Set
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) { if edges.contains(.top) { line.frame(height: 1) } }
            .overlay(alignment: .bottom) { if edges.contains(.bottom) { line.frame(height: 1) } }
            .overlay(alignment: .leading) { if edges.contains(.leading) { line.frame(width: 1) } }
            .overlay(alignment: .trailing) { if edges.contains(.trailing) { line.frame(width: 1) } }
    }
}

private extension View {
    func gridCell(line: Color, edges: Edge.Set = [.trailing, .bottom]) -> some View {
        modifier(GridCellBorders(line: line, edges: edges))
    }

    /// iPhone sheet for the raw-CSV editor. No-op on Mac (the footer is inline).
    /// Uses the shared `mediumLargeSheetDetents()` wrapper so macOS still compiles.
    @ViewBuilder
    func iphoneRawCSVSheet(isPresented: Binding<Bool>, viewModel: TableViewModel) -> some View {
        #if os(iOS)
        sheet(isPresented: isPresented) {
            iPhoneRawCSVSheet(viewModel: viewModel)
        }
        #else
        self
        #endif
    }
}

#if os(iOS)
/// Compact-width raw-CSV editor. Apply reloads the grid; Done dismisses.
private struct iPhoneRawCSVSheet: View {
    @Bindable var viewModel: TableViewModel

    var body: some View {
        NavigationStack {
            RawCSVView(viewModel: viewModel, showsHeader: true, autoFocus: true)
                .padding()
                .navigationTitle("Raw CSV")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            viewModel.applyRawCSVChanges()
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            viewModel.showingRawCSV = false
                        }
                    }
                }
        }
        .mediumLargeSheetDetents()
    }
}
#endif
