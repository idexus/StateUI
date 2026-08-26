// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: RadioButton.

/// RadioButton's own properties - the half a `Style<RadioButton>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol RadioButtonProperties: PropertyContainer {}

extension RadioButtonProperties {
    /// The caption. MAUI: RadioButton.Content, which is why it is not `text`.
    public func content(_ value: String) -> Modified {
        setValue(.content, .string(value))
    }

    /// Whether this is the chosen one. MAUI: RadioButton.IsChecked.
    public func isChecked(_ value: Bool) -> Modified {
        setValue(.isChecked, .bool(value))
    }

    /// Which set this belongs to - picking one clears every other button
    /// carrying the same name. MAUI: RadioButton.GroupName.
    ///
    /// A NAME rather than prose, which is what the property is for: every
    /// button in the set writes the same one, so it rides the session's
    /// dictionary as a number instead of once per button.
    public func groupName(_ value: String) -> Modified {
        setValue(.groupName, .name(value))
    }

    /// Whether the caption is DRAWN as written or in one case throughout.
    /// MAUI: RadioButton.TextTransform.
    ///
    /// Written here rather than taken from a tier because MAUI gives this
    /// control the transform without giving it a `Text` - it captions itself
    /// with `Content` - so it is the one place the two do not travel together.
    public func textTransform(_ value: TextTransform) -> Modified {
        setValue(.textTransform, value.propValue)
    }
}

/// One choice out of several, where picking one clears the rest.
/// MAUI: RadioButton.
///
///     @State private var size = "Medium"
///
///     VStack {
///         ForEach(["Small", "Medium", "Large"]) { option in
///             RadioButton(option)
///                 .groupName("size")
///                 .isChecked(option == size)
///                 .onCheckedChanged { checked in
///                     if checked { size = option }
///                 }
///         }
///     }
///
/// One `@State` for the whole group rather than one Bool per button: what is
/// chosen is a single value, and each button is checked when it matches it.
///
/// The group name is what makes them exclusive: MAUI unchecks the others
/// carrying the same one when a button is checked, and reports both changes -
/// which is why the handler above acts on `checked` alone and ignores the
/// false. Buttons with no group name are exclusive within the layout that
/// holds them.
///
/// The caption is `content`, not `text` - MAUI's RadioButton has no Text
/// property, which is why this is a `TextStyleElement` rather than a
/// `TextElement` the way Label and Button are: the colour and the letter
/// spacing come from the tier, and there is no `.text()` to write a caption
/// MAUI has no property for.
public struct RadioButton: View, TextStyleElement, FontElement, PaddingElement,
    BorderElement, RadioButtonProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<RadioButton>` is written against.
    public init() {
        node = Node(type: .radioButton)
    }

    /// A button captioned `content`. One-way: what is picked goes nowhere
    /// without `.onCheckedChanged`.
    public init(_ content: String) {
        node = Node(type: .radioButton, props: [.content: .string(content)])
    }

    // MARK: Properties

    /// Two-way: shows whether this is the chosen one, and writes back when that
    /// changes - including when it changes because a sibling was picked.
    ///
    /// An `.onCheckedChanged` written beside it runs BESIDE this write rather
    /// than replacing it, like every typed event modifier - whichever order
    /// the two are written in. The order decides only who runs FIRST.
    public func isChecked(_ binding: Binding<Bool>) -> Self {
        isChecked(binding.wrappedValue)
            .addHandler(.checkedChanged) {
                if let checked = EventBuffer.current.value()?.bool {
                    binding.wrappedValue = checked
                }
            }
    }

    // MARK: Events

    /// Fires when this button is picked OR cleared, with the new value - MAUI's
    /// `CheckedChangedEventArgs.Value`. Picking one raises this on two buttons:
    /// false on the one that was chosen before, true on the new one. Runs after
    /// a binding's write, if there is one.
    public func onCheckedChanged(_ handler: @escaping ValueEventHandler<Bool>) -> Self {
        addHandler(.checkedChanged) {
            if let checked = EventBuffer.current.value()?.bool {
                try await handler(checked)
            }
        }
    }
}
