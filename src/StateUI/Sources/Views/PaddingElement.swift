// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The space a control keeps inside itself.
//
// A tier of its own rather than a block in Elements.swift - that file is the
// tier every view shares, and a padding is four controls': MAUI puts it on an
// interface because Layout, Label, Button and ScrollView share no base class
// to declare it on.

/// The space a control keeps INSIDE itself, around its content.
/// MAUI: IPaddingElement - the interface Layout, Label, Button and ScrollView
/// all implement, having no base class between them to declare it on.
public protocol PaddingElement: VisualElementProperties {}

extension PaddingElement {
    /// The space kept INSIDE the view, between its edge and its content.
    /// MAUI: Padding. Margin is the space outside.
    ///
    ///     VStack { … }.padding(24)
    public func padding(_ value: Thickness) -> Modified { setValue(.padding, value.propValue) }

    /// Left and right, then top and bottom. MAUI writes this `Padding="24,16"`.
    public func padding(_ horizontalSize: Double, _ verticalSize: Double) -> Modified {
        padding(Thickness(horizontalSize, verticalSize))
    }

    /// Each side in turn, in MAUI's order: left, top, right, bottom.
    public func padding(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) -> Modified {
        padding(Thickness(left, top, right, bottom))
    }
}
