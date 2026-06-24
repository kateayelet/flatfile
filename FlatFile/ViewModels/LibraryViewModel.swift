//
//  LibraryViewModel.swift
//  FlatFile
//
//  Owns the user's connected folders and the .csv files inside them.
//
//  A connected folder's security scope is held open for as long as the app
//  runs, so files opened from it can be read AND auto-saved (the per-file
//  start/stop in FileService can't grant access to files reached via a folder).
//
//  `folders` is the single source of truth: the persisted bookmark list is
//  always derived from it, so a folder and its bookmark can never drift apart.
//

import Foundation
import Observation

@MainActor
@Observable
final class LibraryViewModel {
    struct Folder: Identifiable {
        /// Normalized filesystem path — a stable de-dup / ForEach key.
        let id: String
        /// The resolved URL we hold security scope on (used for file access).
        let url: URL
        /// The persistable bookmark this folder was created/resolved from.
        let bookmark: Data
        var entries: [CSVFileEntry]

        var name: String { url.lastPathComponent }
    }

    private(set) var folders: [Folder] = []
    var errorMessage: String?

    /// Folder URLs whose security scope we currently hold open.
    private var scopedURLs: [URL] = []

    // MARK: - Lifecycle

    /// Resolve persisted bookmarks on launch and list each folder's contents.
    func loadConnectedFolders() {
        let bookmarks = FolderLibrary.loadBookmarks()
        var resolved: [Folder] = []
        var seen = Set<String>()
        var changed = false

        for data in bookmarks {
            guard let (url, stale) = FolderLibrary.resolveBookmark(data) else {
                changed = true // bookmark no longer resolves — drop it
                continue
            }

            let key = normalizedKey(url)
            if seen.contains(key) {
                changed = true // duplicate of a folder we already loaded — drop it
                continue
            }
            seen.insert(key)

            beginAccess(to: url)

            // Regenerate a stale bookmark so it keeps resolving next launch.
            var blob = data
            if stale, let fresh = try? FolderLibrary.makeBookmark(for: url) {
                blob = fresh
                changed = true
            }

            resolved.append(Folder(
                id: key,
                url: url,
                bookmark: blob,
                entries: FolderLibrary.listCSVFiles(in: url)
            ))
        }

        folders = resolved
        if changed { persist() }
    }

    // MARK: - Connect / remove

    func connectFolder(at url: URL) {
        let key = normalizedKey(url)
        guard !folders.contains(where: { $0.id == key }) else {
            refresh() // already connected — just re-list in case contents changed
            return
        }

        let accessed = url.startAccessingSecurityScopedResource()
        do {
            let bookmark = try FolderLibrary.makeBookmark(for: url)
            if accessed { scopedURLs.append(url) } // retain scope for the session
            folders.append(Folder(
                id: key,
                url: url,
                bookmark: bookmark,
                entries: FolderLibrary.listCSVFiles(in: url)
            ))
            persist()
        } catch {
            if accessed { url.stopAccessingSecurityScopedResource() }
            errorMessage = "Could not connect that folder. \(error.localizedDescription)"
        }
    }

    func removeFolder(_ folder: Folder) {
        endAccess(to: folder.url)
        folders.removeAll { $0.id == folder.id }
        persist()
    }

    // MARK: - Refresh

    /// Re-list every connected folder (e.g. after a new file is saved into one,
    /// or on return to the foreground).
    func refresh() {
        folders = folders.map { folder in
            var updated = folder
            updated.entries = FolderLibrary.listCSVFiles(in: folder.url)
            return updated
        }
    }

    // MARK: - Persistence

    /// The stored bookmark list is always exactly the folders we hold.
    private func persist() {
        FolderLibrary.saveBookmarks(folders.map(\.bookmark))
    }

    // MARK: - Security scope bookkeeping

    private func normalizedKey(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private func beginAccess(to url: URL) {
        guard !scopedURLs.contains(url) else { return }
        if url.startAccessingSecurityScopedResource() {
            scopedURLs.append(url)
        }
    }

    private func endAccess(to url: URL) {
        guard let index = scopedURLs.firstIndex(of: url) else { return }
        url.stopAccessingSecurityScopedResource()
        scopedURLs.remove(at: index)
    }
}
