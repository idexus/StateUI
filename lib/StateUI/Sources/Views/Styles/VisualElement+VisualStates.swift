// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension VisualElement where Self: StyleTarget {
    /// What changes while this control is in a state - the same thing a style
    /// says, said about one control.
    ///
    ///     Button("Save")
    ///         .visualState(.disabled) { $0.textColor(Palette.disabled) }
    ///
    /// A state written here is written over the state of the same name in the
    /// control's style, one setter at a time.
    ///
    /// - Parameters:
    ///   - state: which state these setters describe. What is offered after
    ///     the dot is the states this control actually enters.
    ///   - group: which group of states the state belongs to. A control is in
    ///     one state per group and leaves a state only by entering another in
    ///     the SAME group, so states that exclude one another belong together.
    ///     Every group has a name and nearly everything is in `CommonStates`,
    ///     so that is the default.
    ///   - setters: the property values in force while the control is there.
    public func visualState(
        _ state: VisualState<Self>,
        group: String = "CommonStates",
        _ setters: (StyleBag<Self, StyleState>) -> StyleBag<Self, StyleState>
    ) -> Modified {
        visualState(visualStateSetting(
            setters(StyleBag<Self, StyleState>(key: nil)).node.props, named: state.name, in: group))
    }

    /// A state of this control's that changes nothing, which is how it gets back
    /// to it.
    ///
    ///     Button("Save")
    ///         .visualState(.normal)
    ///         .visualState(.pressed) { $0.opacity(0.6) }
    ///
    /// Worth writing where it says something - and not required, since a group
    /// that wrote none is given its control's resting state anyway.
    ///
    /// - Parameters:
    ///   - state: the state the control returns to, changing nothing.
    ///   - group: which group of states it belongs to, `CommonStates` unless
    ///     said otherwise.
    public func visualState(
        _ state: VisualState<Self>,
        group: String = "CommonStates"
    ) -> Modified {
        visualState(emptyVisualState(named: state.name, in: group))
    }

    /// Runs when this control enters one of the named states - where a state
    /// can animate rather than only be set.
    ///
    ///     @State private var lift = 1.0
    ///
    ///     ZStack { Label("Open") }
    ///         .scale($lift)
    ///         .onVisualStateChanged(.pointerOver, .normal) { state in
    ///             try await $lift.journey.move(to: state == .pointerOver ? 1.03 : 1, .eased(120, .cubicOut))
    ///         }
    ///
    /// A control reports only the states it declares, so the states named here
    /// are declared in `CommonStates`, merged with its style's without changing
    /// how it looks. Name only the states it should react to: declaring a
    /// state can change which one it rests in.
    ///
    /// - Parameter perform: what to run, given the state entered.
    public func onVisualStateChanged(
        _ states: VisualState<Self>...,
        perform handler: @escaping ValueEventHandler<VisualState<Self>>
    ) -> Modified {
        modified { node in
            for state in states {
                let already = node.children.contains {
                    $0.type == VisualStateContract.nodeType
                        && $0.visualStateName == state.name
                        && $0.visualStateGroup == "CommonStates"
                }

                guard !already else { continue }

                write(
                    emptyVisualState(named: state.name, in: "CommonStates"),
                    into: &node,
                    resting: Self.restingVisualState.name)
            }

            node.addHandler(VisualElementContract.visualStateChanged.token) {
                // The state's name, as text: an event payload carries no names.
                if let name = EventBuffer.current.value()?.string {
                    try await handler(VisualState<Self>(name))
                }
            }
        }
    }

    /// Writes one state into the control's own list, as children after what
    /// the control lays out.
    /// Design: docs/design/views/styles.md#visual-states
    private func visualState(_ written: Node) -> Modified {
        modified { write(written, into: &$0, resting: Self.restingVisualState.name) }
    }
}
