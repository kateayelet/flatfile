//
//  FolderLibrary.swift
//  FlatFile
//
//  Security-scoped folder bookmarks (persisted across launches) and
//  enumeration of the .csv files inside a connected folder.
//
//  Bookmarks are app configuration, not table data — so storing them in
//  UserDefaults is fine. No table content ever touches UserDefaults.
//

import Foundation

enum FolderLibrary {
    private static let bookmarksKey = "connectedFolderBookmarks"

    // MARK: - Bookmark persistence

    /// Raw bookmark blobs in the order the user connected them.
    static func loadBookmarks() -> [Data] {
        UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []
    }

    static func saveBookmarks(_ bookmarks: [Data]) {
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }

    /// Create a persistable bookmark for a folder the user just picked.
    /// The caller must already hold the folder's security scope.
    static func makeBookmark(for folderURL: URL) throws -> Data {
        #if os(macOS)
        return try folderURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #else
        return try folderURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        #endif
    }

    /// Resolve a stored bookmark back into a URL. `stale` is true when the
    /// bookmark should be regenerated (the file moved, OS re-issued it, etc.).
    static func resolveBookmark(_ data: Data) -> (url: URL, stale: Bool)? {
        var stale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = .withSecurityScope
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else {
            return nil
        }
        return (url, stale)
    }

    // MARK: - Enumeration

    /// List the `.csv` files in a folder, each tagged with whether a same-named
    /// `.md` companion exists. The folder's security scope must be active
    /// (the LibraryViewModel keeps it open for the app's lifetime).
    static func listCSVFiles(in folderURL: URL) -> [CSVFileEntry] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls
            .filter { $0.pathExtension.lowercased() == "csv" }
            .map { url in
                let mdURL = url.deletingPathExtension().appendingPathExtension("md")
                let hasNote = fm.fileExists(atPath: mdURL.path)
                return CSVFileEntry(url: url, hasPairedNote: hasNote)
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
