// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Map's own properties - the half a `Style<Map>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol MapProperties: PropertyContainer {}

extension MapProperties {
    /// How the world is drawn - streets, satellite photography, or both.
    public func mapType(_ value: MapType) -> Modified {
        setValue(.mapType, value.propValue)
    }

    /// Whether a drag pans it.
    public func isScrollEnabled(_ value: Bool) -> Modified {
        setValue(.isScrollEnabled, .bool(value))
    }

    /// Whether a pinch zooms it.
    public func isZoomEnabled(_ value: Bool) -> Modified {
        setValue(.isZoomEnabled, .bool(value))
    }

    /// Whether the roads are coloured by traffic.
    public func isTrafficEnabled(_ value: Bool) -> Modified {
        setValue(.isTrafficEnabled, .bool(value))
    }

    /// Whether the reader's own position is drawn on it - and the PLATFORM's
    /// location permission is the price: on iOS an app without
    /// `NSLocationWhenInUseUsageDescription` in its Info.plist is killed the
    /// moment this turns on, and Android needs the location permission
    /// granted. The map itself needs none of that.
    public func showsUserLocation(_ value: Bool) -> Modified {
        setValue(.showsUserLocation, .bool(value))
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
/// The map PANS, so it wants room of its own - a grid row, a page that holds
/// still - rather than a seat inside a ScrollView, the rule every gesture
/// follows.
///
/// Where it looks is an ACT rather than a property: declare an
/// `@Aim(Map.self)`, put it on the map with `.aim(_:)`, then call
/// `map.moveToRegion(latitude:longitude:radiusMeters:)`. Where it OPENS is the
/// initializer below, which is not the same thing.
///
/// What draws it is the platform's own map - MapKit on Apple platforms, a map
/// provider elsewhere - and that costs two things the doc of nothing else here
/// has to say: where the provider is Google Maps, an Android app needs a
/// Google Maps API key in its manifest (`com.google.android.geo.API_KEY`;
/// without one the map stays a grey grid), and a host with no map provider
/// shows its unsupported-control marker where the map belongs.
public struct Map: View, MapProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Map>` is written against.
    public init() {
        node = Node(type: .map)
    }

    /// A map opening on the region around a point.
    ///
    ///     Map(latitude: 52.2479, longitude: 21.0155, radiusMeters: 1500)
    ///
    /// Where a map OPENS belongs here rather than in an act from `.onCreated`:
    /// a region given here is kept by the host and applied once the
    /// platform's map is ready, while the same act lands an instant after the
    /// native map exists and the platform's own opening region overwrites it.
    /// Moving LATER is the act -
    /// `map.moveToRegion(latitude:longitude:radiusMeters:)`.
    ///
    /// - Parameter radiusMeters: Half the width of what is shown, in METERS -
    ///   a plain number, its unit in its name.
    public init(latitude: Double, longitude: Double, radiusMeters: Double) {
        node = Node(type: .map, props: [
            .region: .numbers([latitude, longitude, radiusMeters]),
        ])
    }

    // MARK: Properties

    // MARK: The pins

    /// The pins on it, replacing whatever was pinned before.
    ///
    /// A `Pin` is not a view - a label, an address and a point, nothing to lay
    /// out - so it takes none of the modifiers a view has and belongs here and
    /// nowhere else.
    public func pins(@ViewBuilder _ content: () -> [Element]) -> Self {
        var copy = self

        // The slot a `.contextMenu` appended stays LAST, the rule every
        // slot-carrying list follows - so the pins go in front of it.
        copy.node.children.removeAll { $0.type == .pin }
        let slots = copy.node.children.filter { $0.type == .contextMenu }
        copy.node.children.removeAll { $0.type == .contextMenu }
        copy.node.children += content().map { $0.body } + slots

        return copy
    }

    // MARK: Events

    /// Fires when the map itself is tapped - not a pin - with where.
    public func onMapClicked(_ handler: @escaping ValueEventHandler<Location>) -> Self {
        addHandler(.mapClicked) {
            guard let location = Location(EventBuffer.current.value()) else { return }
            try await handler(location)
        }
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
        node = Node(type: .pin, props: [.label: .string(label)])
    }

    /// The node, as every element answers it.
    public var body: Node { node }

    /// The callout's first line, in bold. The initializer takes the same
    /// value and is where a pin usually gets it.
    public func label(_ value: String) -> Self {
        var copy = self
        copy.node.props[.label] = .string(value)
        return copy
    }

    /// The line under the label in the callout.
    public func address(_ value: String) -> Self {
        var copy = self
        copy.node.props[.address] = .string(value)
        return copy
    }

    /// What the pin stands for, which is what decides the icon the platform
    /// draws for it.
    public func type(_ value: PinType) -> Self {
        var copy = self
        copy.node.props[.type] = value.propValue
        return copy
    }

    /// Where it stands.
    public func location(latitude: Double, longitude: Double) -> Self {
        var copy = self
        copy.node.props[.location] = .numbers([latitude, longitude])
        return copy
    }

    /// Fires when the pin is tapped. OBSERVING only: a handler here runs a
    /// boundary away, after the platform has already decided whether the
    /// callout opens, so it cannot keep the callout shut.
    public func onPinClicked(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.node.addHandler(.pinClicked, handler)
        return copy
    }

    /// Fires when the callout above the pin - its details - is tapped: the
    /// place a navigation usually goes.
    public func onPinDetailsClicked(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.node.addHandler(.pinDetailsClicked, handler)
        return copy
    }
}

/// How the world is drawn. Its numbers are this wire's own - the rule at the
/// head of Types/Enums.swift, which every closed vocabulary on this wire
/// follows.
public enum MapType: Int32, Sendable {
    /// Roads and their names - the default.
    case street = 0

    /// Photography from above, no names on it.
    case satellite = 1

    /// The photography with the roads drawn over it.
    case hybrid = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// A point on the world, as an event reports one - the two values every map
/// answer carries.
public struct Location: Equatable, Sendable {
    /// Degrees north of the equator, negative south of it.
    public var latitude: Double

    /// Degrees east of Greenwich, negative west of it.
    public var longitude: Double

    /// A place, by its two coordinates.
    ///
    /// The map hands one of these to `onMapClicked`; this is how an author
    /// makes one of their own - a saved place, a test's expectation - so the
    /// type reads the same in both directions.
    ///
    /// - Parameter latitude: degrees north of the equator, negative south.
    /// - Parameter longitude: degrees east of Greenwich, negative west.
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Reads the pair a payload carries - one `numbers` value, latitude then
    /// longitude. Nil for anything else, so a report that will not read
    /// leaves the handler alone.
    init?(_ value: PropValue?) {
        guard let pair = value?.numbers, pair.count == 2 else { return nil }

        self.latitude = pair[0]
        self.longitude = pair[1]
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
    /// For moving a map that is already up. Where one OPENS is
    /// `Map(latitude:longitude:radiusMeters:)`, not this act from `.onCreated`:
    /// that lands an instant after the native map exists and the platform's
    /// own opening region overwrites it.
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
        try await stateUICall(.moveToRegion, [
            try target, .number(latitude), .number(longitude), .number(radiusMeters),
        ])
    }
}

// A map's kind is a choice a property can be handed as `$x` - see StateChoice.
extension MapType: StateChoice {}
