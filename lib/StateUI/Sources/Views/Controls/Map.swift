// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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
    public func pins(@ViewBuilder _ content: () -> [Element]) -> Self {
        var copy = self

        // The pins go before the context menu's slot, which stays last.
        // Design: docs/design/views/modifiers.md#slot-children
        copy.node.children.removeAll { $0.type == .pin }
        let slots = copy.node.children.filter { $0.type == .contextMenu }
        copy.node.children.removeAll { $0.type == .contextMenu }
        copy.node.children += content().map { $0.body } + slots

        return copy
    }

    // MARK: Events

    /// Fires when the map itself is tapped - not a pin - with where.
    public func onMapClicked(_ handler: @escaping ValueEventHandler<Location>) -> Self {
        onEvent(MapContract.mapClicked, handler)
    }
}

/// A pin on the map.
///
///     Pin("Royal Castle")
///         .address("Plac Zamkowy 4")
///         .location(latitude: 52.2479, longitude: 21.0155)
///
/// Tapping the pin shows its label and address in the platform's own
/// callout; `.onPinClicked` is the tap on the pin, `.onPinDetailsClicked`
/// the tap on that callout - its details.
public struct Pin: Element {
    /// The node this pin describes.
    public var node: Node

    /// A pin labelled `label` - what the callout shows in bold. Give it a
    /// `.location`, or it stands at zero-zero in the Atlantic.
    public init(_ label: String) {
        node = Node(contract: PinContract.self)
        node.write(PinContract.label, label)
    }

    /// The node, as every element answers it.
    public var body: Node { node }

    /// The callout's first line, in bold. The initializer takes the same
    /// value and is where a pin usually gets it.
    public func label(_ value: String) -> Self {
        var copy = self
        copy.node.write(PinContract.label, value)
        return copy
    }

    /// The line under the label in the callout.
    public func address(_ value: String) -> Self {
        var copy = self
        copy.node.write(PinContract.address, value)
        return copy
    }

    /// What the pin stands for, which is what decides the icon the platform
    /// draws for it.
    public func type(_ value: PinType) -> Self {
        var copy = self
        copy.node.write(PinContract.type, value)
        return copy
    }

    /// Where it stands.
    public func location(latitude: Double, longitude: Double) -> Self {
        var copy = self
        copy.node.write(PinContract.location, Location(latitude: latitude, longitude: longitude))
        return copy
    }

    /// Fires when the pin is tapped. Observing only: it cannot keep the
    /// callout shut.
    public func onPinClicked(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.node.addHandler(PinContract.pinClicked.token, handler)
        return copy
    }

    /// Fires when the callout above the pin - its details - is tapped: the
    /// place a navigation usually goes.
    public func onPinDetailsClicked(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.node.addHandler(PinContract.pinDetailsClicked.token, handler)
        return copy
    }
}

/// How the world is drawn.
public enum MapType: Int32, Sendable, HostRepresentable {
    /// Roads and their names - the default.
    case street = 0

    /// Photography from above, no names on it.
    case satellite = 1

    /// The photography with the roads drawn over it.
    case hybrid = 2
}

/// A point on the world, as an event reports one - the two values every map
/// answer carries.
public struct Location: Equatable, Sendable, HostRepresentable {
    /// Degrees north of the equator, negative south of it.
    public var latitude: Double

    /// Degrees east of Greenwich, negative west of it.
    public var longitude: Double

    /// A place, by its two coordinates.
    ///
    /// - Parameter latitude: degrees north of the equator, negative south.
    /// - Parameter longitude: degrees east of Greenwich, negative west.
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// The pair it crosses as - one `numbers` value, latitude then longitude.
    public var propValue: PropValue { .numbers([latitude, longitude]) }

    /// A place back from its pair - nil for anything else, so a report that
    /// will not read leaves the handler alone.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let pair = propValue.numbers, pair.count == 2 else { return nil }

        self.latitude = pair[0]
        self.longitude = pair[1]
    }
}

/// The part of the world a map shows: the region around a point.
///
///     Map(latitude: 52.2479, longitude: 21.0155, radiusMeters: 1500)
///
/// It crosses as its three numbers - latitude, longitude, and the radius in
/// meters.
public struct MapRegion: Equatable, Sendable, HostRepresentable {
    /// Degrees north of the equator, negative south of it.
    public var latitude: Double

    /// Degrees east of Greenwich, negative west of it.
    public var longitude: Double

    /// Half the width of what is shown, in meters.
    public var radiusMeters: Double

    /// A region, by its centre and its radius.
    ///
    /// - Parameters:
    ///   - latitude: degrees north of the equator, negative south.
    ///   - longitude: degrees east of Greenwich, negative west.
    ///   - radiusMeters: half the width of what is shown, in meters.
    public init(latitude: Double, longitude: Double, radiusMeters: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
    }

    /// Its three numbers, in order.
    public var propValue: PropValue { .numbers([latitude, longitude, radiusMeters]) }

    /// A region back from its three numbers - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let numbers = propValue.numbers, numbers.count == 3 else { return nil }

        self.init(latitude: numbers[0], longitude: numbers[1], radiusMeters: numbers[2])
    }
}

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

// A map's kind is a choice a property can be handed as `$x` - see StateChoice.
extension MapType: StateChoice {}
