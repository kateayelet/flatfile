//
//  CreditsView.swift
//  FlatFile
//
//  Family dedication card. Same copy everywhere it appears: Settings
//  and the Mac Credits window. Layout matches AboutView.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Canonical Credits strings. Locked Flat family dedication — must stay verbatim.
enum CreditsCopy {
    static let title = "Credits"
    static let blurb = "FlatNote, FlatFile, and Flat Voice are for my mama, Cathy Benediktsson. Inspired by my brother John Benediktsson — my hero. Notes, files, and voice, kept simple."
}

#if os(macOS)
enum CreditsWindow {
    static let id = "credits"
}
#endif

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss

    private var versionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return AboutCopy.versionLine(version: version, build: build)
    }

    @ViewBuilder
    private var creditBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(versionLine)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    var body: some View {
        #if os(macOS)
        // Same chrome as About: content-hugging height, dismissed by the
        // window's own controls — no confirmation-style button.
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                Spacer()
            }
            Text(CreditsCopy.title)
                .font(.title2.bold())
            Text(CreditsCopy.blurb)
                .font(.body)
            creditBlock
        }
        .padding(24)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        #else
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(CreditsCopy.title)
                    .font(.title2.bold())

                Text(CreditsCopy.blurb)
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
