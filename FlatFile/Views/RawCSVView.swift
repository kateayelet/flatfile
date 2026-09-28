//
//  RawCSVView.swift
//  FlatFile
//
//  Raw CSV text editor — paste or type comma-separated values, then Apply.
//  Used as the Mac/iPad table footer pane and as an iPhone sheet.
//

import SwiftUI
import Observation

struct RawCSVView: View {
    @Bindable var viewModel: TableViewModel
    /// When false, the parent already shows the "Raw CSV" title (footer chrome).
    var showsHeader: Bool = true
    var autoFocus: Bool = false
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            toolbarRow
            if let error = viewModel.rawCSVError {
                errorBanner(error)
            }
            styledEditor
        }
        .onAppear { considerFocus() }
        .onChange(of: viewModel.wantsRawCSVFocus) { _, wants in
            if wants { considerFocus() }
        }
    }

    private var toolbarRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if showsHeader {
                headerCopy
            }
            Spacer(minLength: 8)
            applyButton
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Raw CSV")
                .font(.headline)
            Text("Paste or type comma-separated values")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var applyButton: some View {
        Button("Apply") {
            viewModel.applyRawCSVChanges()
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.return, modifiers: .command)
        .help("Reload the grid from this text (⌘↩)")
        .accessibilityHint("Reloads the table from the raw CSV text")
    }

    private func errorBanner(_ error: String) -> some View {
        Text(error)
            .font(.callout)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(error)
    }

    private var styledEditor: some View {
        rawEditor
            .focused($editorFocused)
            .frame(minHeight: 180)
            .padding(8)
            .background(editorBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.25))
            }
            .accessibilityLabel("Raw CSV")
            .accessibilityHint("Paste or type comma-separated values, then apply")
    }

    private func considerFocus() {
        guard autoFocus || viewModel.wantsRawCSVFocus else { return }
        // Wait a beat so the editor is in the window before taking first responder.
        DispatchQueue.main.async {
            editorFocused = true
            viewModel.wantsRawCSVFocus = false
        }
    }

    /// Monospaced editor. `scrollContentBackground` is iOS-only; on Mac the
    /// TextEditor already draws an opaque field.
    @ViewBuilder
    private var rawEditor: some View {
        #if os(iOS)
        TextEditor(text: $viewModel.rawCSVText)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
        #else
        TextEditor(text: $viewModel.rawCSVText)
            .font(.system(.body, design: .monospaced))
        #endif
    }

    private var editorBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }
}
