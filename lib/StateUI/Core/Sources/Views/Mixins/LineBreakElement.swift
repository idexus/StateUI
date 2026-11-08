// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an element showing words that may not fit shares - a text, a button's caption: what happens to them, which a
/// style may give.
///
///     Text(note.body).lineBreak(.tailTruncation)
public protocol LineBreakElement: PropertyContainer {}

extension LineBreakElement {
    /// What happens to words too long for the space: wrap them, or cut them
    /// and say so.
    public func lineBreak(_ value: LineBreak) -> Modified {
        setValue(LineBreakElementContract.lineBreak, value)
    }
}

extension LineBreakElement where Self: ModifiableElement {
    /// `lineBreak` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func lineBreak(_ state: Binding<LineBreak>) -> Modified {
        twin(LineBreakElementContract.lineBreak, carrying: state)
    }
}
