// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: Entry (and the InputView properties it inherits).

/// Entry's own properties - the half a `Style<Entry>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol EntryProperties: PropertyContainer {}

extension EntryProperties {
    /// Whether what is typed is hidden behind dots. MAUI: Entry.IsPassword.
    public func isPassword(_ value: Bool) -> Modified {
        setValue(.isPassword, .bool(value))
    }

    /// What the keyboard's return key is captioned - Go, Search, Send, Next.
    /// MAUI: Entry.ReturnType. The caption only; what the key DOES is
    /// `.onCompleted`, which it raises whatever it says.
    public func returnType(_ value: ReturnType) -> Modified {
        setValue(.returnType, value.propValue)
    }

    /// When the button that empties the field appears - the one the platform
    /// draws inside it. MAUI: Entry.ClearButtonVisibility.
    public func clearButtonVisibility(_ value: ClearButtonVisibility) -> Modified {
        setValue(.clearButtonVisibility, value.propValue)
    }
}

/// A single-line text field.
///
///     @State private var name = ""
///
///     Entry($name)
///         .placeholder("Type your name")
///         .keyboard(.text)
///
/// Given a binding the field shows the value and writes every edit back. Given a
/// plain string it shows that and nothing else, and `.onTextChanged` is how what
/// is typed gets anywhere:
///
///     Entry(name)
///         .onTextChanged { edited in name = edited }
///
/// The handler's argument is MAUI's `TextChangedEventArgs.NewTextValue` - the
/// text as it stands after the edit. It runs beside a binding rather than
/// instead of one, so a field may have both.
public struct Entry: InputView, TextElement, FontElement, TextAlignmentElement, EntryProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Entry>` is written against.
    public init() {
        node = Node(type: .entry)
    }

    /// A field showing `text`. One-way: what is typed goes nowhere without
    /// `.onTextChanged`, which is what the binding form does for you.
    public init(_ text: String) {
        node = Node(type: .entry, props: [.text: .string(text)])
    }

    /// Two-way: shows what the binding holds, and writes back what is typed.
    public init(_ text: Binding<String>) {
        node = Node(type: .entry, props: [.text: .string(text.wrappedValue)])
        node.addHandler(.textChanged) {
            if let typed = EventBuffer.current.value()?.string {
                text.wrappedValue = typed
            }
        }
    }

    // MARK: Properties

    // MARK: Events

    /// Fires when the return key is pressed - the moment to move to the next
    /// field or run the search. MAUI: Entry.Completed.
    public func onCompleted(_ handler: @escaping EventHandler) -> Self {
        addHandler(.completed, handler)
    }
}
