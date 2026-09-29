// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the host told the core it realizes - nothing until it says.
enum HostRealizations {
    /// The realization, behind the lock: the host says it once at start-up,
    /// and an application may ask from any thread.
    nonisolated(unsafe) private static var told = HostRealization()

    /// The lock.
    private static let guarded = Lock()

    /// What the host said, replacing what it said before.
    static var current: HostRealization {
        get { guarded.withLock { told } }
        set { guarded.withLock { told = newValue } }
    }

    /// What to say about a node type described for the first time: nothing where the
    /// host realizes it or has said nothing, and otherwise that it does not, with the
    /// nearest realized names.
    /// Design: docs/design/core/contracts.md#unrealized-names
    static func unrealized(_ type: NodeType) -> String? {
        let realization = current

        guard realization != HostRealization(), type != .composed,
              !realization.elements.contains(type.name)
        else { return nil }

        return "the host realizes no `\(type.name)`" + nearMisses(type.name, among: realization.elements) + "."
    }

    /// What to say about an event of the application's a handler listens for:
    /// nothing where the host raises it, or has said nothing at all, and
    /// otherwise that it does not - with the events it raises nearest in name.
    static func unraised(owner: String, event: String) -> String? {
        let realization = current

        guard realization != HostRealization(),
              !realization.members.contains(where: { $0.owner == owner && $0.member == event })
        else { return nil }

        let raised = Set(realization.members.filter { $0.element == ApplicationContract.name }.map(\.member))

        return "the host raises no `\(event)`" + nearMisses(event, among: raised) + ": the handler will not hear it."
    }

    /// " (nearest: `a`, `b`)" - the names at most a quarter of the name's
    /// length away, two edits at least, closest first, three at most - or
    /// nothing.
    private static func nearMisses(_ name: String, among names: Set<String>) -> String {
        let reach = max(2, name.count / 4)
        let near = names
            .map { (name: $0, edits: edits(from: name, to: $0)) }
            .filter { $0.edits <= reach }
            .sorted { ($0.edits, $0.name) < ($1.edits, $1.name) }
            .prefix(3)
            .map { "`\($0.name)`" }

        return near.isEmpty ? "" : " (nearest: " + near.joined(separator: ", ") + ")"
    }

    /// How many single-character edits turn one name into the other.
    private static func edits(from source: String, to target: String) -> Int {
        let from = Array(source)
        let to = Array(target)

        guard !from.isEmpty else { return to.count }
        guard !to.isEmpty else { return from.count }

        var row = Array(0...to.count)

        for i in 1...from.count {
            var diagonal = row[0]
            row[0] = i

            for j in 1...to.count {
                let above = row[j]
                row[j] = Swift.min(above + 1, row[j - 1] + 1, diagonal + (from[i - 1] == to[j - 1] ? 0 : 1))
                diagonal = above
            }
        }

        return row[to.count]
    }
}
