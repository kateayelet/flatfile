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
    @State private var rowToDelete: CSVRow?

    var body: some View {
        if let document = viewModel.document {
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        tableGrid(for: document)
                        Divider()
                        RowAppendView(headers: document.headers) { values in
                            viewModel.appendRow(values)
                        }
                        #if os(macOS)
                        Divider()
                        RawCSVView(viewModel: viewModel)
                        #endif
                    }
                    .padding()
                }
            }
            .navigationTitle(document.name)
            .searchable(text: $viewModel.searchQuery, prompt: "Filter rows...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.showingFindReplace.toggle()
                        } label: {
                            Label("Find & Replace", systemImage: "magnifyingglass")
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
            .sheet(isPresented: $viewModel.showingColumnStats) {
                if let index = viewModel.statsColumnIndex,
                   let document = viewModel.document,
                   let stats = viewModel.columnStats(for: index) {
                    ColumnStatsView(
                        headerName: document.headers[index],
                        stats: stats
                    )
                    .presentationDetents([.medium])
                }
            }
        } else {
            ContentUnavailableView(
                "No CSV Selected",
                systemImage: "tablecells",
                description: Text("Import a CSV file to start editing.")
            )
        }
    }

    private func tableGrid(for document: CSVDocument) -> some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    // Leading column reserved for the per-row actions menu.
                    Color.clear.frame(width: 28, height: 28)
                    ForEach(Array(document.headers.enumerated()), id: \.offset) { index, header in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: ColumnType.infer(from: document.rows.map { $0[index] }).icon)
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
                                    viewModel.statsColumnIndex = index
                                    viewModel.showingColumnStats = true
                                } label: {
                                    Image(systemName: "chart.bar")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

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
                        }
                        .frame(minWidth: 140, alignment: .leading)
                    }
                }

                let rows = viewModel.searchQuery.isEmpty ? document.rows : viewModel.filteredRows
                ForEach(rows) { row in
                    GridRow {
                        // Tappable per-row delete — reliable on iPhone, where the
                        // cell TextFields would otherwise swallow a long-press.
                        rowActionsMenu(for: row)
                        ForEach(Array(document.headers.indices), id: \.self) { columnIndex in
                            TextField(
                                document.headers[columnIndex].isEmpty ? "Value" : document.headers[columnIndex],
                                text: cellBinding(rowID: row.id, columnIndex: columnIndex)
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 140)
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

    private func cellBinding(rowID: UUID, columnIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard let row = viewModel.document?.rows.first(where: { $0.id == rowID }) else {
                    return ""
                }
                return row[columnIndex]
            },
            set: { viewModel.updateCell(rowID: rowID, columnIndex: columnIndex, value: $0) }
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
