// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A text field for what to search for, shown as the platform's search field.
///
///     SearchField($query)
///         .placeholder("Search the list")
///         .onSubmitted { runTheSearch() }
///
/// A TextField that says what it is for: the platform draws the magnifier and the
/// cancel button, and the keyboard's return key searches.
///
/// It goes wherever a view goes - in the page's content, or ON the navigation
/// bar as that page's `titleView`, which is what an application
/// writes when it wants the bar to do the searching.
///
/// Given a binding the field shows the value and writes every edit back; given a
/// plain string it shows that, and `.onTextChanged` is how what is typed gets
/// anywhere.
public struct SearchField: TextInput, TextualElement, FontElement, TextAlignmentElement, BorderElement,
    SubmitElement {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: SearchFieldContract.self)
    }

    /// A search box showing `text`. One-way: what is typed goes nowhere without
    /// `.onTextChanged`.
    public init(_ text: String) {
        node = Node(contract: SearchFieldContract.self)
        node.write(TextElementContract.text, text)
    }

    /// Two-way: shows what the binding holds, and writes back what is typed.
    public init(_ state: Binding<String>) {
        self = SearchField().text(state)
    }

    /// Its text from a state carried both ways.
    func text(_ state: Binding<String>) -> Modified {
        words(TextElementContract.text.token, by: state, mode: .inOut)
    }
}

