// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A map of the world, with markers on it.
public enum MapContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Map"

    /// An optional provider supplies it; no base host has to.
    public static let layer: ElementLayer = .provider

    /// A map is a view.
    public static let tiers: [any Tier.Type] = [ViewContract.self]

    /// Whether a drag pans it.
    public static let isScrollEnabled = ElementProperty<Self, Bool>("isScrollEnabled", layer: .native)

    /// Whether the roads are colored by traffic.
    public static let showsTraffic = ElementProperty<Self, Bool>("showsTraffic", layer: .provider)

    /// Whether a pinch zooms it.
    public static let isZoomEnabled = ElementProperty<Self, Bool>("isZoomEnabled", layer: .provider)

    /// The map itself was tapped - not a marker - at a place.
    public static let locationTapped = ElementEvent<Self, Location>("locationTapped", layer: .provider)

    /// Slides the map until it shows a region.
    public static let moveToRegion = ElementAct<Self, MapRegion, Void>("moveToRegion", layer: .provider)

    /// The region the map opens on.
    public static let region = ElementProperty<Self, MapRegion>(
        "region", layer: .provider, travels: false, cleared: false)

    /// Whether the user's own position is drawn on it.
    public static let showsUserLocation = ElementProperty<Self, Bool>("showsUserLocation", layer: .provider)

    /// How the world is drawn - streets, photography from above, or both.
    public static let kind = ElementProperty<Self, MapKind>("kind", layer: .provider)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        isScrollEnabled, showsTraffic, isZoomEnabled, locationTapped, moveToRegion, region,
        showsUserLocation, kind,
    ]
}
