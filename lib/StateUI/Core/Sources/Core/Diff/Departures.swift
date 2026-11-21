// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The views of an authored identity that left their holders declaring a transition, and the id a host knows
/// each by: what a view of the same identity written again under the same holder returns as.
/// Design: docs/design/core/identity-and-diffing.md#an-identity-that-comes-back
struct Departures {
    private struct Departed {
        let identity: ElementIdentity
        let knownAs: ElementID
    }

    /// What left each holder, the oldest first.
    private var departed: [ElementID: [Departed]] = [:]

    /// The id each element standing returns as, where it came back: what a render hands the host.
    private(set) var returned: [ElementID: ElementID] = [:]

    /// A child of `identity`, standing as `id`, left `holder`: it is known by the id it returned as, else its own.
    mutating func left(_ id: ElementID, of identity: ElementIdentity, from holder: ElementID) {
        var list = departed[holder, default: []]
        list.removeAll { $0.identity == identity }
        list.append(Departed(identity: identity, knownAs: returned[id] ?? id))
        if list.count > Transition.keptAtOnce { list.removeFirst(list.count - Transition.keptAtOnce) }
        departed[holder] = list
    }

    /// A child of `identity` is born under `holder` as `id`: it returns as the one of that identity that left it.
    mutating func born(_ id: ElementID, of identity: ElementIdentity, under holder: ElementID) {
        guard let index = departed[holder]?.firstIndex(where: { $0.identity == identity }) else { return }

        returned[id] = departed[holder]?.remove(at: index).knownAs
        if departed[holder]?.isEmpty == true { departed[holder] = nil }
    }

    /// `element` is forgotten: what left it, and what it returned as.
    mutating func forget(_ element: ElementID) {
        departed[element] = nil
        returned[element] = nil
    }
}
