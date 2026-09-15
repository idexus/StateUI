// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// TextEditor's own properties - the half a `Style<TextEditor>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol TextEditorProperties: PropertyContainer {}

extension TextEditorProperties {
    /// Whether the editor grows as the text does.
    ///
    ///     TextEditor($notes).growsWithText(true)
    ///
    /// Growing, the control takes the height of its text on every edit; not
    /// growing, the default, it keeps the height it was given and scrolls the
    /// text inside it. A growing editor wants a ScrollView above it, having no
    /// height of its own to stop at.
    public func growsWithText(_ value: Bool) -> Modified {
        setValue(TextEditorContract.growsWithText, value)
    }
}

/// A text field of several lines.
///
///     @State private var notes = ""
///     …
///     TextEditor($notes)
///         .placeholder("Anything worth remembering")
///         .height(120)
///
/// A `TextField` with room: the same two-way binding and `onTextChanged`, over
/// a field that wraps and keeps the newlines the reader types. A Return is
/// text here, so it has no `onSubmitted`; `isFocused` says when the editing
/// ends.
public struct TextEditor: InputView, TextElement, FontElement, TextAlignmentElement, TextEditorProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<TextEditor>` is written against.
    public init() {
        node = Node(contract: TextEditorContract.self)
    }

    /// An editor showing `text`. One-way: what is typed goes nowhere without
    /// `.onTextChanged`, which is what the binding form does for you.
    public init(_ text: String) {
        node = Node(contract: TextEditorContract.self)
        node.write(TextElementContract.text, text)
    }

    /// Two-way: shows what the binding holds, and writes back what is typed.
    public init(_ text: Binding<String>) {
        self = TextEditor().text(text)
    }

    /// The same two-way text as `TextEditor($text)`, written as a modifier.
    ///
    ///     TextEditor($query)
    ///     TextEditor().text($query)
    ///
    /// BOTH SPELLINGS ALWAYS, and they mean the same thing: the initializer is
    /// the short way to say what gives this control its purpose, and the
    /// modifier is the way every other property is written. Neither is the
    /// real one.
    ///
    /// HANDED OVER, so the field is no reader of the state: the host writes
    /// the field's text from the state on its own frames and lands what the
    /// reader types back on it, whole, as its own write. What a keystroke
    /// COSTS is decided by who reads the state at build - nothing where nobody
    /// prints it, a render per keystroke for the body that does. A part of a
    /// state or a binding made from closures has no storage for the host to
    /// carry and takes the described road instead: shown from the value read
    /// at build, written back through the binding on every report, the
    /// closure that wrote the field a reader of it.
    ///
    /// - Parameter value: the state shown, and written back into as the reader
    ///   types.
    /// - Returns: the control, wearing and reporting that text.
    public func text(_ value: Binding<String>) -> Modified {
        value.image == nil
            ? described(.text, value, on: .textChanged)
            : words(.text, by: value, mode: .inOut)
    }

}
