import SwiftUI

struct NewTableSheetView: View {
    @Binding var tableName: String
    @State private var columnCount = 3
    @State private var rowCount = 0

    let onCreateBlank: (_ name: String, _ columnCount: Int, _ rowCount: Int) -> Void
    let onChooseTemplate: (_ name: String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Table") {
                    TextField("Table name", text: $tableName)

                    Stepper(value: $columnCount, in: 1...24) {
                        LabeledContent("Columns", value: "\(columnCount)")
                    }

                    Stepper(value: $rowCount, in: 0...200) {
                        LabeledContent("Starting rows", value: "\(rowCount)")
                    }
                }

                Section("Template") {
                    Button("Choose Template") {
                        let trimmedName = tableName.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                        onChooseTemplate(trimmedName)
                    }
                }
            }
            .navigationTitle("New Table")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmedName = tableName.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreateBlank(trimmedName.isEmpty ? "Untitled" : trimmedName, columnCount, rowCount)
                        dismiss()
                    }
                }
            }
        }
    }
}
