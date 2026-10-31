// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The space a control keeps inside itself, around its content: worn by
/// every layout, by the controls that pad their content - Text, Button
/// and ScrollView among them - and by the items on a bar.
public protocol PaddingElement: PropertyContainer {}

extension PaddingElement {
    /// The space kept inside the view, between its edge and its content.
    /// Margin is the space outside.
    ///
    ///     VStack { … }.padding(24)
    public func padding(_ value: Insets) -> Modified { setValue(PaddingElementContract.padding, value) }

    /// The same at the start and the end, and the same above and below.
    public func padding(horizontal: Double, vertical: Double) -> Modified {
        padding(Insets(horizontal: horizontal, vertical: vertical))
    }

    /// Each side by name.
    public func padding(start: Double, top: Double, end: Double, bottom: Double) -> Modified {
        padding(Insets(start: start, top: top, end: end, bottom: bottom))
    }
}

extension PaddingElement where Self: VisualElement {
    /// `padding` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func padding(_ state: Binding<Insets>) -> Modified {
        twin(PaddingElementContract.padding, by: state)
    }
}
