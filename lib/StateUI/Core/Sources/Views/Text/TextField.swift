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

    /// What the keyboard's return key is captioned - Go, Search, Send, Next.
    /// What the key does is `.onSubmitted`, which it raises whatever it says;
    /// `.next` hands the keyboard on as well, to the next field the page
    /// reads. A host with a hardware keyboard may have no caption to change,
    /// and does both all the same.
    ///
    ///     TextField($name).submitLabel(.next)
    ///     TextField($street).submitLabel(.next)
    ///     TextField($city).submitLabel(.done).onSubmitted { save() }
    public func submitLabel(_ value: SubmitLabel) -> Modified {
        setValue(TextFieldContract.submitLabel, value)
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
    TextFieldProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<TextField>` is written against.
    public init() {
        node = Node(contract: TextFieldContract.self)
    }

    /// A field showing `text`. One-way: what is typed goes nowhere without
    /// `.onTextChanged`, which is what the binding form does for you.
    public init(_ text: String) {
        node = Node(contract: TextFieldContract.self)
        node.write(TextualElementContract.text, text)
    }

    /// Two-way: shows what the binding holds, and writes back what is typed.
    public init(_ state: some TwoWay<String>) {
        self = TextField().text(state)
    }

    // Design: docs/design/views/bindings.md#two-way-controls
    /// The same two-way text as `TextField($text)`, written as a modifier.
    ///
    ///     TextField($query)
    ///     TextField().text($query)
    ///
    /// The host shows the state's text and writes back what the user types,
    /// with no view rebuilt for it: a keystroke costs a render only in a body
    /// that reads the state.
    ///
    /// - Parameter state: the state shown, and written back into as the user
    ///   types.
    /// - Returns: the control, wearing and reporting that text.
    public func text(_ state: some TwoWay<String>) -> Modified {
        guard let whole = state.whole else {
            return described(TextualElementContract.text.token, state, on: .textChanged)
        }

        return words(TextualElementContract.text.token, by: whole, mode: .inOut)
    }

    // MARK: Events

    /// Fires when the return key is pressed - the moment to move to the next
    /// field or run the search.
    public func onSubmitted(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(TextFieldContract.submitted, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onSubmitted(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(TextFieldContract.submitted, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onSubmitted(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(TextFieldContract.submitted, gate: gate, handler)
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

    /// `submitLabel` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func submitLabel(_ state: Binding<SubmitLabel>) -> Modified {
        twin(TextFieldContract.submitLabel, carrying: state)
    }
}
