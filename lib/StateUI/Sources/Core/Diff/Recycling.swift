// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a subtree looks like with its values left out, so a host can hand a
// row's controls to the next row of the same shape.
// Design: docs/design/core/identity-and-diffing.md#recycling

/// Whether a subtree may be recycled, and what it looks like when it may.
enum Recycling {
    /// The controls whose whole state is in the tree - an inclusion list. Anything
    /// holding a caret, an offset, an open state or a surface of its own stays out.
    /// Design: docs/design/core/identity-and-diffing.md#recycling
    static let poolable: Set<NodeType> = [
        .activityIndicator, .border, .colorBox, .button,
        .checkBox, .ellipse, .spans, .grid,
        .hStack, .image, .positionIndicator, .label,
        .line, .path, .polygon, .polyline, .progressBar, .radioButton,
        .rectangle, .slider, .span, .stepper, .switch,
        .vStack, .zStack,
    ]

    /// Zero: the shape of a subtree that may not be recycled.
    static let none: UInt64 = 0

    /// What this rendered element and its subtree look like, or `none` where any part
    /// holds state the tree does not describe.
    static func shape(of node: RenderedNode) -> UInt64 {
        var value = seed
        return fold(node, into: &value) ? (value == none ? 1 : value) : none
    }

    /// Folds one element into the running number, keys sorted, and answers whether it
    /// may be recycled at all.
    private static func fold(_ node: RenderedNode, into value: inout UInt64) -> Bool {
        guard poolable.contains(node.type) else { return false }

        absorb(node.type.name, into: &value)

        for key in node.props.keys.sorted() {
            absorb(key.name, into: &value)
        }

        // A separator, so a property named like an event cannot read alike.
        absorb("", into: &value)

        for key in node.events.keys.sorted() {
            absorb(key.name, into: &value)
        }

        for child in node.children where !fold(child, into: &value) {
            return false
        }

        // And one at the end, so the same children one level deeper differ.
        absorb("", into: &value)
        return true
    }

    /// FNV-1a, written out: Swift's own hashing is seeded per process.
    private static func absorb(_ text: String, into value: inout UInt64) {
        for byte in text.utf8 {
            value ^= UInt64(byte)
            value = value &* prime
        }

        // Ends every piece, so "ab" then "c" cannot read as "a" then "bc".
        value ^= 0xff
        value = value &* prime
    }

    private static let seed: UInt64 = 0xcbf2_9ce4_8422_2325
    private static let prime: UInt64 = 0x0000_0100_0000_01b3
}
