// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension StyleTarget {
    /// What changes while this control is in a state - the same thing a style
    /// says, said about one control.
    ///
    ///     Button("Save")
    ///         .visualState(.disabled) { $0.textColor(Palette.disabled) }
    ///
    /// A state written here is written over the state of the same name in the
    /// control's style, one setter at a time. Leaving the state gives the
    /// control its own values back, and where several states hold, the first of
    /// disabled, pressed, pointer-over, focused, on and off wins a value.
    ///
    /// - Parameters:
    ///   - state: which state these setters describe. What is offered after
    ///     the dot is the states this control actually enters.
    ///   - setters: the property values in force while the control is there.
    public func visualState(
        _ state: VisualState<Self>,
        _ setters: (StyleBag<Self, StyleState>) -> StyleBag<Self, StyleState>
    ) -> Modified {
        let values = setters(StyleBag<Self, StyleState>(key: nil)).node.props
        return declare(DeclaredState(key: state.key, setters: values))
    }

    /// A state of this control's that changes nothing - declared so the
    /// control can be heard entering it.
    ///
    ///     Button("Save")
    ///         .visualState(.normal)
    ///         .visualState(.pressed) { $0.opacity(0.6) }
    ///
    /// - Parameter state: the state, changing nothing.
    public func visualState(_ state: VisualState<Self>) -> Modified {
        declare(DeclaredState(key: state.key))
    }

    /// Runs when this control enters one of the named states - where a state
    /// can animate rather than only be set.
    ///
    ///     @State private var lift = 1.0
    ///
    ///     ZStack { Text("Open") }
    ///         .scale($lift)
    ///         .onVisualStateChanged(.pointerOver, .normal) { state in
    ///             $lift.journey.move(to: state == .pointerOver ? 1.03 : 1, .eased(.milliseconds(120), .cubicOut))
    ///         }
    ///
    /// It runs after the render in which the control entered the state, never
    /// for the state it arrives in. The states named are declared without
    /// changing how the control looks; naming none hears every state the
    /// control declares, and `.normal`.
    ///
    /// - Parameters:
    ///   - states: the states to hear; none hears every state.
    ///   - perform: what to run, given the state entered.
    public func onVisualStateChanged(
        _ states: VisualState<Self>...,
        perform handler: @escaping @MainActor (VisualState<Self>) throws -> Void
    ) -> Modified {
        listening(states, ValueHandler(step: { try handler(VisualState<Self>($0)) }))
    }

    /// The same, with a handler that awaits: its `policy` says what entering a
    /// state does while a run is under way.
    ///
    /// - Parameters:
    ///   - states: the states to hear; none hears every state.
    ///   - policy: what the handler passes through: what entering a state does while a run is under way.
    ///   - perform: what to run, given the state entered.
    public func onVisualStateChanged(
        _ states: VisualState<Self>...,
        policy: GatePolicy,
        perform handler: @escaping ValueEventHandler<VisualState<Self>>
    ) -> Modified {
        listening(states, ValueHandler(run: { try await handler(VisualState<Self>($0)) }, gate: .own(policy)))
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onVisualStateChanged(
        _ states: VisualState<Self>...,
        gate: Gate,
        perform handler: @escaping ValueEventHandler<VisualState<Self>>
    ) -> Modified {
        listening(states, ValueHandler(run: { try await handler(VisualState<Self>($0)) }, gate: .shared(gate)))
    }

    /// Declares `states` and hears the control entering them.
    private func listening(_ states: [VisualState<Self>], _ handler: ValueHandler<KeyName>) -> Modified {
        modified { node in
            for state in states where !node.visualStates.contains(where: { $0.key == state.key }) {
                node.visualStates.append(DeclaredState(key: state.key))
            }

            node.visualStateListeners.append(VisualStateListener(
                states: states.isEmpty ? nil : Set(states.map { $0.key }), handler: handler))
        }
    }

    /// Writes one state into the control's own list.
    /// Design: docs/design/views/styles.md#arranging-states
    private func declare(_ state: DeclaredState) -> Modified {
        modified { $0.visualStates = written($0.visualStates, adding: state) }
    }
}
