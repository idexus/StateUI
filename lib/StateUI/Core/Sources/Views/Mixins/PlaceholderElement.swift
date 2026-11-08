// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an element holding nothing shows - a field while it is empty, a picker while nothing is chosen: the words it
/// says then, which a style may give.
///
///     TextField($city).placeholder("City")
public protocol PlaceholderElement: PropertyContainer {}

extension PlaceholderElement {
    /// What the element says while it holds nothing: a field while it is
    /// empty, a picker while nothing is chosen. A host can also reuse a
    /// picker's as the heading of a separate native choice surface.
    public func placeholder(_ value: String) -> Modified {
        setValue(PlaceholderElementContract.placeholder, value)
    }
}

extension PlaceholderElement where Self: ModifiableElement {
    /// `placeholder` from a state, `$x`: the host writes each new text, and no
    /// view is rebuilt for it.
    public func placeholder(_ state: Binding<String>) -> Modified {
        words(PlaceholderElementContract.placeholder, by: state)
    }
}
