//
//  PaperclipHelper.swift
//  FlatFile
//
//  Detects paired .md file (FlatNote pairing)
//

import Foundation

enum PaperclipHelper {
    static func pairedMarkdownURL(for csvURL: URL?) -> URL? {
        guard let csvURL else { return nil }

        let markdownURL = csvURL
            .deletingPathExtension()
            .appendingPathExtension("md")

        return FileManager.default.fileExists(atPath: markdownURL.path) ? markdownURL : nil
    }

    /// Deep link that asks FlatNote to open a file: `flatnote://open?path=...`.
    static func flatNoteOpenURL(for fileURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "flatnote"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "path", value: fileURL.path)]
        return components.url
    }
}
