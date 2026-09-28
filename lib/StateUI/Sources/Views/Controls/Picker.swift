// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Picker`'s own properties, shared by the control and its `Style<Picker>`.
public protocol PickerProperties: PropertyContainer {}

extension PickerProperties {
    /// Shows or dismisses the list of choices. The user may still close it by
    /// choosing, clicking away or pressing Escape, which `onClosed` reports.
    public func isOpen(_ value: Bool) -> Modified {
        setValue(PickerContract.isOpen, value)
    }

    /// The captions to choose from, in order. Choosing among models, format
    /// them here and find the chosen one by its index.
    public func options(_ value: [String]) -> Modified {
        setValue(PickerContract.options, value)
    }

    /// Which item is chosen, counted from zero; -1 for none.
    public func selectedIndex(_ value: Int) -> Modified {
        setValue(PickerContract.selectedIndex, value)
    }

    /// What the field says while nothing is chosen. A host can also reuse it
    /// as the heading of a separate native choice surface.
    public func title(_ value: String) -> Modified {
        setValue(PickerContract.title, value)
    }
}

/// One choice out of a list.
///
///     private let sizes = ["Small", "Medium", "Large"]
///     @State private var size = 1
///
///     Picker(sizes)
///         .selectedIndex($size)
///         .title("Size")
///
/// The choice comes back through the binding as an index into the list, `-1`
/// while nothing is chosen; `sizes[size]` turns it back into a value, which is
/// why the list is worth holding. The picker takes `.textColor` but has no
/// `.text`: the field shows the chosen item or the title.
public struct Picker: View, TextStyleElement, FontElement, TextAlignmentElement, TintElement,
    PickerProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Picker>` is written against.
    public init() {
        node = Node(contract: PickerContract.self)
    }

    /// A picker offering `items`, with nothing chosen until `.selectedIndex`
    /// says so.
    public init(_ items: [String]) {
        node = Node(contract: PickerContract.self)
        node.write(PickerContract.options, items)
    }

    // MARK: Properties

    // Design: docs/design/views/bindings.md#two-way-controls
    /// Two-way: shows the choice the state holds and writes back the one the
    /// user makes, with no view rebuilt for it.
    ///
    /// - Parameter binding: the state shown, and written back into as the
    ///   user chooses.
    /// - Returns: the picker, wearing and reporting that choice.
    public func selectedIndex(_ binding: Binding<Int>) -> Self {
        binding.image == nil
            ? described(.selectedIndex, binding, on: .selectedIndexChanged)
            : plain(.selectedIndex, by: binding, mode: .inOut)
    }

    // MARK: Events

    /// Fires when the user changes the choice, with the new index - after the
    /// choice has landed on a state handed as `$size`.
    public func onSelectedIndexChanged(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        onEvent(PickerContract.selectedIndexChanged, handler)
    }

    /// The user has opened the list of choices. Opening it with `isOpen(true)`
    /// raises nothing: the application already knows.
    public func onOpened(_ handler: @escaping EventHandler) -> Self {
        onEvent(PickerContract.opened, handler)
    }

    /// The user has closed it - by a choice, a click outside or the platform's
    /// own dismissal.
    public func onClosed(_ handler: @escaping EventHandler) -> Self {
        onEvent(PickerContract.closed, handler)
    }
}
