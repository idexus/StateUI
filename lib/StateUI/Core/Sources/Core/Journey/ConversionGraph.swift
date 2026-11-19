// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The conversions whose derived states live elements wear: their destinations are worked out from their sources'
/// before a patch is prepared and in the display's cycle, sources first, each once.
/// Design: docs/design/core/journeys.md#the-graph-of-destinations
@MainActor
final class ConversionGraph {
    /// The conversions worn, by their order of declaration.
    private var worn: [Int: Conversion] = [:]

    /// A live element wears `conversion`'s derived state: the graph keeps it up to date from now on.
    func wear(_ conversion: Conversion) {
        conversion.wearers += 1
        worn[conversion.id] = conversion
    }

    /// An element let `conversion`'s derived state go; with its last wearer the graph lets it go too.
    func unwear(_ conversion: Conversion) {
        conversion.wearers -= 1
        if conversion.wearers <= 0 { worn[conversion.id] = nil }
    }

    /// Whether a source of any worn conversion has moved its destination since.
    var isStale: Bool { worn.values.contains(where: \.isStale) }

    /// How many conversions the graph keeps up to date - what a test of leaks counts.
    var count: Int { worn.count }

    /// Works out every derived destination a moved source reaches, in one pass: a conversion after every one it is
    /// worked out from, the rest in the order declared - so two branches of one source meet at their common result
    /// once, both moved. Answers how many were worked out.
    @discardableResult
    func settle() -> Int {
        guard isStale else { return 0 }

        var ordered: [Conversion] = []
        var placed = Set<ObjectIdentifier>()
        func place(_ conversion: Conversion) {
            guard placed.insert(ObjectIdentifier(conversion)).inserted else { return }

            conversion.upstream.sorted { $0.id < $1.id }.forEach(place)
            ordered.append(conversion)
        }
        for id in worn.keys.sorted() { worn[id].map(place) }

        // Each asked as its turn comes: one upstream publishing makes the next stale within the pass.
        var worked = 0
        for conversion in ordered where conversion.isStale {
            conversion.refresh(asking: true)
            worked += 1
        }
        return worked
    }

    /// Forgets every conversion - a fresh process's graph, for a test.
    func clear() {
        worn.removeAll()
    }
}
