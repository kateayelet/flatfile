import SwiftUI

struct ColumnStatsView: View {
    let headerName: String
    let stats: ColumnStats

    var body: some View {
        NavigationStack {
            List {
                Section("Overview") {
                    row("Type", value: stats.type.rawValue, icon: stats.type.icon)
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
            .navigationTitle(headerName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
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
