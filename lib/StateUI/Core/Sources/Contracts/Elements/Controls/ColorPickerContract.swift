// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A well showing a color, which the user opens to choose another in the platform's own picker.
public enum ColorPickerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ColorPicker"

    /// The platform's own picker where it has one.
    public static let layer: ElementLayer = .native

    /// A color picker is a view the keyboard reaches.
    public static let tiers: [any Contract.Type] = [ViewContract.self, FocusElementContract.self]

    /// Whether the user chooses the color's opacity too; an opaque color only where false, the default.
    public static let choosesOpacity = ElementProperty<Self, Bool>("choosesOpacity", layer: .native)

    /// The color the well shows.
    public static let color = ElementProperty<Self, Color>("color", layer: .native)

    /// The user chose another color, which it carries.
    public static let colorChanged = ElementEvent<Self, Color>("colorChanged", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [choosesOpacity, color, colorChanged]
}
