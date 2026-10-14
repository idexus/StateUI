// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The space between the letters of words drawn as written - worn by `Text`,
/// `Button` and `TextSpan`; a field's words are the user's, a picker's a
/// formatted value.
public protocol TrackingElement: PropertyContainer {}

extension TrackingElement {
    /// The space added between letters, in device units.
    public func tracking(_ value: Double) -> Modified { setValue(TrackingElementContract.tracking, value) }
}

extension TrackingElement where Self: VisualElement {
    /// `tracking` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func tracking(_ state: Binding<Double>) -> Modified {
        twin(TrackingElementContract.tracking, by: state)
    }
}
