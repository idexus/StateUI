// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Differ {
    /// Lays the setters of the states that hold over the element's values and hears what the user does that they
    /// follow; answers the state it is in, and the `.onVisualStateChanged` listeners that hear it where its state
    /// moved from `previous`.
    /// What is read here makes the element its reader, so a change describes the element again from its placeholder.
    /// Design: docs/design/views/styles.md#which-state-a-control-is-in
    func resolveVisualStates(
        _ node: inout Node,
        input: VisualInput,
        previous: KeyName?,
        reads: inout Set<ObjectIdentifier>
    ) -> (state: KeyName, heard: [(index: Int, listener: VisualStateListener)]) {
        let declared = Set(node.visualStates.map { $0.key })

        // Only what a declared state follows is heard.
        if declared.contains(VisualStateName.pressed) {
            node.addHandler(.pressed) { input.hold(true) }
            node.addHandler(.released) { input.hold(false) }
        }
        if declared.contains(VisualStateName.pointerOver) {
            node.addHandler(.pointerEntered) { input.hover(true) }
            node.addHandler(.pointerExited) { input.hover(false) }
        }
        if declared.contains(VisualStateName.focused) {
            node.addHandler(.isFocusedChanged) {
                if let focused = EventBuffer.current.first?.bool { input.focus(focused) }
            }
        }

        // A fact is read as the host shows it - a bound state's value first - and only where a declared state
        // follows it, so a control with none reads nothing of a state bound to it.
        let follows = (
            enablement: declared.contains(VisualStateName.disabled),
            isOn: declared.contains(VisualStateName.on) || declared.contains(VisualStateName.off))
        let facts = ReadScope.collect(into: &reads) { [node, enablements] () -> VisualStateRules.Facts in
            let doing = input.read()
            let disabled = follows.enablement
                && (Enablement(node)?.isEnabled() == false || enablements.contains { !$0.isEnabled() })
            return VisualStateRules.Facts(
                disabled: disabled, pressed: doing.pressed, pointerOver: doing.pointerOver, focused: doing.focused,
                isOn: follows.isOn ? Enablement.shown(.isOn, of: node) : nil)
        }

        let holding = VisualStateRules.holding(node.visualStates, facts: facts)
        let state = holding.first ?? VisualStateRules.normal
        node.props = VisualStateRules.resolved(node.props, states: node.visualStates, holding: holding)

        guard let previous, previous != state else { return (state, []) }

        let heard = node.visualStateListeners.enumerated().filter { $0.element.hears(state) }
        return (state, heard.map { ($0.offset, $0.element) })
    }
}

/// What an element says of its enablement, as the host shows it: the state it binds it to while that state is
/// carried both ways, else the value stated on it - by itself, or a style.
/// Design: docs/design/views/styles.md#which-state-a-control-is-in
@MainActor
struct Enablement {
    private let stated: Bool?
    private let bound: StateRegistration?

    /// What `node` says; nil where it says nothing of its enablement.
    init?(_ node: Node) {
        stated = node.props[.isEnabled]?.bool
        bound = node.driven[.isEnabled].flatMap { $0.mode == .in ? nil : $0 }
        if stated == nil, bound == nil { return nil }
    }

    /// Whether the user's hand reaches it by what it says - reading a bound state, which makes the element asking
    /// its reader.
    func isEnabled() -> Bool {
        bound?.current.flatMap { Bool(carried: $0()) } ?? stated ?? true
    }

    /// What a view carried whole compares of it: disabled by a stated value, or the state it is bound to - a branch
    /// turned so, or bound to another state, describes the views in it again; a bound state's writes reach its
    /// readers by their reads.
    enum Key: Hashable {
        case statedOff
        case bound(ObjectIdentifier)
    }

    /// Its key; nil where it says it is enabled with no state bound, which changes nothing in it.
    var key: Key? {
        if let bound { return .bound(ObjectIdentifier(bound.state)) }
        return stated == false ? .statedOff : nil
    }

    /// `property` of `node` as the host shows it: the bound state's value while it is carried both ways, else the
    /// stated one.
    static func shown(_ property: Prop, of node: Node) -> Bool? {
        if let binding = node.driven[property], binding.mode != .in,
           let value = binding.current.flatMap({ Bool(carried: $0()) }) {
            return value
        }
        return node.props[property]?.bool
    }
}

