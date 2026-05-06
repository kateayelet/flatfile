import Foundation

enum ColumnType: String, CaseIterable {
    case text, number, date, boolean, url

    var icon: String {
        switch self {
        case .text: "textformat"
        case .number: "number"
        case .date: "calendar"
        case .boolean: "checkmark.square"
        case .url: "link"
        }
    }

    static func infer(from values: [String]) -> ColumnType {
        let nonEmpty = values.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonEmpty.isEmpty else { return .text }
        let sample = Array(nonEmpty.prefix(50))

        if sample.allSatisfy({ Double($0) != nil }) { return .number }
        if sample.allSatisfy({ boolValues.contains($0.lowercased()) }) { return .boolean }
        if sample.allSatisfy({ datePattern.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }) { return .date }
        if sample.allSatisfy({ urlPattern.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }) { return .url }

        return .text
    }

    private static let boolValues: Set<String> = ["true", "false", "yes", "no", "1", "0", "t", "f"]
    // swiftlint:disable force_try
    private static let datePattern = try! NSRegularExpression(pattern: #"^\d{4}[-/]\d{1,2}[-/]\d{1,2}$|^\d{1,2}[-/]\d{1,2}[-/]\d{2,4}$"#)
    private static let urlPattern = try! NSRegularExpression(pattern: #"^https?://.+"#, options: .caseInsensitive)
    // swiftlint:enable force_try
}

struct ColumnStats {
    let total: Int
    let filled: Int
    let empty: Int
    let unique: Int
    let topValue: String
    let topCount: Int
    let type: ColumnType
    let min: Double?
    let max: Double?
    let sum: Double?
    let avg: Double?

    static func compute(values: [String]) -> ColumnStats {
        let type = ColumnType.infer(from: values)
        let nonEmpty = values.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let unique = Set(nonEmpty).count

        var freq: [String: Int] = [:]
        for v in nonEmpty { freq[v, default: 0] += 1 }
        let sorted = freq.sorted { $0.value > $1.value }

        var numMin: Double?, numMax: Double?, numSum: Double?, numAvg: Double?
        if type == .number {
            let nums = nonEmpty.compactMap { Double($0) }
            if !nums.isEmpty {
                numMin = nums.min()
                numMax = nums.max()
                numSum = nums.reduce(0, +)
                numAvg = numSum! / Double(nums.count)
            }
        }

        return ColumnStats(
            total: values.count,
            filled: nonEmpty.count,
            empty: values.count - nonEmpty.count,
            unique: unique,
            topValue: sorted.first?.key ?? "",
            topCount: sorted.first?.value ?? 0,
            type: type,
            min: numMin, max: numMax, sum: numSum, avg: numAvg
        )
    }
}
