import SwiftUI

struct FindReplaceBar: View {
    @Binding var findQuery: String
    @Binding var replaceQuery: String
    @Binding var isVisible: Bool
    let matchCount: Int
    let totalRows: Int
    let onReplaceOne: () -> Void
    let onReplaceAll: () -> Void

    @State private var showReplace = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Find...", text: $findQuery)
                    .textFieldStyle(.roundedBorder)
                Text("\(matchCount)/\(totalRows)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44)
                Button { showReplace.toggle() } label: {
                    Image(systemName: "arrow.2.squarepath")
                        .foregroundStyle(showReplace ? .primary : .secondary)
                }
                Button {
                    findQuery = ""
                    replaceQuery = ""
                    isVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            if showReplace {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(.secondary)
                    TextField("Replace with...", text: $replaceQuery)
                        .textFieldStyle(.roundedBorder)
                    Button("Replace", action: onReplaceOne)
                        .buttonStyle(.bordered)
                        .disabled(findQuery.isEmpty)
                    Button("All", action: onReplaceAll)
                        .buttonStyle(.borderedProminent)
                        .disabled(findQuery.isEmpty)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
