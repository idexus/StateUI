// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which state a control is in, and what it shows there: StateUI's own rules, one place.
/// Design: docs/design/views/styles.md#which-state-a-control-is-in
enum VisualStateRules {
    /// What the states follow: the control's values and what the user is doing to it.
    struct Facts: Equatable {
        var disabled = false
        var pressed = false
        var pointerOver = false
        var focused = false

        /// Whether it is on; nil for a control that is neither.
        var isOn: Bool?
    }

    /// The states in the order they come first: the first that holds is the control's state, and wins a value.
    static let precedence = [
        VisualStateName.disabled, VisualStateName.pressed, VisualStateName.pointerOver, VisualStateName.focused,
        VisualStateName.on, VisualStateName.checked, VisualStateName.off, VisualStateName.unchecked,
    ]

    /// The state a control is in when no other of its states holds, written or not.
    static let normal = VisualStateName.normal

    /// Whether the state named `name` holds for these facts; Normal is not asked.
    static func holds(_ state: KeyName, _ facts: Facts) -> Bool {
        switch state {
        case VisualStateName.disabled: facts.disabled
        case VisualStateName.pressed: facts.pressed
        case VisualStateName.pointerOver: facts.pointerOver
        case VisualStateName.focused: facts.focused
        case VisualStateName.on, VisualStateName.checked: facts.isOn == true
        case VisualStateName.off, VisualStateName.unchecked: facts.isOn == false
        default: false
        }
    }

    /// The declared states that hold, in precedence order.
    static func holding(_ states: [DeclaredState], facts: Facts) -> [KeyName] {
        precedence.filter { state in holds(state, facts) && states.contains { $0.key == state } }
    }

    /// `props` with the setters of every state that holds laid over them, the first in precedence winning a value;
    /// Normal's where none holds.
    static func resolved(_ props: [Prop: PropValue], states: [DeclaredState], holding: [KeyName]) -> [Prop: PropValue] {
        var result = props
        let shown = holding.isEmpty ? [normal] : holding

        for key in shown.reversed() {
            guard let state = states.first(where: { $0.key == key }) else { continue }
            result.merge(state.setters) { _, setter in setter }
        }

        return result
    }
}
