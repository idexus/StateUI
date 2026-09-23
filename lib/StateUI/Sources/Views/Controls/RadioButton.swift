// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `RadioButton`'s own properties, shared by the control and its
/// `Style<RadioButton>`.
public protocol RadioButtonProperties: PropertyContainer {}

extension RadioButtonProperties {
    /// Whether this is the chosen one.
    public func isOn(_ value: Bool) -> Modified {
        setValue(RadioButtonContract.isOn, value)
    }

    /// Which set this belongs to: picking one clears every other button with
    /// the same name in the window.
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
/// The group name makes them exclusive: the host unchecks the others with the
/// same name and reports both changes together, which is why the handler above
/// acts on `checked` alone. Buttons with no group name are exclusive within
/// the layout that holds them.
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

    // Design: docs/design/views/bindings.md#two-way-controls
    /// Two-way: shows what the state holds and writes back what is picked,
    /// with no view rebuilt for it.
    ///
    /// - Parameter binding: the state shown, and written back into as the
    ///   user picks or clears it.
    /// - Returns: the button, wearing and reporting that value.
    public func isOn(_ binding: Binding<Bool>) -> Self {
        binding.image == nil
            ? described(RadioButtonContract.isOn.token, binding, on: RadioButtonContract.toggled.token)
            : plain(RadioButtonContract.isOn.token, by: binding, mode: .inOut)
    }

    // MARK: Events

    /// Fires when this button is picked or cleared, with the new value: picking
    /// one raises it on two buttons, false on the one chosen before and true on
    /// the new one. Runs after a binding's write.
    public func onToggled(_ handler: @escaping ValueEventHandler<Bool>) -> Self {
        onEvent(RadioButtonContract.toggled, handler)
    }
}

extension RadioButton {
    /// `textCase` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func textCase(_ state: Binding<TextCase>) -> Modified {
        plain(.textCase, by: state)
    }
}
