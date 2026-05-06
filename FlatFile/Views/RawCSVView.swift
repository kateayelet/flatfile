//
//  RawCSVView.swift
//  FlatFile
//
//  Raw CSV text editor (Mac only)
//

import SwiftUI
import Observation

struct RawCSVView: View {
    @Bindable var viewModel: TableViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Raw CSV")
                    .font(.headline)
                Spacer()
                Button("Apply") {
                    viewModel.applyRawCSVChanges()
                }
                .buttonStyle(.bordered)
            }

            TextEditor(text: $viewModel.rawCSVText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 220)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2))
                }
        }
    }
}
