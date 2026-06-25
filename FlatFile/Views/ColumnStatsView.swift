import SwiftUI

struct ColumnStatsView: View {
    @Bindable var viewModel: TableViewModel
    let columnIndex: Int
    let headerName: String
    let stats: ColumnStats

    /// Edited locally and committed to the sidecar on submit / disappear, so we
    /// don't write a file on every keystroke.
    @State private var displayNameDraft: String = ""

    /// nil == "Auto" (use the inferred type). A concrete case overrides it.
    private var intendedType: ColumnType? { viewModel.intendedType(forColumn: columnIndex) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(headerName, text: $displayNameDraft)
                        .onSubmit(commitDisplayName)
                    Picker("Type", selection: typeSelection) {
                        Text("Auto (\(stats.type.rawValue))").tag(ColumnType?.none)
                        ForEach(ColumnType.allCases, id: \.self) { type in
                            Label(type.rawValue.capitalized, systemImage: type.icon)
                                .tag(ColumnType?.some(type))
                        }
                    }
                } header: {
                    Text("Column")
                } footer: {
                    Text("Display name and type are saved in an optional \"\(headerName).flatfile\" note beside the CSV. The CSV itself is never changed.")
                }

                Section("Overview") {
                    row("Type", value: presentedType.rawValue, icon: presentedType.icon)
                    row("Total rows", value: "\(stats.total)")
                    row("Filled", value: "\(stats.filled) (\(pct(stats.filled, stats.total)))")
                    row("Empty", value: "\(stats.empty)")
                    row("Unique values", value: "\(stats.unique)")
                }

                Section("Frequency") {
                    row("Most common", value: stats.topValue.isEmpty ? "--" : stats.topValue)
                    row("Occurrences", value: "\(stats.topCount)")
                }

                if stats.type == .number {
                    Section("Numeric") {
                        if let min = stats.min { row("Min", value: formatted(min)) }
                        if let max = stats.max { row("Max", value: formatted(max)) }
                        if let sum = stats.sum { row("Sum", value: formatted(sum)) }
                        if let avg = stats.avg { row("Average", value: formatted(avg)) }
                    }
                }
            }
            .navigationTitle(viewModel.displayName(forColumn: columnIndex))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .onAppear { displayNameDraft = viewModel.customDisplayName(forColumn: columnIndex) }
        .onDisappear(perform: commitDisplayName)
    }

    /// The type to show: the user's intended type if set, else the inferred one.
    private var presentedType: ColumnType { intendedType ?? stats.type }

    private var typeSelection: Binding<ColumnType?> {
        Binding(
            get: { intendedType },
            set: { viewModel.setIntendedType($0, forColumn: columnIndex) }
        )
    }

    private func commitDisplayName() {
        viewModel.setDisplayName(displayNameDraft, forColumn: columnIndex)
    }

    private func row(_ label: String, value: String, icon: String? = nil) -> some View {
        HStack {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }

    private func pct(_ n: Int, _ total: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int(round(Double(n) / Double(total) * 100)))%"
    }

    private func formatted(_ n: Double) -> String {
        n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(format: "%.2f", n)
    }
}
