// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a subtree LOOKS like, with every value taken out of it.
//
// A list scrolling by one row costs the platform four controls built and four
// thrown away, and that is the whole of what makes a scroll judder - measured
// on Mac Catalyst, where the message for the same row is a fifth of a
// millisecond and the apply is four. The row leaving and the row arriving are
// usually the SAME SHAPE, so the control that left could stand in for the one
// arriving; what stops a renderer from simply doing that is that it cannot
// know the two are alike.
//
// This is how it knows. A shape is a number over the subtree's TYPES, PROPERTY
// KEYS and EVENT KEYS, recursively, with the values left out - so two rows
// share a shape exactly when they name the same properties on the same
// controls in the same places. A control adopted under a matching shape is
// then given a value for every property it already carries, which is what
// makes the adoption safe: there is nothing left over to clear, and nothing
// the arriving row names that the leaving row did not.
//
// A conditional property splits the shape in two - a row that writes
// `.textColor` only when it is chosen has one shape chosen and another not -
// and that is correct rather than cheap: those two rows are NOT
// interchangeable. A list has one to three shapes in practice.

/// Whether a subtree may be recycled, and what it looks like when it may.
enum Recycling {
    /// The controls whose whole state is in the tree, so a value for every
    /// property they name is a complete description of them.
    ///
    /// An INCLUSION list, and that is the load-bearing part: a control an
    /// application registered, a page, and every type added to this library
    /// later are all outside it until somebody puts them in deliberately. What
    /// is kept out and why:
    ///
    /// - `Entry`, `Editor`, `SearchBar`, `Picker`, `DatePicker`, `TimePicker` -
    ///   the caret, the selection, which of them the platform is typing into,
    ///   and whether a list is open. None of it is a property, so none of it is
    ///   in the shape.
    /// - `ScrollView` - its own offset, which nothing describes.
    /// - `SwipeView` - open or closed, which nothing describes either, so an
    ///   adopted row could arrive with its actions already showing.
    /// - `RefreshView` - the spinner the platform is running.
    /// - `WebView`, `Map` - a whole browser and a whole map, each with a
    ///   history and a region of its own.
    /// - `GraphicsView` - the drawing is a property, the surface it is cached
    ///   on is not.
    static let poolable: Set<NodeType> = [
        .absoluteLayout, .activityIndicator, .border, .boxView, .button,
        .checkBox, .ellipse, .flexLayout, .formattedString, .grid,
        .horizontalStackLayout, .image, .imageButton, .indicatorView, .label,
        .line, .path, .polygon, .polyline, .progressBar, .radioButton,
        .rectangle, .roundRectangle, .slider, .span, .stepper, .switch,
        .verticalStackLayout,
    ]

    /// The two events a pooled control cannot answer honestly.
    ///
    /// Both are about the control's PRESENCE in the tree, and a control kept
    /// for the next row never leaves it: the row that arrives is handed a
    /// control that was already loaded, so nothing would fire. Rather than
    /// answer a question with silence, a row that asks it is left out of the
    /// pool and built as it always was.
    static let presence: Set<Event> = [.loaded, .unloaded]

    /// Zero, which is the shape of a subtree that may NOT be recycled - so the
    /// wire carries one number rather than a number and a flag, and a host
    /// that reads zero pools nothing.
    static let none: UInt64 = 0

    /// What this element and everything under it looks like, or `none` when
    /// any part of it holds state the tree does not describe.
    ///
    /// Read off the RENDERED element rather than the node, because that is
    /// what the differ has once a subtree is settled: the same types, the same
    /// complete property map, and the same events, whoever wrote them - a
    /// style's properties included, since a style is resolved before this.
    static func shape(of node: RenderedNode) -> UInt64 {
        var value = seed
        return fold(node, into: &value) ? (value == none ? 1 : value) : none
    }

    /// Folds one element into the running number, and says whether it may be
    /// recycled at all.
    ///
    /// SORTED keys, both maps, for the reason everything else this side writes
    /// is sorted: Swift salts each dictionary with its own storage address, so
    /// an unsorted walk gives two instances of one row two different numbers
    /// inside a single run - and the pool would then never match anything.
    private static func fold(_ node: RenderedNode, into value: inout UInt64) -> Bool {
        guard poolable.contains(node.type) else { return false }

        absorb(node.type.name, into: &value)

        for key in node.props.keys.sorted() {
            absorb(key.name, into: &value)
        }

        // A separator between the two maps, so a property named like an event
        // cannot make two different elements read alike.
        absorb("", into: &value)

        for key in node.events.keys.sorted() {
            if presence.contains(key) { return false }
            absorb(key.name, into: &value)
        }

        for child in node.children where !fold(child, into: &value) {
            return false
        }

        // And one at the end, so the same children one level deeper are a
        // different number.
        absorb("", into: &value)
        return true
    }

    /// FNV-1a, written out here rather than taken from Swift's own hashing,
    /// which is seeded per process: two runs of one interface must number a
    /// shape the same way for a fixture to be worth reading, and two INSTANCES
    /// inside one run must, or nothing would ever be adopted.
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
