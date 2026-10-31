// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The value of a control's member a style is worn for - a button's role, a picker's presentation - over the style
/// every control of its type gets.
/// Design: docs/design/views/styles.md#a-style-for-a-variant
struct StyleVariant: Equatable {
    let target: NodeType
    let member: Prop
    let value: PropValue

    /// What a control saying none of the member holds - a picker is a menu; nil for none, as a button's role.
    let unsaid: PropValue?

    init<Owner: ElementContract, Value>(_ member: ElementProperty<Owner, Value>, _ value: Value, unsaid: Value? = nil) {
        target = Owner.nodeType
        self.member = member.token
        self.value = value.propValue
        self.unsaid = unsaid?.propValue
    }

    /// Whether `node` holds the value.
    func worn(by node: Node) -> Bool {
        node.type == target && (node.props[member] ?? unsaid) == value
    }
}
