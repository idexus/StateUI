// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The space a control keeps inside itself, around its content: worn by
/// every layout, and by the controls that pad their content - Text, Button
/// and ScrollView among them.
public protocol PaddingElement: VisualElementProperties {}

extension PaddingElement {
    /// The space kept inside the view, between its edge and its content.
    /// Margin is the space outside.
    ///
    ///     VStack { … }.padding(24)
    public func padding(_ value: Insets) -> Modified { setValue(PaddingElementContract.padding, value) }

    /// The same on the left and the right, and the same above and below.
    public func padding(horizontal: Double, vertical: Double) -> Modified {
        padding(Insets(horizontal: horizontal, vertical: vertical))
    }

    /// Each side by name.
    public func padding(left: Double, top: Double, right: Double, bottom: Double) -> Modified {
        padding(Insets(left: left, top: top, right: right, bottom: bottom))
    }
}

extension PaddingElement where Self: VisualElement {
    /// `padding` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func padding(_ state: Binding<Insets>) -> Modified {
        journey(PaddingElementContract.padding, by: state)
    }
}
