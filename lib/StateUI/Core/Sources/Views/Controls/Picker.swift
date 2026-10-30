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

    /// What the field says while nothing is chosen. A host can also reuse it
    /// as the heading of a separate native choice surface.
    public func placeholder(_ value: String) -> Modified {
        setValue(PickerContract.placeholder, value)
    }

    /// How the values are offered: `.menu`, the default - a field opening the
    /// list - `.segmented`, a row of segments, or `.radio`, a radio button
    /// for each. A list opens only from a menu.
    ///
    ///     Picker(Span.allCases, selection: $span) { "\($0)" }
    ///         .presentation(.segmented)
    public func presentation(_ value: PickerPresentation) -> Modified {
        setValue(PickerContract.presentation, value)
    }
}

/// One choice out of a list of values.
///
///     enum Span: CaseIterable, Hashable { case day, week, month }
///     @State private var span = Span.week
///
///     Picker(Span.allCases, selection: $span) { "\($0)" }
///         .placeholder("Span")
///
/// The choice is one of the values, not a place in the list: the list may
/// change its order and the choice stays. Each value shows by its caption -
/// its description unless the picker is given one. The picker takes
/// `.textColor` but has no `.text`: the field shows the chosen value's caption,
/// or the placeholder while nothing is chosen.
public struct Picker: ElementView, TextColorElement, FontElement, TextAlignmentElement, TintElement,
    PickerProperties, FocusElement {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Picker>` is written against.
    public init() {
        node = Node(contract: PickerContract.self)
    }

    /// A picker offering `items`, each by its `caption`, with the one
    /// `selection` holds chosen; the user's choice is written into it.
    ///
    /// - Parameters:
    ///   - items: the values to choose from, in the order they are offered.
    ///   - selection: the state holding the chosen value, shown and written back into.
    ///   - caption: the words each value shows by; its description unless given.
    public init<Item: Equatable>(
        _ items: [Item], selection: some TwoWay<Item>, caption: (Item) -> String = { "\($0)" }
    ) {
        let chosen = Binding<Item?>.Proxy(
            get: { selection.wrappedValue }, set: { if let value = $0 { selection.wrappedValue = value } })
        self.init(items, chosen: chosen, caption: caption)
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
        _ items: [Item], selection: some TwoWay<Item?>, caption: (Item) -> String = { "\($0)" }
    ) {
        self.init(items, chosen: selection, caption: caption)
    }

    /// The choice crosses as the chosen value's place in the list, worked out
    /// again at each build, and a choice reported comes back as its value.
    /// Design: docs/design/views/bindings.md#two-way-controls
    private init<Item: Equatable>(_ items: [Item], chosen: some TwoWay<Item?>, caption: (Item) -> String) {
        var picker = Picker()
        picker.node.write(PickerContract.options, items.map(caption))
        let place = Binding<Int>.Proxy(
            get: { chosen.wrappedValue.flatMap { items.firstIndex(of: $0) } ?? -1 },
            set: { place in if items.indices.contains(place) { chosen.wrappedValue = items[place] } })
        self = picker.described(.selectedIndex, place, on: .selectedIndexChanged)
    }

    // MARK: Events

    /// The user has opened the list of choices. Opening it with `isOpen(true)`
    /// raises nothing: the application already knows.
    public func onOpened(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(PickerContract.opened, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onOpened(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PickerContract.opened, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onOpened(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PickerContract.opened, gate: gate, handler)
    }

    /// The user has closed it - by a choice, a click outside or the platform's
    /// own dismissal.
    public func onClosed(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(PickerContract.closed, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onClosed(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PickerContract.closed, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onClosed(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(PickerContract.closed, gate: gate, handler)
    }
}

extension Picker {
    /// `isOpen` from a state, `$x`, both ways: the host opens and closes the list as the state stands, and the
    /// user's opening and closing come back into it; no view is rebuilt for it.
    public func isOpen(_ state: Binding<Bool>) -> Modified {
        opening(PickerContract.isOpen, by: state, opened: PickerContract.opened, closed: PickerContract.closed)
    }

    /// `placeholder` from a state, `$x`: the host writes each new text, and no
    /// view is rebuilt for it.
    public func placeholder(_ state: Binding<String>) -> Modified {
        words(PickerContract.placeholder, by: state)
    }
}
