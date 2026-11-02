// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The derived states the builds open now made or found - a conversion's - which the element being built holds,
/// as it holds its readings, while the source knows them weakly: one per use, gone with the element.
/// Design: docs/design/core/journeys.md#conversions
@MainActor
enum DerivationScope {
    /// One build's: what it made or found, and how many times each place was written in it so far.
    private struct Frame {
        var held: [AnyObject] = []
        var written: [DerivationKey: Int] = [:]
    }

    private static var stack: [Frame] = []

    /// The identities of the `ForEach` rows being built, outermost first.
    private static var rows: [AnyHashable] = []

    /// The key a conversion written at `site` keeps its derived state under: the element being built and the line,
    /// the rows of the `ForEach`s it stands in, and which time the line runs in this build - a helper called twice.
    static func key(_ site: PathNumber) -> DerivationKey {
        let place = (BuildScope.current?.element).map { site.under(PathNumber($0)) } ?? site
        var key = DerivationKey(site: place, rows: rows, occurrence: 0)
        guard !stack.isEmpty else { return key }

        key.occurrence = stack[stack.count - 1].written[key, default: 0]
        stack[stack.count - 1].written[DerivationKey(site: place, rows: rows, occurrence: 0)] = key.occurrence + 1
        return key
    }

    /// Builds a `ForEach` row's content under its identity, so a conversion written in it is the row's own.
    static func row<T>(_ identity: AnyHashable, _ build: () -> T) -> T {
        rows.append(identity)
        defer { rows.removeLast() }
        return build()
    }

    /// Hands a derived state to the element being built; false where none is being built.
    @discardableResult
    static func hold(_ derived: AnyObject) -> Bool {
        guard !stack.isEmpty else { return false }

        stack[stack.count - 1].held.append(derived)
        return true
    }

    /// Runs a build with a scope of its own, adding what it made to `held`.
    static func collect<T>(into held: inout [AnyObject], _ build: () -> T) -> T {
        stack.append(Frame())

        let value = build()

        held += stack.removeLast().held
        return value
    }
}

/// Where a conversion keeps its derived state: the element and the line it is written at, the identities of the
/// `ForEach` rows it stands in - values, compared as values - and which time the line ran in the build.
struct DerivationKey: Hashable {
    let site: PathNumber
    let rows: [AnyHashable]
    var occurrence: Int
}

/// A derived state as its source knows it: weakly where an element holds it, held here where it was made with no
/// element being built.
struct Derivation {
    private var held: AnyObject?
    private weak var known: AnyObject?

    init(_ state: AnyObject, heldHere: Bool) {
        known = state
        held = heldHere ? state : nil
    }

    /// The derived state, while anything holds it.
    var state: AnyObject? { held ?? known }
}
