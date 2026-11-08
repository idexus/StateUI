// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `TextField`'s own properties, shared by the control and its
/// `Style<TextField>`.
public protocol TextFieldProperties: PropertyContainer {}

extension TextFieldProperties {
    /// Whether what is typed is hidden behind the platform's secure-entry marks.
    public func isPassword(_ value: Bool) -> Modified {
        setValue(TextFieldContract.isPassword, value)
    }

    /// Whether the field shows the native button that empties it - while
    /// there is text and the field has the focus, on platforms whose ordinary
    /// text field provides one. It does unless told otherwise.
    public func showsClearButton(_ value: Bool) -> Modified {
        setValue(TextFieldContract.showsClearButton, value)
    }
}

/// A native single-line text field.
///
///     @State private var name = ""
///
///     TextField($name)
///         .placeholder("Type your name")
///         .inputPurpose(.text)
///
/// Given a binding the field shows the value and writes every edit back. Given a
/// plain string it shows that and nothing else, and `.onTextChanged` is how what
/// is typed gets anywhere:
///
///     TextField(name)
///         .onTextChanged { edited in name = edited }
///
/// The handler receives the whole text as it stands after the edit. It runs
/// beside a binding rather than instead of one, so a field may have both.
public struct TextField: TextInput, TextualElement, FontElement, TextAlignmentElement, BorderElement,
    TextFieldProperties, SubmitElement {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: TextFieldContract.self)
    }

    /// A field showing `text`. One-way: what is typed goes nowhere without
    /// `.onTextChanged`, which is what the binding form does for you.
    public init(_ text: String) {
        node = Node(contract: TextFieldContract.self)
        node.write(TextElementContract.text, text)
    }

    /// Two-way: shows what the binding holds, and writes back what is typed.
    public init(_ state: Binding<String>) {
        self = TextField().text(state)
    }

    /// Its text from a state carried both ways.
    func text(_ state: Binding<String>) -> Modified {
        words(TextElementContract.text.token, by: state, mode: .inOut)
    }
}

extension TextField {
    /// `showsClearButton` from a state, `$x`: the host sets each new value as
    /// it stands, and no view is rebuilt for it.
    public func showsClearButton(_ state: Binding<Bool>) -> Modified {
        twin(TextFieldContract.showsClearButton, by: state)
    }

    /// `isPassword` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func isPassword(_ state: Binding<Bool>) -> Modified {
        twin(TextFieldContract.isPassword, by: state)
    }

}
