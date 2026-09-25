// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension Differ {
    /// Lays the setters of the states that hold over the element's values, hears what the user does that they
    /// follow, and books `.onVisualStateChanged` where its state moved from `previous`; answers the state it is in.
    /// What is read here makes the element its reader, so a change describes the element again from its placeholder.
    /// Design: docs/design/views/styles.md#which-state-a-control-is-in
    func resolveVisualStates(
        _ node: inout Node,
        input: VisualInput,
        previous: String?,
        reads: inout Set<ObjectIdentifier>
    ) -> String {
        let names = Set(node.visualStates.map(\.name))

        // The Watch rule: only what a declared state follows is heard.
        if names.contains("Pressed") {
            node.addHandler(.pressed) { input.hold(true) }
            node.addHandler(.released) { input.hold(false) }
        }
        if names.contains("PointerOver") {
            node.addHandler(.pointerEntered) { input.hover(true) }
            node.addHandler(.pointerExited) { input.hover(false) }
        }
        if names.contains("Focused") {
            node.addHandler(.isFocusedChanged) {
                if let focused = EventBuffer.current.first?.bool { input.focus(focused) }
            }
        }

        let facts = ReadScope.collect(into: &reads) { [node] () -> VisualStateRules.Facts in
            let doing = input.read()
            let isOn = node.props[.isOn]?.bool ?? node.driven[.isOn]?.current.flatMap { Bool(carried: $0()) }
            return VisualStateRules.Facts(
                disabled: node.props[.isEnabled]?.bool == false, pressed: doing.pressed,
                pointerOver: doing.pointerOver, focused: doing.focused, isOn: isOn)
        }

        let holding = VisualStateRules.holding(node.visualStates, facts: facts)
        let state = holding.first ?? VisualStateRules.normal
        node.props = VisualStateRules.resolved(node.props, states: node.visualStates, holding: holding)

        // Heard after the render that entered it, never for the state the control arrives in.
        if let previous, previous != state {
            for listener in node.visualStateListeners where listener.hears(state) {
                fired.append { try await listener.run(state) }
            }
        }

        return state
    }
}
