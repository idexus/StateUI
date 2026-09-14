// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Picker's own properties - the half a `Style<Picker>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol PickerProperties: PropertyContainer {}

extension PickerProperties {
    /// Asks the host to show or dismiss the list of choices.
    ///
    /// This is a presentation request, not another selection state. A reader
    /// can still close the native list by choosing, clicking away or pressing
    /// Escape; `onClosed` reports that reader-driven boundary.
    public func isOpen(_ value: Bool) -> Modified {
        setValue(.isOpen, .bool(value))
    }

    /// The list to choose from, in the order it is offered.
    ///
    /// The host boundary carries captions rather than application objects, so
    /// an application choosing among models formats them here and resolves the
    /// chosen model through its index.
    public func options(_ value: [String]) -> Modified {
        setValue(.options, .strings(value))
    }

    /// Which item is chosen, counted from zero; -1 for none.
    public func selectedIndex(_ value: Int) -> Modified {
        setValue(.selectedIndex, .number(Double(value)))
    }

    /// What the field says while nothing is chosen. A host can also reuse it
    /// as the heading of a separate native choice surface.
    public func title(_ value: String) -> Modified {
        setValue(.title, .string(value))
    }

    /// The colour of that `title`.
    ///
    /// Not the colour of the chosen item - `.textColor` is that one, from
    /// `TextStyleElement`.
    public func titleColor(_ value: Color) -> Modified {
        setValue(.titleColor, value.propValue)
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
/// The list is the initializer argument because it is what a Picker is for.
/// Which one is chosen is a binding, so the choice comes back without a
/// handler - as an INDEX into the list, and `-1` while nothing is chosen.
/// Turning that index back into a value is the author's own `sizes[size]`,
/// which is why the list is worth holding rather than writing inline.
///
/// `TextStyleElement` rather than `TextElement`: the field displays either a
/// chosen item or its title, so there is no independent `.text()` value.
public struct Picker: View, TextStyleElement, FontElement, TextAlignmentElement, PickerProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Picker>` is written against.
    public init() {
        node = Node(type: .picker)
    }

    /// A picker offering `items`, with nothing chosen until `.selectedIndex`
    /// says so.
    public init(_ items: [String]) {
        node = Node(type: .picker, props: [.options: .strings(items)])
    }

    // MARK: Properties

    /// Two-way: shows the choice the state holds and writes back the one
    /// made - and HANDED OVER, so the picker is no reader of the state; a part
    /// of a state or a binding made from closures is shown by the tree
    /// instead.
    ///
    /// - Parameter binding: the state shown, and written back into as the
    ///   reader chooses.
    /// - Returns: the picker, wearing and reporting that choice.
    public func selectedIndex(_ binding: Binding<Int>) -> Self {
        binding.image == nil
            ? described(.selectedIndex, binding, on: .selectedIndexChanged)
            : plain(.selectedIndex, by: binding, mode: .inOut)
    }

    // MARK: Events

    /// Fires when the reader changes the choice, with the new index.
    ///
    /// Runs after the choice has landed on a state handed as `$size`, wherever
    /// `.selectedIndex($:)` is written in the chain. Over a part of a state or
    /// a binding made from closures it runs in WRITING order instead: written
    /// after the binding it sees the state already updated, written before it
    /// the state still holds the old index. The payload carries the new one
    /// either way.
    public func onSelectedIndexChanged(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        addHandler(.selectedIndexChanged) {
            // A payload that will not parse leaves the handler alone, the rule
            // every gesture follows. -1 is a real value here - nothing chosen -
            // so it cannot double as "unreadable".
            if let index = EventBuffer.current.value()?.int {
                try await handler(index)
            }
        }
    }

    /// The reader has opened the native list of choices.
    ///
    /// It deliberately does not echo an `isOpen(true)` write from the tree: an
    /// application issuing that request already knows it did so.
    public func onOpened(_ handler: @escaping EventHandler) -> Self {
        addHandler(.opened, handler)
    }

    /// The reader has closed it - by a choice, a click outside or the native
    /// platform's dismissal command.
    public func onClosed(_ handler: @escaping EventHandler) -> Self {
        addHandler(.closed, handler)
    }
}
