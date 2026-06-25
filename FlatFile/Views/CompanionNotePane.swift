//
//  CompanionNotePane.swift
//  FlatFile
//
//  iPad/Mac side-by-side companion: the paired `.md` shown next to the table as
//  plain text (FlatFile is the plaintext stack; FlatNote remains the rich editor,
//  one tap away). Edits autosave in place to the same `.md` file.
//

import SwiftUI

struct CompanionNotePane: View {
    let url: URL

    @State private var text = ""
    @State private var lastSaved = ""
    @State private var loadedURL: URL?
    @State private var saveTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label(url.lastPathComponent, systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                PairedNoteButton(url: url) {
                    Label("Open in FlatNote", systemImage: "arrow.up.forward.app")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()
            TextEditor(text: $text)
                .font(.body)
                .padding(4)
        }
        .background(.background)
        .task(id: url) { load() }
        .onChange(of: text) { _, _ in if loadedURL != nil { scheduleSave() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { flush() } }
        .onDisappear { flush() }
    }

    private func load() {
        flush() // persist edits to the previously shown note before switching
        let content = (try? FileService.readText(from: url)) ?? ""
        text = content
        lastSaved = content
        loadedURL = url
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            flush()
        }
    }

    /// Writes to the URL currently loaded (not necessarily `url`, which may have
    /// just changed), so switching notes never writes one note's text to another.
    private func flush() {
        saveTask?.cancel()
        guard let loadedURL, text != lastSaved else { return }
        do {
            try FileService.writeText(text, to: loadedURL)
            lastSaved = text
        } catch {
            // A failed note save shouldn't disrupt table editing; leave the buffer
            // intact so the next autosave tick can retry.
        }
    }
}
