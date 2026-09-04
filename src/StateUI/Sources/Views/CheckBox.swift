// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: CheckBox.

/// CheckBox's own properties - the half a `Style<CheckBox>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol CheckBoxProperties: PropertyContainer {}

extension CheckBoxProperties {
    /// Whether the box is ticked. MAUI: CheckBox.IsChecked.
    ///
    /// Usually given in the initializer instead; this is the way to set it in a
    /// style, or to change it on a checkbox built elsewhere.
    public func isChecked(_ value: Bool) -> Modified {
        setValue(.isChecked, .bool(value))
    }

    /// What colour the tick and the box around it are drawn in.
    /// MAUI: CheckBox.Color.
    public func color(_ value: Color) -> Modified {
        setValue(.color, value.propValue)
    }
}

/// A box that is ticked or not.
///
///     @State private var agreed = false
///     …
///     HStack {
///         CheckBox($agreed).color(.firebrick)
///         Label("I agree").verticalOptions(.center)
///     }
///
/// Given a binding it shows what the binding holds and writes every tick back.
/// Given a plain `Bool` it only shows: `.onCheckedChanged` is then the one way
/// a tick reaches anywhere.
///
/// No caption of its own - MAUI's CheckBox has none either, being the box and
/// nothing else. Put a Label beside it, as above.
public struct CheckBox: View, CheckBoxProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<CheckBox>` is written against.
    public init() {
        node = Node(type: .checkBox)
    }

    /// A box that is ticked or not. One-way: what is ticked goes nowhere
    /// without `.onCheckedChanged`.
    public init(_ isChecked: Bool) {
        node = Node(type: .checkBox, props: [.isChecked: .bool(isChecked)])
    }

    /// Two-way: shows what the binding holds, and writes back what is ticked.
    public init(_ isChecked: Binding<Bool>) {
        self = CheckBox().isChecked(isChecked)
    }

    /// The same two-way value as `CheckBox($isChecked)`, written as a modifier.
    ///
    ///     CheckBox($level)
    ///     CheckBox().isChecked($level)
    ///
    /// BOTH SPELLINGS ALWAYS, and they mean the same thing: the initializer is
    /// the short way to say what gives this control its purpose, and the
    /// modifier is the way every other property is written. Neither is the
    /// real one.
    ///
    /// - Parameter value: the state shown, and written back into as the reader
    ///   moves it.
    /// - Returns: the control, showing and reporting that value.
    public func isChecked(_ value: Binding<Bool>) -> Modified {
        modified {
            $0.props[.isChecked] = .bool(value.wrappedValue)
            $0.addHandler(.checkedChanged) {
                if let moved = EventBuffer.current.value()?.bool {
                    value.wrappedValue = moved
                }
            }
        }
    }

    // MARK: Properties

    // MARK: Events

    /// Fires when it is ticked or unticked, with the new value - MAUI's
    /// `CheckedChangedEventArgs.Value`. Runs after a binding's write, if there
    /// is one.
    public func onCheckedChanged(_ handler: @escaping ValueEventHandler<Bool>) -> Self {
        addHandler(.checkedChanged) {
            if let checked = EventBuffer.current.value()?.bool {
                try await handler(checked)
            }
        }
    }
}
