//
//  PaywallView.swift
//  FlatFile
//
//  Shown when someone taps a Pro-only power tool without the unlock. FlatFile
//  stays fully usable for editing without ever seeing this; it only gates the
//  analysis tools.
//

import SwiftUI

struct PaywallView: View {
    /// A sentence about the user's own file (e.g. what Inspect just found in
    /// it), shown under the header. The strongest pitch is their own data.
    var teaser: String?

    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    private struct Perk: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let perks: [Perk] = [
        Perk(icon: "checkmark.seal",
             title: "Inspect",
             detail: "Data-quality checks that flag ragged rows, stray types, and blanks."),
        Perk(icon: "magnifyingglass",
             title: "Find & Replace",
             detail: "Search and rewrite values across the whole table at once."),
        Perk(icon: "chart.bar",
             title: "Column Stats & Schema",
             detail: "Per-column summaries plus a saved display name and type."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    VStack(spacing: 16) {
                        ForEach(perks) { perk in
                            perkRow(perk)
                        }
                    }
                    .frame(maxWidth: 460)

                    Text("Editing, folders, sort, search, share, and the FlatNote paperclip are always free. Your files stay plain .csv either way.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 460)

                    if let error = store.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    actions
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("FlatFile Pro")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
            .onChange(of: store.isPro) { _, unlocked in
                if unlocked { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Unlock the power tools")
                .font(.title2.weight(.semibold))
            Text("One-time purchase. No subscription.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let teaser {
                Text(teaser)
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .frame(maxWidth: 460)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 4)
            }
        }
        .padding(.top, 8)
    }

    private func perkRow(_ perk: Perk) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: perk.icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(perk.title)
                    .font(.headline)
                Text(perk.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await store.purchase() }
            } label: {
                HStack {
                    if store.isWorking {
                        ProgressView()
                    } else {
                        Text("Unlock Pro for \(store.displayPrice)")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: 460)
                .frame(minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isWorking || store.proProduct == nil)

            Button("Restore Purchases") {
                Task { await store.restore() }
            }
            .font(.subheadline)
            .disabled(store.isWorking)
        }
        .padding(.top, 4)
    }
}
