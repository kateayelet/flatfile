//
//  TableListView.swift
//  FlatFile
//
//  Workspace sidebar: sheets, file actions, connected folders, current file.
//  Styled as a native NavigationSplitView sidebar (List + Label + Section),
//  not a stack of bordered pills.
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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        List {
            newSheetSection
            sheetsSection
            workspaceSection
            if !library.recents.isEmpty {
                recentsSection
            }
            foldersSections
            if let document {
                currentFileSection(document)
            }
        }
        .sidebarListStyle(isCompact: horizontalSizeClass == .compact)
        .listSectionSpacing(16)
        .navigationTitle("FlatFile")
    }

    // MARK: - New Sheet

    private var newSheetSection: some View {
        Section {
            Button(action: onNewTable) {
                Label("New Sheet", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .sidebarHitTarget()
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 4, trailing: 12))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityLabel("New Sheet")
            .accessibilityHint("Create a new CSV sheet")
            .keyboardShortcut("n", modifiers: .command)
        }
    }

    // MARK: - Sheets

    private var sheetsSection: some View {
        Section {
            if library.allSheets.isEmpty {
                emptyCopy("Sheets you open appear here.")
            } else {
                ForEach(library.allSheets) { entry in
                    fileRow(
                        name: entry.displayName,
                        url: entry.url,
                        systemImage: "tablecells",
                        hasPairedNote: entry.hasPairedNote
                    )
                }
            }
        } header: {
            sidebarHeader("Sheets")
        }
    }

    // MARK: - Workspace

    private var workspaceSection: some View {
        Section {
            workspaceAction("Import CSV", systemImage: "square.and.arrow.down", action: onImport)
            workspaceAction("Connect Folder", systemImage: "folder.badge.plus", action: onConnectFolder)
            workspaceAction("Save As…", systemImage: "square.and.arrow.down.on.square", action: onSave)
                .disabled(document == nil)
            if let document {
                ShareLink(
                    item: document.rawCSV,
                    subject: Text(document.name),
                    message: Text("")
                ) {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                        .labelStyle(.titleAndIcon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sidebarHitTarget()
                .accessibilityLabel("Export CSV")
            }
        } header: {
            sidebarHeader("Workspace")
        }
    }

    // MARK: - Recents

    private var recentsSection: some View {
        Section {
            ForEach(library.recents) { item in
                fileRow(name: item.name, url: item.url, systemImage: "clock")
            }
            Button("Clear Recents", role: .destructive) {
                library.clearRecents()
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .sidebarHitTarget()
            .accessibilityLabel("Clear Recents")
        } header: {
            sidebarHeader("Recents")
        }
    }

    // MARK: - Folders

    @ViewBuilder
    private var foldersSections: some View {
        if library.folders.isEmpty {
            Section {
                emptyCopy("Connect a folder to browse CSVs.")
            } header: {
                sidebarHeader("Folders")
            }
        } else {
            ForEach(library.folders) { folder in
                folderSection(folder)
            }
        }
    }

    @ViewBuilder
    private func folderSection(_ folder: LibraryViewModel.Folder) -> some View {
        Section {
            if folder.entries.isEmpty {
                emptyCopy("This folder has no CSV files.")
            } else {
                ForEach(folder.entries) { entry in
                    fileRow(
                        name: entry.displayName,
                        url: entry.url,
                        systemImage: "tablecells",
                        hasPairedNote: entry.hasPairedNote
                    )
                }
            }
        } header: {
            HStack(spacing: 8) {
                Label(folder.name, systemImage: "folder")
                    .sidebarHeaderStyle()
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(folder.name)
                Spacer(minLength: 8)
                Button(role: .destructive) {
                    library.removeFolder(folder)
                } label: {
                    Image(systemName: "minus.circle")
                        .imageScale(.medium)
                        .frame(minWidth: folderDisconnectHitSize, minHeight: folderDisconnectHitSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Disconnect \(folder.name)")
            }
        }
    }

    // MARK: - Current File

    @ViewBuilder
    private func currentFileSection(_ document: CSVDocument) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .help(document.name)
                Text(currentFileCaption(for: document))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let sourceURL {
                    Text(sourceURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(sourceURL.lastPathComponent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(currentFileAccessibilityLabel(for: document))

            if let pairedMarkdownURL {
                PairedNoteButton(url: pairedMarkdownURL) {
                    Label("Open \(pairedMarkdownURL.lastPathComponent)", systemImage: "paperclip")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sidebarHitTarget()
            }
        } header: {
            sidebarHeader("Current File")
        }
    }

    // MARK: - Rows

    private func fileRow(
        name: String,
        url: URL,
        systemImage: String,
        hasPairedNote: Bool = false
    ) -> some View {
        Button {
            onOpenFile(url)
        } label: {
            HStack(spacing: 8) {
                Label(name, systemImage: systemImage)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if hasPairedNote {
                    Image(systemName: "paperclip")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Has paired note")
                }
                if isCurrent(url) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Currently open")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sidebarHitTarget()
        .help(name)
        .accessibilityAddTraits(isCurrent(url) ? .isSelected : [])
    }

    private func workspaceAction(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sidebarHitTarget()
        .help(title)
        .accessibilityLabel(title)
    }

    private func emptyCopy(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.regular))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(text)
    }

    private func sidebarHeader(_ title: String) -> some View {
        Text(title)
            .sidebarHeaderStyle()
    }

    // MARK: - Helpers

    private func isCurrent(_ url: URL) -> Bool {
        guard let sourceURL else { return false }
        return url.standardizedFileURL.path == sourceURL.standardizedFileURL.path
    }

    private func currentFileCaption(for document: CSVDocument) -> String {
        let columns = document.columnCount == 1 ? "1 column" : "\(document.columnCount) columns"
        let rows = document.rowCount == 1 ? "1 row" : "\(document.rowCount) rows"
        return "\(columns) · \(rows)"
    }

    private func currentFileAccessibilityLabel(for document: CSVDocument) -> String {
        var parts = [document.name, currentFileCaption(for: document)]
        if let sourceURL {
            parts.append(sourceURL.lastPathComponent)
        }
        return parts.joined(separator: ", ")
    }

    private var folderDisconnectHitSize: CGFloat {
        #if os(iOS)
        44
        #else
        24
        #endif
    }
}

// MARK: - Sidebar chrome

private extension View {
    /// iPhone/iPad drawer or sheet: keep rows at a 44pt hit target. Mac sidebar
    /// rows stay at the platform default so the list does not feel padded.
    @ViewBuilder
    func sidebarHitTarget() -> some View {
        #if os(iOS)
        frame(minHeight: 44, alignment: .center)
        #else
        self
        #endif
    }

    func sidebarHeaderStyle() -> some View {
        font(.caption.weight(.regular))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }

    @ViewBuilder
    func sidebarListStyle(isCompact: Bool) -> some View {
        #if os(macOS)
        listStyle(.sidebar)
        #else
        if isCompact {
            listStyle(.insetGrouped)
        } else {
            listStyle(.sidebar)
        }
        #endif
    }
}
