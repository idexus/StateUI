// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an arrangement declares of the bar while it stands on the visible
/// path: its look.
public enum BarElementContract: Contract {
    /// The tier's name.
    public static let name = "BarElement"

    /// The bar's color; unwritten, the platform's own material.
    public static let barBackgroundColor = ElementProperty<Self, Color>("barBackgroundColor", layer: .adaptive)

    /// The color behind the bar's buttons, where the host draws them a
    /// background.
    public static let barButtonBackgroundColor = ElementProperty<Self, Color>(
        "barButtonBackgroundColor", layer: .adaptive)

    /// The color of what stands on the bar: the title and the native
    /// affordances.
    public static let barForegroundColor = ElementProperty<Self, Color>("barForegroundColor", layer: .adaptive)

    /// How the bar's buttons stand, where the host draws them itself.
    public static let toolbarStyle = ElementProperty<Self, ToolbarStyle>("toolbarStyle", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [
        barBackgroundColor, barButtonBackgroundColor, barForegroundColor, toolbarStyle,
    ]
}
