// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A marker on the map.
public enum MarkerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Marker"

    /// An optional provider supplies it; no base host has to.
    public static let layer: ElementLayer = .provider

    /// The line under the label in the callout.
    public static let subtitle = ElementProperty<Self, String>("subtitle", layer: .provider)

    /// The callout's first line, in bold.
    public static let label = ElementProperty<Self, String>("label", layer: .provider)

    /// Where it stands.
    public static let location = ElementProperty<Self, Location>("location", layer: .provider, travels: false)

    /// The marker was tapped.
    public static let selected = ElementEvent<Self, Void>("selected", layer: .provider)

    /// The callout above the marker - its details - was tapped.
    public static let detailsClicked = ElementEvent<Self, Void>("detailsClicked", layer: .provider)

    /// What the marker stands for, which decides the icon the platform draws for
    /// it.
    public static let type = ElementProperty<Self, MarkerType>("type", layer: .provider)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        detailsClicked, label, location, selected, subtitle, type,
    ]
}
