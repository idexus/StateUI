// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The space a control keeps inside itself, around its content: worn by
/// every layout, and by the controls that pad their content - Label, Button,
/// Border and ScrollView among them.
public protocol PaddingElement: VisualElementProperties {}

extension PaddingElement {
    /// The space kept inside the view, between its edge and its content.
    /// Margin is the space outside.
    ///
    ///     VStack { … }.padding(24)
    public func padding(_ value: Insets) -> Modified { setValue(PaddingElementContract.padding, value) }

    /// Left and right, then top and bottom.
    public func padding(_ horizontalSize: Double, _ verticalSize: Double) -> Modified {
        padding(Insets(horizontalSize, verticalSize))
    }

    /// Each side in turn: left, top, right, bottom.
    public func padding(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) -> Modified {
        padding(Insets(left, top, right, bottom))
    }
}
