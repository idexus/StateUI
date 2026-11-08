// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One choice out of a list of values.
///
///     enum Span: CaseIterable, Hashable { case day, week, month }
///     @State private var span = Span.week
///
///     Picker(Span.allCases, selection: $span) { "\($0)" }
///         .placeholder("Span")
///
/// The choice is one of the values, not a place in the list: the list may
/// change its order and the choice stays. A choice is always a state, which
/// the picker reads as it is described. Each value shows by its caption -
/// its description unless the picker is given one. The picker takes
/// `.textColor` but has no `.text`: the field shows the chosen value's caption,
/// or the placeholder while nothing is chosen.
public struct Picker: ElementView, TextColorElement, FontElement, TextAlignmentElement, TintElement,
    FocusElement, PopupElement, PlaceholderElement {
    /// The node this control describes.
    public var node: Node

    /// A picker offering `items`, each by its `caption`, with the one
    /// `selection` holds chosen; the user's choice is written into it.
    ///
    /// - Parameters:
    ///   - items: the values to choose from, in the order they are offered.
    ///   - selection: the state holding the chosen value, shown and written back into.
    ///   - caption: the words each value shows by; its description unless given.
    public init<Item: Equatable>(
        _ items: [Item], selection: Binding<Item>, caption: (Item) -> String = { "\($0)" }
    ) {
        let write: @MainActor (Item?) -> Void = { if let value = $0 { selection.wrappedValue = value } }
        self.init(items, read: { selection.wrappedValue }, write: write, caption: caption)
    }

    /// A picker offering `items`, each by its `caption`, with nothing chosen
    /// while `selection` holds nil - the placeholder shows then - and the user's
    /// choice written into it.
    ///
    /// - Parameters:
    ///   - items: the values to choose from, in the order they are offered.
    ///   - selection: the state holding the chosen value, or nil, shown and written back into.
    ///   - caption: the words each value shows by; its description unless given.
    public init<Item: Equatable>(
        _ items: [Item], selection: Binding<Item?>, caption: (Item) -> String = { "\($0)" }
    ) {
        let write: @MainActor (Item?) -> Void = { if let value = $0 { selection.wrappedValue = value } }
        self.init(items, read: { selection.wrappedValue }, write: write, caption: caption)
    }

    /// The choice crosses as the chosen value's place in the list, worked out
    /// again at each build, and a choice reported comes back as its value.
    /// Design: docs/design/views/bindings.md#two-way-controls
    private init<Item: Equatable>(
        _ items: [Item], read: @escaping @MainActor () -> Item?, write: @escaping @MainActor (Item?) -> Void,
        caption: (Item) -> String
    ) {
        node = Node(contract: PickerContract.self)
        node.write(PickerContract.options, items.map(caption))
        self = described(
            .selectedIndex,
            read: { read().flatMap { items.firstIndex(of: $0) } ?? -1 },
            write: { place in if items.indices.contains(place) { write(items[place]) } },
            on: .selectedIndexChanged)
    }

    // MARK: Events

    /// The user has chosen another value, after the selection's write: the
    /// handler reads it there. A choice the application makes raises nothing.
    public func onSelectionChanged(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(PickerContract.selectedIndexChanged) { (_: Int) in try handler() }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onSelectionChanged(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PickerContract.selectedIndexChanged, policy: policy) { (_: Int) in try await handler() }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onSelectionChanged(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PickerContract.selectedIndexChanged, gate: gate) { (_: Int) in try await handler() }
    }
}

extension Picker {
    /// How the values are offered: `.menu`, the default - a field opening the
    /// list - `.segmented`, a row of segments, or `.radio`, a radio button
    /// for each. A list opens only from a menu. Said where the picker is
    /// written: a style is chosen by it, `Style<Picker>(presentation:)`, and
    /// gives none.
    ///
    ///     Picker(Span.allCases, selection: $span) { "\($0)" }
    ///         .presentation(.segmented)
    public func presentation(_ value: PickerPresentation) -> Modified {
        setValue(PickerContract.presentation, value)
    }
}
