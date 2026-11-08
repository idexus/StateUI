// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a field the user submits shares - a text field, a search field: the caption of the key that submits it,
/// which a style may give, and what the submission does.
///
///     TextField($city).submitLabel(.done).onSubmitted { save() }
public protocol SubmitElement: PropertyContainer {}

extension SubmitElement {
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
        setValue(SubmitElementContract.submitLabel, value)
    }
}

extension SubmitElement where Self: ModifiableElement {
    /// Fires when the return key is pressed - the moment to move to the next
    /// field or run the search.
    public func onSubmitted(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(SubmitElementContract.submitted, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onSubmitted(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(SubmitElementContract.submitted, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onSubmitted(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(SubmitElementContract.submitted, gate: gate, handler)
    }

    /// `submitLabel` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func submitLabel(_ state: Binding<SubmitLabel>) -> Modified {
        twin(SubmitElementContract.submitLabel, carrying: state)
    }
}
