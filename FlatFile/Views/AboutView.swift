//
//  AboutView.swift
//  FlatFile
//
//  The "What is FlatFile?" card. Same copy everywhere it appears:
//  Settings, the Home Screen quick action, and the Mac About window.
//  Title matches the button. Credit is personal — the App Store listing
//  is under Kate Benediktsson, not Aftrveil Labs.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Canonical About strings. Shortcut type follows the Flat family
/// (`com.aftrveil.*`) used by FlatNote; the shipping bundle id is
/// `aftrveil.FlatFile`.
enum AboutCopy {
    static let title = "What is FlatFile?"
    /// Home Screen quick action type. Must match `UIApplicationShortcutItemType`
    /// in `FlatFile-Info.plist`.
    static let shortcutType = "com.aftrveil.flatfile.about"

    static let paragraph1 = "FlatFile is a place to keep tables as plain files."
    static let paragraph2 = "Every table is an ordinary CSV: text you can open in any app, with no silent type changes. Your tables live in a folder you choose through Files or Finder. FlatFile stores no separate copy."
    static let paragraph3 = "There is no account because there is nothing an account would do for you. FlatFile collects nothing: no ads, no tracking, no analytics."
    static let paragraph4 = "If you ever stop using FlatFile, your tables remain ordinary CSV files, readable in any spreadsheet, on any device."
    static let madeForMom = "Made for Mom by Kate Benediktsson"

    static func versionLine(version: String, build: String) -> String {
        "FlatFile \(version) (Build \(build))"
    }
}

#if os(macOS)
enum AboutWindow {
    static let id = "about"
}
#endif

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var versionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return AboutCopy.versionLine(version: version, build: build)
    }

    @ViewBuilder
    private var copyBlock: some View {
        Text(AboutCopy.paragraph1)
        Text(AboutCopy.paragraph2)
        Text(AboutCopy.paragraph3)
        Text(AboutCopy.paragraph4)
    }

    @ViewBuilder
    private var creditBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(versionLine)
            Text(AboutCopy.madeForMom)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    var body: some View {
        #if os(macOS)
        // A real About window: content-hugging height, dismissed by the
        // window's own controls — no confirmation-style button.
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                Spacer()
            }
            Text(AboutCopy.title)
                .font(.title2.bold())
            copyBlock
                .font(.body)
            creditBlock
        }
        .padding(24)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(AboutCopy.title)
                    .font(.title2.bold())

                VStack(alignment: .leading, spacing: 30) {
                    copyBlock
                }
                .font(.body)

                creditBlock
                    .padding(.top, 4)

                Button {
                    dismiss()
                } label: {
                    Text("Understood")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .padding(.top, 6)
            }
            .padding(24)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(14)
            .accessibilityLabel("Close")
        }
        .presentationDetents([.large, .medium])
        #endif
    }
}
