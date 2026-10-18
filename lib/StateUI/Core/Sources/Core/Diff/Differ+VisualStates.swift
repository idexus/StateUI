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

        guard let previous, previous != state else { return (state, []) }

        let heard = node.visualStateListeners.enumerated().filter { $0.element.hears(state) }
        return (state, heard.map { ($0.offset, $0.element) })
    }
}
