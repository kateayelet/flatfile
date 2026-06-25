//
//  FlatFileSidecar.swift
//  FlatFile
//
//  An optional, transparent companion to a `.csv`: `<name>.flatfile` (JSON) in
//  the same folder. It remembers per-file preferences — friendlier column
//  display names, an intended/advisory column type, a format hint, and the last
//  sort — so the user doesn't re-set them every open.
//
//  Rules (do not violate):
//  - The `.csv` is always the source of truth. The sidecar never changes a single
//    byte of it; every cell stays exactly as written, everything stays a String.
//  - Entirely optional. If it's missing or unreadable, the `.csv` opens clean.
//  - Transparent, not a database: plain JSON, keyed by the visible header text.
//

import Foundation

/// Per-file, non-authoritative metadata persisted next to a `.csv`.
struct FlatFileSidecar: Codable, Equatable {
    /// Schema version, so a future format change can migrate (or ignore) old files.
    var version: Int
    /// Column preferences, keyed by the `.csv` header text they apply to.
    var columns: [Column]
    /// The sort to restore on open, keyed by header text.
    var sort: Sort?

    init(version: Int = FlatFileSidecar.currentVersion, columns: [Column] = [], sort: Sort? = nil) {
        self.version = version
        self.columns = columns
        self.sort = sort
    }

    static let currentVersion = 1

    struct Column: Codable, Equatable {
        /// The `.csv` header this entry maps to. Header text is the key, so the
        /// sidecar survives column reordering and tolerates added/removed columns.
        var header: String
        /// An optional friendlier label to show instead of the raw header.
        var displayName: String?
        /// Intended column type (a `ColumnType` rawValue). Advisory only — it
        /// affects how the column is presented, never how the data is stored.
        var type: String?
        /// A freeform format hint (e.g. "USD", "YYYY-MM-DD"). Advisory only.
        var format: String?

        init(header: String, displayName: String? = nil, type: String? = nil, format: String? = nil) {
            self.header = header
            self.displayName = displayName
            self.type = type
            self.format = format
        }

        /// A column entry with no preferences carries no information and is pruned.
        var isEmpty: Bool {
            isBlank(displayName) && isBlank(type) && isBlank(format)
        }

        private func isBlank(_ s: String?) -> Bool {
            (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    struct Sort: Codable, Equatable {
        /// The header text of the sorted column.
        var column: String
        var ascending: Bool
    }

    /// Nothing worth persisting — used to decide whether to delete the file
    /// rather than leave an empty one littering the folder.
    var isEmpty: Bool {
        columns.allSatisfy(\.isEmpty) && sort == nil
    }

    // MARK: - Read helpers

    func column(for header: String) -> Column? {
        columns.first { $0.header == header }
    }

    /// The label to show for a column: its display name if set, else the header.
    func displayName(for header: String) -> String {
        let name = column(for: header)?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (name?.isEmpty == false) ? name! : header
    }

    /// The intended type for a column, if one was set and is still a valid type.
    func intendedType(for header: String) -> ColumnType? {
        guard let raw = column(for: header)?.type else { return nil }
        return ColumnType(rawValue: raw)
    }

    // MARK: - Mutation helpers (each prunes entries that become empty)

    mutating func setDisplayName(_ name: String?, for header: String) {
        let value = Self.normalized(name)
        update(header) { $0.displayName = value }
    }

    mutating func setType(_ type: ColumnType?, for header: String) {
        update(header) { $0.type = type?.rawValue }
    }

    mutating func setFormat(_ format: String?, for header: String) {
        let value = Self.normalized(format)
        update(header) { $0.format = value }
    }

    /// Follow a header rename so the column's prefs (and any sort on it) stay
    /// attached. Returns whether anything actually moved, so callers can avoid a
    /// needless write. Header text is the key, so this must run when the in-app
    /// header editor changes a name — otherwise `pruneColumns` would drop it.
    @discardableResult
    mutating func renameHeader(from old: String, to new: String) -> Bool {
        guard old != new else { return false }
        var changed = false
        for index in columns.indices where columns[index].header == old {
            columns[index].header = new
            changed = true
        }
        if sort?.column == old {
            sort?.column = new
            changed = true
        }
        return changed
    }

    /// Drop any preferences whose column no longer exists in the file, so a
    /// header rename or column removal doesn't leave stale entries behind.
    mutating func pruneColumns(keepingHeaders headers: [String]) {
        let live = Set(headers)
        columns.removeAll { !live.contains($0.header) || $0.isEmpty }
        if let s = sort, !live.contains(s.column) { sort = nil }
    }

    private mutating func update(_ header: String, _ mutate: (inout Column) -> Void) {
        if let index = columns.firstIndex(where: { $0.header == header }) {
            mutate(&columns[index])
            if columns[index].isEmpty { columns.remove(at: index) }
        } else {
            var column = Column(header: header)
            mutate(&column)
            if !column.isEmpty { columns.append(column) }
        }
    }

    private static func normalized(_ s: String?) -> String? {
        let trimmed = s?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed : nil
    }
}
