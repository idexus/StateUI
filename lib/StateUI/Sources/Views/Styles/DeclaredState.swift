// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A visual state a control declares - its name and the values in force while the control is in it: data the
/// differ resolves, never crossing to a host.
/// Design: docs/design/views/styles.md#visual-states
struct DeclaredState: Equatable {
    let name: String
    var setters: [Prop: PropValue] = [:]
}

/// `states` with `state` written into them: over one of the same name, where that one stood, else after them - the
/// one place a list of states is arranged, for a style and a control alike.
/// Design: docs/design/views/styles.md#arranging-states
func written(_ states: [DeclaredState], adding state: DeclaredState) -> [DeclaredState] {
    var result = states

    if let at = result.firstIndex(where: { $0.name == state.name }) {
        result[at] = state
    } else {
        result.append(state)
    }

    return result
}

/// The states of a control that also has a style: the style's, with the control's written over them one setter at
/// a time, and a state the style never mentioned after them.
/// Design: docs/design/views/styles.md#states-on-a-control-over-its-style
func merged(_ base: [DeclaredState], with own: [DeclaredState]) -> [DeclaredState] {
    var result = base

    for state in own {
        if let at = result.firstIndex(where: { $0.name == state.name }) {
            result[at].setters.merge(state.setters) { _, mine in mine }
        } else {
            result.append(state)
        }
    }

    return result
}
