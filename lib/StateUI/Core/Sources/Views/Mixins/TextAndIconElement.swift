// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a button and a bar's item share: whether their words stand beside
/// their picture.
///
///     Button("Delete")
///         .icon("trash.png")
///         .showsText(false)
public protocol TextAndIconElement: PropertyContainer {}

extension TextAndIconElement {
    /// Whether its words stand beside its picture. Unsaid, a button shows
    /// them and a bar's item shows its picture alone. Left out, the words
    /// still name it to assistive technology - a bar's item's stand in its tip
    /// too; one with no picture always shows its words.
    public func showsText(_ value: Bool) -> Modified {
        setValue(TextAndIconElementContract.showsText, value)
    }
}

extension TextAndIconElement where Self: VisualElement {
    /// `showsText` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func showsText(_ state: Binding<Bool>) -> Modified {
        twin(TextAndIconElementContract.showsText, by: state)
    }
}
