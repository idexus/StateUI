// MAUI: Map and Pin - Microsoft.Maui.Controls.Maps.

/// Map's own properties - the half a `Style<Map>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol MapProperties: PropertyContainer {}

extension MapProperties {
    /// How the world is drawn - streets, satellite photography, or both.
    /// MAUI: Map.MapType.
    public func mapType(_ value: MapType) -> Modified {
        setValue(.mapType, value.propValue)
    }

    /// Whether a drag pans it. MAUI: Map.IsScrollEnabled.
    public func isScrollEnabled(_ value: Bool) -> Modified {
        setValue(.isScrollEnabled, .bool(value))
    }

    /// Whether a pinch zooms it. MAUI: Map.IsZoomEnabled.
    public func isZoomEnabled(_ value: Bool) -> Modified {
        setValue(.isZoomEnabled, .bool(value))
    }

    /// Whether the roads are coloured by traffic. MAUI: Map.IsTrafficEnabled.
    public func isTrafficEnabled(_ value: Bool) -> Modified {
        setValue(.isTrafficEnabled, .bool(value))
    }

    /// Whether the reader's own position is drawn on it. MAUI:
    /// Map.IsShowingUser - and the PLATFORM's location permission is the
    /// price: on iOS an app without `NSLocationWhenInUseUsageDescription` in
    /// its Info.plist is killed the moment this turns on, and Android needs
    /// the location permission granted. The map itself needs none of that.
    public func isShowingUser(_ value: Bool) -> Modified {
        setValue(.isShowingUser, .bool(value))
    }
}

/// A map of the world, with pins on it.
///
///     Map()
///         .pins {
///             Pin("Royal Castle")
///                 .address("Plac Zamkowy 4")
///                 .location(latitude: 52.2479, longitude: 21.0155)
///                 .onMarkerClicked { chosen = "castle" }
///         }
///
/// The map PANS, so it wants room of its own - a grid row, a page that holds
/// still - rather than a seat inside a ScrollView, the rule every gesture
/// follows.
///
/// Where it looks is an ACT rather than a property, because MAUI's
/// `MoveToRegion` is a method: hold the map in a `ControlState<Map>` with
/// `.assign`, then call `map.moveToRegion(latitude:longitude:radiusMeters:)`.
/// Where it OPENS is the initializer below, which is not the same thing.
///
/// What draws it is the platform's own map - MapKit on iOS and Mac Catalyst,
/// Google Maps on Android - and that costs three things the doc of nothing
/// else here has to say: the application registers the handler itself with
/// `builder.UseMauiMaps()` in MauiProgram, an Android app also needs a Google
/// Maps API key in its manifest (`com.google.android.geo.API_KEY`; without
/// one the map stays a grey grid), and Windows has no Map handler at all, so
/// a Map there renders as the unknown-control marker.
public struct Map: View, MapProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Map>` is written against.
    public init() {
        node = Node(type: .map)
    }

    /// A map opening on the region around a point. MAUI: Map(MapSpan), the
    /// span built with `MapSpan.FromCenterAndRadius`.
    ///
    ///     Map(latitude: 52.2479, longitude: 21.0155, radiusMeters: 1500)
    ///
    /// Where a map OPENS belongs here rather than in an act from `.onLoaded`,
    /// and the difference is measured on Mac Catalyst: a region given while
    /// the platform's map is still connecting is kept by MAUI and applied at
    /// the right moment, while the same act lands an instant after the handler
    /// exists and the platform's own opening region overwrites it. Moving
    /// LATER is the act - `map.moveToRegion(latitude:longitude:radiusMeters:)`.
    ///
    /// - Parameter radiusMeters: Half the width of what is shown, in METERS -
    ///   MAUI's `Distance` is meters at bottom, so no unit is invented here.
    public init(latitude: Double, longitude: Double, radiusMeters: Double) {
        node = Node(type: .map, props: [
            .region: .numbers([latitude, longitude, radiusMeters]),
        ])
    }

    // MARK: Properties

    // MARK: The pins

    /// The markers on it, replacing whatever was pinned before. MAUI: Map.Pins.
    ///
    /// A `Pin` is not a view - a label, an address and a point, nothing to lay
    /// out - so it takes none of the modifiers a view has and belongs here and
    /// nowhere else.
    public func pins(@ViewBuilder _ content: () -> [Element]) -> Self {
        var copy = self

        // The slot a `.contextFlyout` appended stays LAST, the rule every
        // slot-carrying list follows - so the pins go in front of it.
        copy.node.children.removeAll { $0.type == .pin }
        let slots = copy.node.children.filter { $0.type == .contextFlyout }
        copy.node.children.removeAll { $0.type == .contextFlyout }
        copy.node.children += content().map { $0.body } + slots

        return copy
    }

    // MARK: Events

    /// Fires when the map itself is tapped - not a pin - with where. MAUI:
    /// Map.MapClicked.
    public func onMapClicked(_ handler: @escaping ValueEventHandler<Location>) -> Self {
        addHandler(.mapClicked) {
            guard let location = Location(EventBuffer.current.value()) else { return }
            try await handler(location)
        }
    }
}

/// A marker on the map. MAUI: Pin.
///
///     Pin("Royal Castle")
///         .address("Plac Zamkowy 4")
///         .location(latitude: 52.2479, longitude: 21.0155)
///
/// Tapping the marker shows its label and address in the platform's own
/// callout; `.onMarkerClicked` is the tap on the marker, `.onInfoWindowClicked`
/// the tap on that callout.
public struct Pin: Element {
    /// The node this pin describes.
    public var node: Node

    /// A pin labelled `label` - what the callout shows in bold. Give it a
    /// `.location`, or it stands at zero-zero in the Atlantic. MAUI: Pin.Label.
    public init(_ label: String) {
        node = Node(type: .pin, props: [.label: .string(label)])
    }

    /// The node, as every element answers it.
    public var body: Node { node }

    /// The callout's first line, in bold. The initializer takes the same
    /// value and is where a pin usually gets it. MAUI: Pin.Label.
    public func label(_ value: String) -> Self {
        var copy = self
        copy.node.props[.label] = .string(value)
        return copy
    }

    /// The line under the label in the callout. MAUI: Pin.Address.
    public func address(_ value: String) -> Self {
        var copy = self
        copy.node.props[.address] = .string(value)
        return copy
    }

    /// Where it stands. MAUI: Pin.Location.
    public func location(latitude: Double, longitude: Double) -> Self {
        var copy = self
        copy.node.props[.location] = .numbers([latitude, longitude])
        return copy
    }

    /// Fires when the marker is tapped. OBSERVING only: MAUI's event can keep
    /// the callout shut by setting `HideInfoWindow` before it returns, and a
    /// handler here runs a boundary away, after it has. MAUI: Pin.MarkerClicked.
    public func onMarkerClicked(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.node.addHandler(.markerClicked, handler)
        return copy
    }

    /// Fires when the callout above the marker is tapped - the place a
    /// navigation usually goes. MAUI: Pin.InfoWindowClicked.
    public func onInfoWindowClicked(_ handler: @escaping EventHandler) -> Self {
        var copy = self
        copy.node.addHandler(.infoWindowClicked, handler)
        return copy
    }
}

/// How the world is drawn. MAUI: MapType, numbered here rather than there -
/// the rule at the head of Types/Enums.swift, which every closed vocabulary on
/// this wire follows.
public enum MapType: Int32, Sendable {
    /// Roads and their names - the default. MAUI: MapType.Street.
    case street = 0

    /// Photography from above, no names on it. MAUI: MapType.Satellite.
    case satellite = 1

    /// The photography with the roads drawn over it. MAUI: MapType.Hybrid.
    case hybrid = 2

    var propValue: PropValue { .enumeration(rawValue) }
}

/// A point on the world, as an event reports one. MAUI: Location
/// (Microsoft.Maui.Devices.Sensors), reduced to the two values every map
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

extension ControlState where Target == Map {
    /// Slides the map until it shows the region around a point. MAUI:
    /// Map.MoveToRegion, the span built with `MapSpan.FromCenterAndRadius`.
    ///
    ///     @State private var map = ControlState<Map>()
    ///
    ///     Map(latitude: 52.2297, longitude: 21.0122, radiusMeters: 3000)
    ///         .assign(map)
    ///
    ///     Button("Old Town").onClicked {
    ///         try await map.moveToRegion(
    ///             latitude: 52.2497, longitude: 21.0135, radiusMeters: 800)
    ///     }
    ///
    /// For moving a map that is already up. Where one OPENS is
    /// `Map(latitude:longitude:radiusMeters:)`, not this act from `.onLoaded`:
    /// that lands an instant after the handler exists and the platform's own
    /// opening region overwrites it. Measured on Mac Catalyst.
    ///
    /// - Parameter radiusMeters: Half the width of what is shown, in METERS -
    ///   MAUI's `Distance` is meters at bottom, so no unit is invented here.
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
