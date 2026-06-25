//
//  SidecarService.swift
//  FlatFile
//
//  Reads and writes the optional `<name>.flatfile` JSON next to a `.csv`.
//  Everything here degrades gracefully: a missing, unreadable, or malformed
//  sidecar simply means "open the .csv clean." A sidecar problem must never
//  block editing the table, so callers treat failures as "no sidecar."
//

import Foundation

enum SidecarService {
    static let fileExtension = "flatfile"

    /// The sidecar path for a `.csv`: same folder, same base name, `.flatfile`.
    static func sidecarURL(for csvURL: URL) -> URL {
        csvURL.deletingPathExtension().appendingPathExtension(fileExtension)
    }

    /// Loads the sidecar for a `.csv`, or `nil` if there is none / it can't be
    /// read / it isn't valid. Never throws — the `.csv` always opens regardless.
    /// `FileService.readText` establishes the security scope and throws when the
    /// file is absent, which we treat (like any failure) as "no sidecar."
    static func load(for csvURL: URL) -> FlatFileSidecar? {
        let url = sidecarURL(for: csvURL)
        guard let json = try? FileService.readText(from: url),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(FlatFileSidecar.self, from: data)
    }

    /// Persists the sidecar next to the `.csv`. If there's nothing worth keeping
    /// (`isEmpty`), the file is removed instead of writing an empty one — we never
    /// litter the user's folder. Writes are coordinated/atomic via `FileService`.
    static func save(_ sidecar: FlatFileSidecar, for csvURL: URL) throws {
        guard !sidecar.isEmpty else {
            delete(for: csvURL)
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sidecar)
        guard let json = String(data: data, encoding: .utf8) else { return }
        try FileService.writeText(json, to: sidecarURL(for: csvURL))
    }

    /// Removes the sidecar if present (a no-op if it isn't). Coordinated so
    /// Files/iCloud see the deletion cleanly.
    static func delete(for csvURL: URL) {
        let url = sidecarURL(for: csvURL)
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        var coordError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordError) { resolved in
            try? FileManager.default.removeItem(at: resolved)
        }
    }
}
