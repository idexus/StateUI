// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The space a control keeps inside itself.
//
// A tier of its own rather than a block in Elements.swift - that file is the
// tier every view shares, and a padding is a handful of controls' and every
// layout's, so the ones that pad their content wear this tier and the rest
// are never offered the modifier.

/// The space a control keeps INSIDE itself, around its content.
/// The tier every layout wears, and every control that pads its content -
/// Label, Button, Border and ScrollView among them.
public protocol PaddingElement: VisualElementProperties {}

extension PaddingElement {
    /// The space kept INSIDE the view, between its edge and its content.
    /// Margin is the space outside.
    ///
    ///     VStack { … }.padding(24)
    public func padding(_ value: Thickness) -> Modified { setValue(.padding, value.propValue) }

    /// Left and right, then top and bottom.
    public func padding(_ horizontalSize: Double, _ verticalSize: Double) -> Modified {
        padding(Thickness(horizontalSize, verticalSize))
    }

    /// Each side in turn: left, top, right, bottom.
    public func padding(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) -> Modified {
        padding(Thickness(left, top, right, bottom))
    }
}
