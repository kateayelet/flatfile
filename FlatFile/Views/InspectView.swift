//
//  InspectView.swift
//  FlatFile
//
//  Read-only data-quality report. FlatFile never guesses. Your data is your data.
//

import SwiftUI

struct InspectView: View {
    let findings: [InspectionFinding]
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if findings.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing to flag", systemImage: "checkmark.seal")
                    } description: {
                        Text("No data-quality oddities found. Every cell is exactly as written.")
                    }
                } else {
                    List(findings) { finding in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(finding.title, systemImage: finding.kind.symbol)
                                .font(.headline)
                            Text(finding.summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if !finding.samples.isEmpty {
                                Text(finding.samples.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Inspect")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .safeAreaInset(edge: .bottom) {
                Text("FlatFile never guesses. Your data is your data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        #if os(macOS)
        // On macOS a sheet sizes to its content; without a minimum the report
        // collapses to just the footer. Give it room to show the findings.
        .frame(minWidth: 480, minHeight: 600)
        #endif
    }
}
