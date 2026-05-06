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
}
