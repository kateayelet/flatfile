//
//  PairedNoteButton.swift
//  FlatFile
//
//  Opens the companion `.md` in FlatNote (the differentiator: a `.csv` and its
//  `.md` notes side by side in one folder, linked by filename, no database).
//
//  iOS: deep-link `flatnote://open?path=...`. When the paired files live in the
//  FlatNote folder, FlatNote opens the note IN PLACE so edits round-trip to the
//  same file. If FlatNote isn't installed, fall back to an in-app Quick Look.
//  macOS: hand off via NSWorkspace, revealing in Finder if no opener is found.
//

import SwiftUI
import QuickLook
#if os(macOS)
import AppKit
#endif

struct PairedNoteButton<Label: View>: View {
    let url: URL
    @ViewBuilder var label: () -> Label

    @Environment(\.openURL) private var openURL
    @State private var previewURL: URL?

    var body: some View {
        #if os(macOS)
        Button(action: openOnMac, label: label)
        #else
        Button(action: openOnIOS, label: label)
            .quickLookPreview($previewURL)
        #endif
    }

    #if os(macOS)
    private func openOnMac() {
        if !NSWorkspace.shared.open(url) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    #else
    private func openOnIOS() {
        guard let link = Self.flatNoteLink(for: url) else {
            previewURL = url
            return
        }
        openURL(link) { accepted in
            // FlatNote not installed — preview the note in place instead.
            if !accepted { previewURL = url }
        }
    }

    private static func flatNoteLink(for fileURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "flatnote"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "path", value: fileURL.path)]
        return components.url
    }
    #endif
}
