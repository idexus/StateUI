// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an arrangement declares of the bar while it stands on the visible
/// path: its colours, and the application's name, line and mark in the bar.
public enum BarElementContract: Contract {
    /// The tier's name.
    public static let name = "BarElement"

    /// The bar's colour; unwritten, the platform's own material.
    public static let barBackgroundColor = ElementProperty<Self, Color>("barBackgroundColor", layer: .adaptive)

    /// The colour of what stands on the bar: the title and the native
    /// affordances.
    public static let barForegroundColor = ElementProperty<Self, Color>("barForegroundColor", layer: .adaptive)

    /// The application's mark beside its name in the bar.
    public static let barIcon = ElementProperty<Self, ImageSource>("barIcon", layer: .adaptive)

    /// A second line in the bar, under the title it shows: the current
    /// document or section.
    public static let barSubtitle = ElementProperty<Self, String>("barSubtitle", layer: .adaptive)

    /// The application's name in the bar, where the platform's chrome names
    /// the application.
    public static let barTitle = ElementProperty<Self, String>("barTitle", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [
        barBackgroundColor, barForegroundColor, barIcon, barSubtitle, barTitle,
    ]
}
