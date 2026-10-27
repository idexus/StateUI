// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an arrangement declares of the bar while it stands on the visible
/// path: its look.
public enum BarElementContract: Contract {
    /// The tier's name.
    public static let name = "BarElement"

    /// What the bar is made of - a color, a gradient, a blur or glass; unwritten, the platform's own material.
    public static let barBackground = ElementProperty<Self, Material>("barBackground", layer: .adaptive)

    /// The color of what stands on the bar: the title and the native
    /// affordances.
    public static let barForegroundColor = ElementProperty<Self, Color>("barForegroundColor", layer: .adaptive)

    /// How the bar's buttons stand, where the host draws them itself.
    public static let toolbarStyle = ElementProperty<Self, ToolbarStyle>("toolbarStyle", layer: .adaptive)

    /// The room between the bar's groups and its own buttons, where the host draws the bar itself.
    public static let toolbarSpacing = ElementProperty<Self, Double>("toolbarSpacing", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [barBackground, barForegroundColor, toolbarStyle, toolbarSpacing]
}
