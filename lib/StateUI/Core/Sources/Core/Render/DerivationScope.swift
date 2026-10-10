// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The derived states the builds open now made or found - a conversion's - which the element being built holds,
/// as it holds its readings, while the source knows them weakly: one per element and line, gone with the element.
/// Design: docs/design/core/journeys.md#conversions
@MainActor
enum DerivationScope {
    private static var stack: [[AnyObject]] = []

    /// The key a conversion written at `site` keeps its derived state under: the element being built, then the line.
    static func key(_ site: String) -> String {
        (BuildScope.current?.element).map { "\($0)#\(site)" } ?? site
    }

    /// Hands a derived state to the element being built; false where none is being built.
    @discardableResult
    static func hold(_ derived: AnyObject) -> Bool {
        guard !stack.isEmpty else { return false }

        stack[stack.count - 1].append(derived)
        return true
    }

    /// Runs a build with a scope of its own, adding what it made to `held`.
    static func collect<T>(into held: inout [AnyObject], _ build: () -> T) -> T {
        stack.append([])

        let value = build()

        held += stack.removeLast()
        return value
    }
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
