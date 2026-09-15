// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A map of the world, with pins on it.
public enum MapContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .map

    /// An optional provider supplies it; no base host has to.
    public static let layer: ElementLayer = .provider

    /// A map is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// Whether a drag pans it.
    public static let isScrollEnabled = ElementProperty<Self, Bool>("isScrollEnabled", layer: .native)

    /// Whether the roads are coloured by traffic.
    public static let isTrafficEnabled = ElementProperty<Self, Bool>("isTrafficEnabled", layer: .provider)

    /// Whether a pinch zooms it.
    public static let isZoomEnabled = ElementProperty<Self, Bool>("isZoomEnabled", layer: .provider)

    /// The map itself was tapped - not a pin - at a place.
    public static let mapClicked = ElementEvent<Self, Location>("mapClicked", layer: .provider)

    /// How the world is drawn - streets, photography from above, or both.
    public static let mapType = ElementProperty<Self, MapType>("mapType", layer: .provider)

    /// Slides the map until it shows the region around a point: latitude,
    /// longitude, and the radius in meters.
    public static let moveToRegion = ElementAct<Self, (Double, Double, Double), Void>("moveToRegion")

    /// The region the map opens on.
    public static let region = ElementProperty<Self, MapRegion>(
        "region", layer: .provider, travels: false, cleared: false)

    /// Whether the reader's own position is drawn on it.
    public static let showsUserLocation = ElementProperty<Self, Bool>("showsUserLocation", layer: .provider)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        isScrollEnabled, isTrafficEnabled, isZoomEnabled, mapClicked, mapType, moveToRegion, region,
        showsUserLocation,
    ]
}
