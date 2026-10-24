// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A setting on its page's bar, standing on or off - or, declared on a split
/// view, on the part of its bar it names.
///
///     ToolbarToggle("Inspector", isOn: $showsInspector)
///         .icon("sidebar.png", on: "sidebar_filled.png")
///
/// Choosing it turns its state over; the bar shows it on or off as the
/// platform shows a two-state button, and its `on:` picture while it is on.
/// Its words are always its name - to assistive technology, in its tip and
/// in the overflow, where it stands checked or not. An item that acts is a
/// `ToolbarButton`.
public struct ToolbarToggle: PlacedToolbarItem, MenuItemElement, TextAndIconElement {
    /// The node this item describes.
    public var node: Node

    /// The group it stands in alone, which its placement is written on.
    var alone = Node(contract: ToolbarGroupContract.self)

    /// An item captioned `text`, standing on as `isOn` says. One-way: the
    /// turn goes nowhere without `.onToggled`.
    public init(_ text: String, isOn: Bool) {
        node = Node(contract: ToolbarToggleContract.self)
        node.write(MenuItemElementContract.text, text)
        node.write(ToolbarToggleContract.isOn, isOn)
    }

    /// An item captioned `text`, standing on as the state holds; choosing it
    /// turns the state over.
    public init(_ text: String, isOn: Binding<Bool>) {
        self.init(text, isOn: isOn.wrappedValue)
        node.addHandler(ToolbarToggleContract.toggled.token) {
            if let turned = EventBuffer.current.value()?.bool { isOn.wrappedValue = turned }
        }
    }

    /// Fires when the user chooses it, with the way it turned to. Runs after
    /// the state's write.
    public func onToggled(_ handler: @escaping @MainActor (Bool) throws -> Void) -> Modified {
        modified { $0.addHandler(ToolbarToggleContract.toggled, handler) }
    }

    /// The same, with a handler that awaits: its `gate` says what the event does when it comes
    /// again while a run is under way.
    public func onToggled(gate: some Gate, _ handler: @escaping ValueEventHandler<Bool>) -> Modified {
        modified { $0.addHandler(ToolbarToggleContract.toggled, gate: gate, handler) }
    }

    /// Its picture while off, and `on` while on - each resolved from the
    /// application's image resources.
    public func icon(_ value: ImageSource, on: ImageSource) -> Modified {
        setValue(MenuItemElementContract.icon, value).setValue(ToolbarToggleContract.onIcon, on)
    }

    /// Who this item is among the others of its declaration, so an item
    /// inserted in the middle is matched to itself rather than to whichever
    /// stood there.
    public func id(_ value: some Hashable) -> Modified {
        var copy = self
        copy.node.identify(value)
        return copy
    }

    /// Where the item stands, each part of it only where said: the part of
    /// its split view's bar - by default its declarer's - the edge of the bar
    /// or its overflow, and its order among the others there, lower earlier.
    public func placement(
        _ part: ToolbarPart? = nil, at position: ToolbarPosition? = nil, order: Int? = nil
    ) -> Modified {
        var copy = self
        copy.alone.place(part, at: position, order: order)
        return copy
    }

    /// Whether it hides with its split view's sidebar rather than move to the
    /// start of the detail's part while the sidebar is not shown.
    public func hidesWithSidebar(_ value: Bool) -> Modified {
        var copy = self
        copy.alone.write(ToolbarGroupContract.hidesWithSidebar, value)
        return copy
    }

}
