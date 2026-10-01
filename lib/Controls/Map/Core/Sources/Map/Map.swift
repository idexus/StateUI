// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// `Map`'s own properties, shared by the control and its `Style<Map>`.
public protocol MapProperties: PropertyContainer {}

extension MapProperties {
    /// How the world is drawn - streets, satellite photography, or both.
    public func mapType(_ value: MapType) -> Modified {
        setValue(MapContract.mapType, value)
    }

    /// Whether a drag pans it.
    public func isScrollEnabled(_ value: Bool) -> Modified {
        setValue(MapContract.isScrollEnabled, value)
    }

    /// Whether a pinch zooms it.
    public func isZoomEnabled(_ value: Bool) -> Modified {
        setValue(MapContract.isZoomEnabled, value)
    }

    /// Whether the roads are coloured by traffic.
    public func isTrafficEnabled(_ value: Bool) -> Modified {
        setValue(MapContract.isTrafficEnabled, value)
    }

    /// Whether the user's own position is drawn on it. That needs the
    /// platform's location permission: on iOS an app without
    /// `NSLocationWhenInUseUsageDescription` in its Info.plist is killed the
    /// moment this turns on, and Android needs the permission granted.
    public func showsUserLocation(_ value: Bool) -> Modified {
        setValue(MapContract.showsUserLocation, value)
    }
}

/// A map of the world, with pins on it.
///
///     Map()
///         .pins {
///             Pin("Royal Castle")
///                 .address("Plac Zamkowy 4")
///                 .location(latitude: 52.2479, longitude: 21.0155)
///                 .onPinClicked { chosen = "castle" }
///         }
///
/// The map pans, so give it room of its own - a grid row, a page that holds
/// still - rather than a place inside a ScrollView.
///
/// Where it looks is an act: put an `@Aim(Map.self)` on it with `.aim(_:)` and
/// call `map.moveToRegion(latitude:longitude:radiusMeters:)`. Where it opens
/// is the initializer below.
///
/// The platform's own map draws it. Where that is Google Maps, an Android app
/// needs an API key in its manifest (`com.google.android.geo.API_KEY`) or the
/// map stays a grey grid; a host with no map provider shows its
/// unsupported-control marker instead.
public struct Map: View, MapProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Map>` is written against.
    public init() {
        node = Node(contract: MapContract.self)
    }

    /// A map opening on the region around a point.
    ///
    ///     Map(latitude: 52.2479, longitude: 21.0155, radiusMeters: 1500)
    ///
    /// Where a map opens belongs here, not in an act from `.onCreated`, which
    /// the platform's own opening region overwrites. Moving later is the act,
    /// `map.moveToRegion(latitude:longitude:radiusMeters:)`.
    ///
    /// - Parameter radiusMeters: Half the width of what is shown, in METERS -
    ///   a plain number, its unit in its name.
    public init(latitude: Double, longitude: Double, radiusMeters: Double) {
        node = Node(contract: MapContract.self)
        node.write(MapContract.region, MapRegion(latitude: latitude, longitude: longitude, radiusMeters: radiusMeters))
    }

    // MARK: The pins

    /// The pins on it, replacing whatever was pinned before. A `Pin` is not a
    /// view, and goes here and nowhere else.
    public func pins(@PinBuilder _ content: () -> [Pin]) -> Self {
        var copy = self

        // The pins go before the context menu's slot, which stays last.
        // Design: docs/design/views/modifiers.md#slot-children
        copy.node.children.removeAll { $0.type == PinContract.nodeType }
        let slots = copy.node.children.filter { $0.type == ContextMenuContract.nodeType }
        copy.node.children.removeAll { $0.type == ContextMenuContract.nodeType }
        copy.node.children += content().map { $0.body } + slots

        return copy
    }

    // MARK: Events

    /// Fires when the map itself is tapped - not a pin - with where.
    public func onMapClicked(_ handler: @escaping ValueEventHandler<Location>) -> Self {
        onEvent(MapContract.mapClicked, handler)
    }
}

// MARK: - A style written for it

extension Map: StyleTarget {}

extension StyleBag: MapProperties where Target == Map {}

// MARK: - The acts

extension Aim where Target == Map {
    /// Slides the map until it shows the region around a point.
    ///
    ///     @Aim(Map.self) private var map
    ///
    ///     Map(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
    ///         .aim(map)
    ///
    ///     Button("Old Town").onClicked {
    ///         try await map.moveToRegion(
    ///             latitude: 52.2497, longitude: 21.0135, radiusMeters: 800)
    ///     }
    ///
    /// For moving a map that is already up; where one opens is
    /// `Map(latitude:longitude:radiusMeters:)`.
    ///
    /// - Parameter radiusMeters: Half the width of what is shown, in METERS -
    ///   a plain number, its unit in its name.
    /// - Throws: `StateUIError` when no view of that id is being shown, or
    ///   the view it names is not a Map.
    public nonisolated(nonsending) func moveToRegion(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double
    ) async throws {
        try await call(MapContract.moveToRegion, latitude, longitude, radiusMeters)
    }
}
