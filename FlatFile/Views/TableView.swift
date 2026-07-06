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

    /// Fixed column width keeps the pinned header aligned with virtualized rows.
    private let cellWidth: CGFloat = 160
    private static let largeFileThreshold = 2000
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

    var body: some View {
        if let document = viewModel.document {
            content(for: document)
            .navigationTitle(document.name)
            // Reset the note pane per document: tears it down (flushing its edits
            // via onDisappear) and clears the toggle so it never leaks across files.
            .onChange(of: viewModel.sourceURL) { _, _ in showingNotePane = false }
            .searchable(text: $viewModel.searchQuery, prompt: "Filter rows...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.undo()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(!viewModel.canUndo)
                        .keyboardShortcut("z", modifiers: .command)
                        Button {
                            viewModel.redo()
                        } label: {
                            Label("Redo", systemImage: "arrow.uturn.forward")
                        }
                        .disabled(!viewModel.canRedo)
                        .keyboardShortcut("z", modifiers: [.command, .shift])
                        companionControls()
                        Button {
                            gatePro { viewModel.showingFindReplace.toggle() }
                        } label: {
                            proLabel("Find & Replace", systemImage: "magnifyingglass")
                        }
                        Button {
                            if store.isPro {
                                viewModel.showingInspect = true
                            } else {
                                // Free taps still run the checks, so the paywall
                                // can speak to this file; only the details are paid.
                                // The paywall opens immediately; the teaser line
                                // fills in when the scan finishes off-main.
                                paywallTeaser = nil
                                pendingInspectAfterUnlock = true
                                showingPaywall = true
                                let snapshot = viewModel.document
                                Task.detached(priority: .userInitiated) {
                                    let teaser = TableView.inspectTeaser(for: snapshot)
                                    await MainActor.run { paywallTeaser = teaser }
                                }
                            }
                        } label: {
                            proLabel("Inspect", systemImage: "checkmark.seal")
                        }
                        ShareLink(
                            item: document.rawCSV,
                            subject: Text(document.name),
                            message: Text("")
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .confirmationDialog(
                "Delete this row?",
                isPresented: .init(
                    get: { rowToDelete != nil },
                    set: { if !$0 { rowToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let row = rowToDelete {
                        viewModel.deleteRow(id: row.id)
                        rowToDelete = nil
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingInspect) {
                InspectView(findings: viewModel.runInspection()) {
                    viewModel.showingInspect = false
                }
            }
            .sheet(isPresented: $viewModel.showingColumnStats) {
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
            .sheet(isPresented: $showingPaywall, onDismiss: {
                let openInspect = pendingInspectAfterUnlock && store.isPro
                pendingInspectAfterUnlock = false
                if openInspect { viewModel.showingInspect = true }
            }) {
                PaywallView(teaser: paywallTeaser)
            }
        } else {
            ContentUnavailableView(
                "No CSV Selected",
                systemImage: "tablecells",
                description: Text("Import a CSV file to start editing.")
            )
        }
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
        } else {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
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

            #if os(macOS)
            Divider()
            RawCSVView(viewModel: viewModel)
                .frame(maxHeight: 220)
            #endif
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
            VStack(alignment: .leading, spacing: 8) {
                headerRow(for: document)
                Divider()
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(rows) { row in
                            rowView(row, document: document)
                        }
                        Divider()
                            .padding(.top, 8)
                        RowAppendView(headers: document.headers) { values in
                            viewModel.appendRow(values)
                        }
                        .frame(width: 360, alignment: .leading)
                        .padding(.bottom)
                    }
                }
            }
            .padding()
        }
    }

    private func headerRow(for document: CSVDocument) -> some View {
        HStack(spacing: 12) {
            // Leading column reserved for the per-row actions menu.
            Color.clear.frame(width: 28, height: 1)
            ForEach(Array(document.headers.enumerated()), id: \.offset) { index, header in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        // The user's intended type (from the sidecar) if set,
                        // else inferred from a sample (not the whole column) so a
                        // big file doesn't pay an O(rows) scan on every redraw.
                        Image(systemName: viewModel.resolvedType(
                            forColumn: index,
                            sample: document.rows.prefix(50).map { $0[index] }
                        ).icon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Button {
                            viewModel.sortByColumn(index)
                        } label: {
                            Text("Sort")
                                .font(.caption.weight(.medium))
                        }
                        .buttonStyle(.borderless)

                        Spacer(minLength: 0)

                        Button {
                            gatePro {
                                viewModel.statsColumnIndex = index
                                viewModel.showingColumnStats = true
                            }
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "chart.bar")
                                    .font(.caption)
                                    .foregroundStyle(store.isPro ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                                if !store.isPro {
                                    proBadge
                                }
                            }
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(store.isPro ? "Column stats" : "Column stats (Pro)")

                        if viewModel.sortColumnIndex == index {
                            Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                    }
                    TextField(
                        "Column \(index + 1)",
                        text: headerBinding(columnIndex: index)
                    )
                    .textFieldStyle(.roundedBorder)
                    // The optional sidecar display name, shown only when it's been
                    // set to something other than the raw header.
                    if viewModel.displayName(forColumn: index) != header, !header.isEmpty {
                        Text(viewModel.displayName(forColumn: index))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: cellWidth, alignment: .leading)
            }
        }
        .padding(.vertical, 4)
        .background(.background)
    }

    private func rowView(_ row: CSVRow, document: CSVDocument) -> some View {
        HStack(spacing: 12) {
            // Tappable per-row delete — reliable on iPhone, where the cell
            // TextFields would otherwise swallow a long-press.
            rowActionsMenu(for: row)
            ForEach(Array(document.headers.indices), id: \.self) { columnIndex in
                TextField(
                    document.headers[columnIndex].isEmpty ? "Value" : document.headers[columnIndex],
                    text: cellBinding(row: row, columnIndex: columnIndex)
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: cellWidth)
            }
        }
        .contextMenu {
            // Right-click on Mac (and a secondary path elsewhere).
            Button(role: .destructive) {
                rowToDelete = row
            } label: {
                Label("Delete Row", systemImage: "trash")
            }
        }
    }

    private func rowActionsMenu(for row: CSVRow) -> some View {
        Menu {
            Button(role: .destructive) {
                rowToDelete = row
            } label: {
                Label("Delete Row", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Row actions")
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
