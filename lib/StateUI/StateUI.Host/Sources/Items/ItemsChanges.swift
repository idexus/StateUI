// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What turns one list of identities into another, for a collection told its changes one by one: the positions
/// removed from the old list, last first, then the positions inserted into the new, first first. An identity in
/// both that moved against the others is removed and inserted; one that kept its place is neither.
/// Design: docs/design/host/items.md#changes-one-by-one
@_spi(Host) public struct ItemsChanges: Equatable, Sendable {
    /// Positions in the old list, last first - the order to remove them in.
    public let removed: [Int]

    /// Positions in the new list, first first - the order to insert them in.
    public let inserted: [Int]

    /// Whether nothing changes.
    public var isEmpty: Bool { removed.isEmpty && inserted.isEmpty }

    /// The removals as runs of neighbours, last first: each run is removed in one.
    public var removedRuns: [Range<Int>] {
        Self.runs(of: removed.reversed()).reversed()
    }

    /// The insertions as runs of neighbours, first first: each run is inserted in one.
    public var insertedRuns: [Range<Int>] {
        Self.runs(of: inserted)
    }

    /// The changes from `old` to `new`.
    public init(from old: [String], to new: [String]) {
        let newPositions = Dictionary(new.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

        // The identities in both, in the old order, each with its new place: the longest run whose new places
        // rise keeps its place, and every other one moved.
        let kept = old.enumerated().compactMap { position, identity in
            newPositions[identity].map { (old: position, new: $0) }
        }
        let staying = Set(Self.longestRising(kept.map(\.new)).map { kept[$0].old })

        removed = old.indices.filter { !staying.contains($0) }.reversed()
        let stayingNew = Set(staying.map { newPositions[old[$0]]! })
        inserted = new.indices.filter { !stayingNew.contains($0) }
    }

    /// Rising `positions` as runs of neighbours, in order.
    private static func runs(of positions: some Sequence<Int>) -> [Range<Int>] {
        var runs: [Range<Int>] = []
        for position in positions {
            if let last = runs.last, last.upperBound == position {
                runs[runs.count - 1] = last.lowerBound..<position + 1
            } else {
                runs.append(position..<position + 1)
            }
        }
        return runs
    }

    /// The indices of a longest strictly rising run of `values`, in order.
    private static func longestRising(_ values: [Int]) -> [Int] {
        var tails: [Int] = []
        var previous = [Int](repeating: -1, count: values.count)
        for (index, value) in values.enumerated() {
            var low = 0
            var high = tails.count
            while low < high {
                let middle = (low + high) / 2
                if values[tails[middle]] < value { low = middle + 1 } else { high = middle }
            }
            if low > 0 { previous[index] = tails[low - 1] }
            if low == tails.count { tails.append(index) } else { tails[low] = index }
        }
        var run: [Int] = []
        var index = tails.last ?? -1
        while index >= 0 {
            run.append(index)
            index = previous[index]
        }
        return run.reversed()
    }
}
