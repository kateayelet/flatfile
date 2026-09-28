//
//  SheetLibraryView.swift
//  FlatFile
//
//  The home page: a grid of tiles for every sheet you have — the ones FlatFile
//  keeps in its own folder plus any connected folders — newest first. Tap a
//  tile to open it. Mirrors FlatNote's library so the two apps feel like a set.
//

import SwiftUI

struct SheetLibraryView: View {
    let library: LibraryViewModel
    let currentURL: URL?
    let onOpen: (URL) -> Void
    let onNewSheet: () -> Void
    let onImport: () -> Void
    let onConnectFolder: () -> Void

    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 14)]

    /// Sheets to show, filtered by the search field (name match).
    private var sheets: [CSVFileEntry] {
        let all = library.allSheets
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter { $0.displayName.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        ScrollView {
            if library.allSheets.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(sheets) { entry in
                        Button { onOpen(entry.url) } label: { tile(entry) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if isOwned(entry.url) {
                                    Button(role: .destructive) {
                                        library.deleteOwnedSheet(entry.url)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Sheets")
        .searchable(text: $query, prompt: "Search sheets")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { onImport() } label: { Label("Open a file", systemImage: "folder") }
                    Button { onConnectFolder() } label: { Label("Connect a folder", systemImage: "folder.badge.plus") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { onNewSheet() } label: {
                    Image(systemName: "plus.square.on.square")
                }
                .accessibilityLabel("New sheet")
            }
            #endif
        }
        .onAppear { library.refresh() }
    }

    /// True when the file lives in FlatFile's own folder (so it's ours to delete).
    private func isOwned(_ url: URL) -> Bool {
        url.deletingLastPathComponent().standardizedFileURL.path
            == library.ownedFolderURL.standardizedFileURL.path
    }

    private func tile(_ entry: CSVFileEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "tablecells")
                    .font(.title3)
                    .foregroundStyle(.tint)
                Spacer()
                if entry.hasPairedNote {
                    Image(systemName: "paperclip")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Has a paired note")
                }
                if entry.url.standardizedFileURL.path == currentURL?.standardizedFileURL.path {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Currently open")
                }
            }
            Spacer(minLength: 20)
            Text(entry.displayName)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(height: 120, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(cardFill))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.06)))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tablecells")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No sheets yet")
                .font(.body.weight(.regular))
                .foregroundStyle(.secondary)
            Text("Create a sheet, or open a CSV from Files.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { onNewSheet() } label: {
                Label("New Sheet", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }

    private var cardFill: Color {
        #if os(iOS)
        Color(.secondarySystemBackground)
        #else
        Color.gray.opacity(0.10)
        #endif
    }
}
