// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `TextEditor`'s own properties, shared by the control and its
/// `Style<TextEditor>`.
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
/// a field that wraps and keeps the newlines the user types. A Return is
/// text here, so it has no `onSubmitted`; `isFocused` says when the editing
/// ends.
public struct TextEditor: TextInput, TextualElement, FontElement, TextAlignmentElement, BorderElement,
    TextEditorProperties {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: TextEditorContract.self)
    }

    /// An editor showing `text`. One-way: what is typed goes nowhere without
    /// `.onTextChanged`, which is what the binding form does for you.
    public init(_ text: String) {
        node = Node(contract: TextEditorContract.self)
        node.write(TextElementContract.text, text)
    }

    /// Two-way: shows what the binding holds, and writes back what is typed.
    public init(_ state: Binding<String>) {
        self = TextEditor().text(state)
    }

    /// Its text from a state carried both ways.
    func text(_ state: Binding<String>) -> Modified {
        words(TextElementContract.text.token, by: state, mode: .inOut)
    }

}

extension TextEditor {
    /// `growsWithText` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func growsWithText(_ state: Binding<Bool>) -> Modified {
        twin(TextEditorContract.growsWithText, by: state)
    }
}
