// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The states of one target with `state` written into them: the one place a
/// list of states is arranged, for a style and a control alike.
/// Design: docs/design/views/styles.md#arranging-states
func visualStates(_ existing: [Node], adding state: Node, resting: String) -> [Node] {
    let group = state.visualStateGroup ?? ""
    let name = state.visualStateName ?? ""

    var result = existing

    if let written = result.firstIndex(where: {
        $0.visualStateGroup == group && $0.visualStateName == name
    }) {
        result[written] = state
    } else {
        result.append(state)
    }

    guard let first = result.firstIndex(where: { $0.visualStateGroup == group }) else {
        return result
    }

    guard let at = result.firstIndex(where: {
        $0.visualStateGroup == group && $0.visualStateName == resting
    }) else {
        result.insert(emptyVisualState(named: resting, in: group), at: first)

        return result
    }

    if at != first {
        result.insert(result.remove(at: at), at: first)
    }

    return result
}

/// Puts one state among a control's own, keeping them arranged and leaving
/// whatever the control lays out exactly where it was.
func write(_ state: Node, into node: inout Node, resting: String) {
    node.states = true

    let laid = node.children.filter { $0.type != .visualState }

    node.children = laid + visualStates(
        node.children.filter { $0.type == .visualState },
        adding: state,
        resting: resting)
}

/// A visual state named `name` in `group`, with no values of its own - how a
/// state a control only has to be able to enter is written.
func emptyVisualState(named name: String, in group: String) -> Node {
    var node = Node(contract: VisualStateContract.self)
    node.write(VisualStateContract.name, Name(name))
    node.write(VisualStateContract.group, Name(group))
    return node
}

/// A visual state with the values in force while the control is in it: its
/// setters, under the state's name and group.
func visualStateSetting(_ values: [Prop: PropValue], named name: String, in group: String) -> Node {
    var setters = Node(contract: SettersContract.self)
    setters.props = values

    var node = emptyVisualState(named: name, in: group)
    node.children = [setters]
    return node
}

extension Node {
    /// The group a visual state's node says it belongs to.
    var visualStateGroup: String? { props[VisualStateContract.group.token]?.name }

    /// The name a visual state's node carries.
    var visualStateName: String? { props[VisualStateContract.name.token]?.name }
}
