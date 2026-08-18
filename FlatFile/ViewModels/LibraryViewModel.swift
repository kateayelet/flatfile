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

    /// A recently opened file, resolved from a persisted bookmark.
    struct RecentItem: Identifiable {
        let id: String      // normalized filesystem path
        let url: URL
        let bookmark: Data
        var name: String { url.deletingPathExtension().lastPathComponent }
    }

    private(set) var folders: [Folder] = []
    private(set) var recents: [RecentItem] = []
    private static let maxRecents = 12
    var errorMessage: String?

    /// FlatFile's own folder — the app's Documents directory, shown as "FlatFile"
    /// in the Files app (Info.plist sets UIFileSharingEnabled + open-in-place).
    /// Sheets created in the app land here so the home always has something to
    /// show, exactly like FlatNote. Files stay plain .csv — no proprietary store.
    let ownedFolderURL: URL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask).first!

    /// The `.csv` files in the owned folder.
    private(set) var ownedEntries: [CSVFileEntry] = []

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

        loadOwned()
        loadRecents()
    }

    // MARK: - Owned folder (FlatFile's own sheets)

    /// List the `.csv` files FlatFile keeps in its own folder.
    func loadOwned() {
        ownedEntries = FolderLibrary.listCSVFiles(in: ownedFolderURL)
    }

    /// Every sheet the home should tile: the owned folder plus any connected
    /// folders, de-duplicated by path and newest-modified first.
    var allSheets: [CSVFileEntry] {
        var seen = Set<String>()
        var out: [CSVFileEntry] = []
        for entry in ownedEntries + folders.flatMap({ $0.entries }) {
            let key = normalizedKey(entry.url)
            if seen.insert(key).inserted { out.append(entry) }
        }
        return out.sorted { modified($0.url) > modified($1.url) }
    }

    private func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    /// Create a new `.csv` in the owned folder from a row matrix (first row =
    /// headers). Returns the file URL, or nil on failure. The name is made
    /// unique so a second "Untitled" becomes "Untitled 2".
    func createSheetFile(name: String, rows: [[String]]) -> URL? {
        let base = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = base.isEmpty ? "Untitled" : base
        var url = ownedFolderURL.appendingPathComponent(safe).appendingPathExtension("csv")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = ownedFolderURL.appendingPathComponent("\(safe) \(n)").appendingPathExtension("csv")
            n += 1
        }
        do {
            try Data(CSVParser.serialize(rows).utf8).write(to: url, options: .atomic)
            loadOwned()
            return url
        } catch {
            errorMessage = "Could not create the sheet. \(error.localizedDescription)"
            return nil
        }
    }

    /// Move a sheet to Trash (owned folder only) and re-list.
    func deleteOwnedSheet(_ url: URL) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        loadOwned()
    }

    // MARK: - Recents

    /// Resolve persisted recent-file bookmarks on launch (dropping any that no
    /// longer resolve), most-recent first.
    func loadRecents() {
        let blobs = RecentFilesStore.load()
        var items: [RecentItem] = []
        var seen = Set<String>()
        var changed = false

        for data in blobs {
            guard let (url, stale) = FolderLibrary.resolveBookmark(data) else { changed = true; continue }
            let key = normalizedKey(url)
            if seen.contains(key) { changed = true; continue }
            seen.insert(key)

            var blob = data
            if stale {
                let accessed = url.startAccessingSecurityScopedResource()
                if let fresh = try? FolderLibrary.makeBookmark(for: url) { blob = fresh; changed = true }
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            items.append(RecentItem(id: key, url: url, bookmark: blob))
        }

        recents = items
        if changed { RecentFilesStore.save(recents.map(\.bookmark)) }
    }

    /// Record (or bump to the top) a just-opened file. Capped and de-duplicated.
    func recordRecent(at url: URL) {
        let key = normalizedKey(url)
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let bookmark = try? FolderLibrary.makeBookmark(for: url) else { return }

        var updated = recents.filter { $0.id != key }
        updated.insert(RecentItem(id: key, url: url, bookmark: bookmark), at: 0)
        if updated.count > Self.maxRecents { updated = Array(updated.prefix(Self.maxRecents)) }
        recents = updated
        RecentFilesStore.save(recents.map(\.bookmark))
    }

    func clearRecents() {
        recents = []
        RecentFilesStore.save([])
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

    /// True when `url` lives inside a connected folder, so we hold a security
    /// scope that covers reading/writing it and creating siblings (e.g. a
    /// companion `.md`). Companion features are gated on this.
    func contains(_ url: URL) -> Bool {
        let target = url.standardizedFileURL.resolvingSymlinksInPath().path
        return folders.contains { folder in
            let base = folder.url.standardizedFileURL.resolvingSymlinksInPath().path
            return target == base || target.hasPrefix(base + "/")
        }
    }

    // MARK: - Refresh

    /// Re-list every connected folder (e.g. after a new file is saved into one,
    /// or on return to the foreground).
    func refresh() {
        loadOwned()
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

/// Persists recent-file bookmarks in UserDefaults (app config, never table data).
enum RecentFilesStore {
    private static let key = "recentFileBookmarks"

    static func load() -> [Data] {
        UserDefaults.standard.array(forKey: key) as? [Data] ?? []
    }

    static func save(_ bookmarks: [Data]) {
        UserDefaults.standard.set(bookmarks, forKey: key)
    }
}
