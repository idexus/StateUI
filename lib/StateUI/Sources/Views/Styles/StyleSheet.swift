// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The styles an application makes available.
///
/// Written into the application's session, so they apply to the whole
/// application:
///
///     application.styles = StyleSheet {
///         Style<Label>().textColor(AppColors.text)
///         Style<Button>("Danger").background(.firebrick)
///     }
///
/// Writing a new sheet restyles every control.
public struct StyleSheet {
    /// Every style, in writing order, each with what it is based on already
    /// under it - the one storage the two maps below point into.
    var written: [AnyStyle] = []

    /// Where the one every control of a type gets is.
    private var implicit: [NodeType: Int] = [:]

    /// Where the ones asked for by name are.
    private var keyed: [String: Int] = [:]

    /// The styles the closure describes, with every `basedOn` chain flattened.
    ///
    /// Two styles under one key, or two implicit ones for one target, are one:
    /// the LAST wins, as a second assignment to one dictionary key does.
    public init(@StyleBuilder _ content: () -> [AnyStyle]) {
        written = content()

        for (index, style) in written.enumerated() {
            if let key = style.key {
                keyed[key] = index
            } else {
                implicit[style.target] = index
            }
        }

        // Against what was written, so a style may start from one below it.
        let unflattened = written

        for index in written.indices {
            written[index] = StyleSheet.flatten(written[index], from: unflattened, keyed: keyed)
        }
    }

    /// One style with everything it is based on already under it; `chain`
    /// stops a cycle where it began.
    private static func flatten(
        _ style: AnyStyle,
        from written: [AnyStyle],
        keyed: [String: Int],
        chain: Set<String> = []
    ) -> AnyStyle {
        guard let key = style.basedOn, !chain.contains(key), let at = keyed[key] else {
            return style
        }

        let base = StyleSheet.flatten(
            written[at], from: written, keyed: keyed, chain: chain.union([key]))

        var result = style
        result.props = base.props.merging(style.props) { _, mine in mine }
        result.states = merged(base.states, with: style.states)

        return result
    }

    /// The style a node wears: the keyed one it asks for where that is for its
    /// type, or else the one every control of its type gets.
    func style(for node: Node) -> AnyStyle? {
        if let key = node.props[VisualElementContract.style.token]?.name, let at = keyed[key],
           written[at].target == node.type {
            return written[at]
        }

        return implicit[node.type].map { written[$0] }
    }

    /// Whether two sheets say the same thing - read once per render, to decide
    /// whether a composed view may still be carried.
    static func same(_ one: StyleSheet?, _ other: StyleSheet?) -> Bool {
        switch (one, other) {
        case (nil, nil): return true
        case (let one?, let other?): return same(one.written, other.written)
        default: return false
        }
    }

    private static func same(_ one: [AnyStyle], _ other: [AnyStyle]) -> Bool {
        one.count == other.count && zip(one, other).allSatisfy { mine, theirs in
            mine.target == theirs.target
                && mine.key == theirs.key
                && mine.props == theirs.props
                && mine.states == theirs.states
        }
    }
}

/// The node as the host will see it: its style's values under its own, and
/// the states of both - the one place a style is applied.
/// Design: docs/design/views/styles.md#applying-a-style
func styled(_ node: Node, with sheet: StyleSheet?) -> Node {
    let style = sheet?.style(for: node)

    // Asked first: assigning nil to a missing key still copies the storage.
    guard style != nil || node.props[VisualElementContract.style.token] != nil else { return node }

    var node = node
    node.props[VisualElementContract.style.token] = nil

    guard let style = style else { return node }

    // The control's own values win, one property at a time.
    if !style.props.isEmpty {
        node.props = style.props.merging(node.props) { _, own in own }
    }

    if !style.states.isEmpty {
        node.visualStates = merged(style.states, with: node.visualStates)
    }

    return node
}
