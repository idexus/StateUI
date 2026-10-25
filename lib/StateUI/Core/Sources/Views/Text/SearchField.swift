// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `SearchField`'s own properties, shared by the control and its
/// `Style<SearchField>`.
public protocol SearchFieldProperties: PropertyContainer {}

extension SearchFieldProperties {
    /// What the keyboard's return key is captioned, `.search` unless said. What
    /// the key does is `.onSubmitted`; `.next` hands the keyboard on as well,
    /// to the next field the page reads.
    public func submitLabel(_ value: SubmitLabel) -> Modified {
        setValue(SearchFieldContract.submitLabel, value)
    }
}

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
public struct SearchField: TextInput, TextualElement, FontElement, TextAlignmentElement, SearchFieldProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<SearchField>` is written against.
    public init() {
        node = Node(contract: SearchFieldContract.self)
    }

    /// A search box showing `text`. One-way: what is typed goes nowhere without
    /// `.onTextChanged`.
    public init(_ text: String) {
        node = Node(contract: SearchFieldContract.self)
        node.write(TextualElementContract.text, text)
    }

    /// Two-way: shows what the binding holds, and writes back what is typed.
    public init(_ state: Binding<String>) {
        self = SearchField().text(state)
    }

    // Design: docs/design/views/bindings.md#two-way-controls
    /// The same two-way text as `SearchField($text)`, written as a modifier.
    ///
    ///     SearchField($query)
    ///     SearchField().text($query)
    ///
    /// The host shows the state's text and writes back what the user types,
    /// with no view rebuilt for it: a keystroke costs a render only in a body
    /// that reads the state.
    ///
    /// - Parameter state: the state shown, and written back into as the user
    ///   types.
    /// - Returns: the control, wearing and reporting that text.
    public func text(_ state: Binding<String>) -> Modified {
        state.image == nil
            ? described(TextualElementContract.text.token, state, on: .textChanged)
            : words(TextualElementContract.text.token, by: state, mode: .inOut)
    }

    // MARK: Events

    /// Fires when the search is submitted - the return key, or the magnifier
    /// where a platform draws a button.
    public func onSubmitted(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(SearchFieldContract.submitted, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onSubmitted(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(SearchFieldContract.submitted, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onSubmitted(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(SearchFieldContract.submitted, gate: gate, handler)
    }
}

extension SearchField {
    /// `submitLabel` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func submitLabel(_ state: Binding<SubmitLabel>) -> Modified {
        twin(SearchFieldContract.submitLabel, carrying: state)
    }
}
