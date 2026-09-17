// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// RadioButton's own properties - the half a `Style<RadioButton>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol RadioButtonProperties: PropertyContainer {}

extension RadioButtonProperties {
    /// Whether this is the chosen one.
    public func isOn(_ value: Bool) -> Modified {
        setValue(RadioButtonContract.isOn, value)
    }

    /// Which set this belongs to - picking one clears every other button
    /// carrying the same name inside one native window.
    ///
    /// A name rather than prose: every button in the set writes the same one,
    /// and the host resolves it without relying on native view adjacency.
    public func groupName(_ value: String) -> Modified {
        setValue(RadioButtonContract.groupName, Name(value))
    }
}

/// One choice out of several, where picking one clears the rest.
///
///     @State private var size = "Medium"
///
///     VStack {
///         ForEach(["Small", "Medium", "Large"]) { option in
///             RadioButton(option)
///                 .groupName("size")
///                 .isOn(option == size)
///                 .onToggled { checked in
///                     if checked { size = option }
///                 }
///         }
///     }
///
/// One `@State` for the whole group rather than one Bool per button: what is
/// chosen is a single value, and each button is checked when it matches it.
///
/// The group name is what makes them exclusive: the host unchecks the others
/// carrying the same one and reports both changes atomically -
/// which is why the handler above acts on `checked` alone and ignores the
/// false. Buttons with no group name are exclusive within the layout that
/// holds them.
///
/// The caption is ordinary StateUI `text`, independent of whether a native
/// backend calls that property text, title, label or content.
public struct RadioButton: View, TextElement, FontElement, PaddingElement,
    BorderElement, RadioButtonProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<RadioButton>` is written against.
    public init() {
        node = Node(contract: RadioButtonContract.self)
    }

    /// A button captioned `text`. One-way: what is picked goes nowhere
    /// without `.onToggled`.
    public init(_ text: String) {
        node = Node(contract: RadioButtonContract.self)
        node.write(TextElementContract.text, text)
    }

    // MARK: Properties

    /// Two-way: shows what the state holds and writes back what is picked -
    /// and HANDED OVER, so the button is no reader of the state; a part of a
    /// state or a binding made from closures is shown by the tree instead.
    ///
    /// - Parameter binding: the state shown, and written back into as the
    ///   reader picks or clears it.
    /// - Returns: the button, wearing and reporting that value.
    public func isOn(_ binding: Binding<Bool>) -> Self {
        binding.image == nil
            ? described(RadioButtonContract.isOn.token, binding, on: RadioButtonContract.toggled.token)
            : plain(RadioButtonContract.isOn.token, by: binding, mode: .inOut)
    }

    // MARK: Events

    /// Fires when this button is picked OR cleared, with the new value. Picking
    /// one raises this on two buttons:
    /// false on the one that was chosen before, true on the new one. Runs after
    /// a binding's write, if there is one.
    public func onToggled(_ handler: @escaping ValueEventHandler<Bool>) -> Self {
        onEvent(RadioButtonContract.toggled, handler)
    }
}
