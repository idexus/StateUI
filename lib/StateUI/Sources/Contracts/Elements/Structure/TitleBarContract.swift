// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An authored title area attached to a window.
public enum TitleBarContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "TitleBar"

    /// Every base host presents it by its platform's conventions, keeping
    /// StateUI's state contract.
    public static let layer: ElementLayer = .adaptive

    /// A title area is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// The colour the bar draws its title and subtitle in.
    public static let barForegroundColor = ElementProperty<Self, Color>(
        "barForegroundColor", layer: .adaptive)

    /// A small picture beside the title.
    public static let icon = ElementProperty<Self, ImageSource>("icon", layer: .adaptive)

    /// A second line naming the current document or section.
    public static let subtitle = ElementProperty<Self, String>("subtitle", layer: .adaptive)

    /// The title.
    public static let title = ElementProperty<Self, String>("title", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [barForegroundColor, icon, subtitle, title]
}
