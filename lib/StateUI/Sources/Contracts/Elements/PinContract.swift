// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A pin on the map.
public enum PinContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .pin

    /// An optional provider supplies it; no base host has to.
    public static let layer: ElementLayer = .provider

    /// The line under the label in the callout.
    public static let address = ElementProperty<Self, String>("address", layer: .provider)

    /// The callout's first line, in bold.
    public static let label = ElementProperty<Self, String>("label", layer: .provider)

    /// Where it stands.
    public static let location = ElementProperty<Self, Location>("location", layer: .provider, travels: false)

    /// The pin was tapped.
    public static let pinClicked = ElementEvent<Self, Void>("pinClicked", layer: .provider)

    /// The callout above the pin - its details - was tapped.
    public static let pinDetailsClicked = ElementEvent<Self, Void>("pinDetailsClicked", layer: .provider)

    /// What the pin stands for, which decides the icon the platform draws for
    /// it.
    public static let type = ElementProperty<Self, PinType>("type", layer: .provider)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        address, label, location, pinClicked, pinDetailsClicked, type,
    ]
}
