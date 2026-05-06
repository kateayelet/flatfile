//
//  RowAppendView.swift
//  FlatFile
//
//  Single-row form at bottom for quick append
//

import SwiftUI

struct RowAppendView: View {
    let headers: [String]
    let onAppend: ([String]) -> Void

    @State private var draftValues: [String]

    init(headers: [String], onAppend: @escaping ([String]) -> Void) {
        self.headers = headers
        self.onAppend = onAppend
        _draftValues = State(initialValue: Array(repeating: "", count: headers.count))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Append Row")
                .font(.headline)

            ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                TextField(header.isEmpty ? "Column \(index + 1)" : header, text: binding(for: index))
                    .textFieldStyle(.roundedBorder)
            }

            Button("Add Row") {
                onAppend(draftValues)
                draftValues = Array(repeating: "", count: headers.count)
            }
            .buttonStyle(.borderedProminent)
        }
        .onChange(of: headers) { _, newHeaders in
            draftValues = Array(draftValues.prefix(newHeaders.count))
            if draftValues.count < newHeaders.count {
                draftValues.append(contentsOf: Array(repeating: "", count: newHeaders.count - draftValues.count))
            }
        }
    }

    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { draftValues.indices.contains(index) ? draftValues[index] : "" },
            set: { newValue in
                if draftValues.indices.contains(index) {
                    draftValues[index] = newValue
                }
            }
        )
    }
}
