// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import MapKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Map on Apple's platforms: MapKit's own map. It shows the region the tree gives it or an act slides it to, the
/// kind of map and what the user may do with it, and its markers as MapKit's markers; a click on the map itself is
/// heard where it fell, one on a marker on the marker. Each host's own map hears the user's click or tap, dresses a
/// marker in its platform's colours and gives its callout the details button the platform shows.
/// Design: docs/design/platforms/apple/maps.md#a-map
@_spi(Host) @MainActor
open class MapKitView: MKMapView, MKMapViewDelegate {
    /// What the view does when the user clicks or taps the map itself, not a marker, at a place.
    public var onClicked: ((Location) -> Void)?

    /// The markers shown, each kept by its child for as long as it lives.
    private var pins: [ChildElement<MarkerContract>: MapKitMarker] = [:]

    /// What asks the user, once, for leave to know where they are.
    private let locations = CLLocationManager()

    private static let marker = "pin"

    /// A map, its own delegate, its markers MapKit's.
    public init() {
        super.init(frame: .zero)
        delegate = self
        register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Self.marker)
    }

    /// Never made from an archive.
    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("MapKitView is made in code")
    }

    // MARK: - What the tree says

    /// Shows `region`, sliding to it where `sliding`: the circle its shorter side spans.
    public func show(_ region: MapRegion, sliding: Bool) {
        let side = MapFraming.side(of: region)
        let center = CLLocationCoordinate2D(latitude: region.center.latitude, longitude: region.center.longitude)
        setRegion(MKCoordinateRegion(center: center, latitudinalMeters: side, longitudinalMeters: side), animated: sliding)
    }

    /// Draws the world as `type` says, the roads coloured by traffic where `traffic` and the map has roads.
    public func style(_ type: MapType, traffic: Bool) {
        switch type {
        case .standard:
            let configuration = MKStandardMapConfiguration()
            configuration.showsTraffic = traffic
            preferredConfiguration = configuration
        case .satellite:
            preferredConfiguration = MKImageryMapConfiguration()
        case .hybrid:
            let configuration = MKHybridMapConfiguration()
            configuration.showsTraffic = traffic
            preferredConfiguration = configuration
        }
    }

    /// Draws the user's own position where `on`, asking the user first, once, for leave to know it.
    public func showUser(_ on: Bool) {
        if on, locations.authorizationStatus == .notDetermined { locations.requestWhenInUseAuthorization() }
        showsUserLocation = on
    }

    /// Shows `children` as markers: one kept for each child for as long as it lives, its values taken again.
    public func show(_ children: [ChildElement<MarkerContract>]) {
        let kept = Set(children)
        for (child, pin) in pins where !kept.contains(child) {
            removeAnnotation(pin)
            pins[child] = nil
        }
        for child in children {
            if let pin = pins[child] {
                pin.take()
                if let marker = view(for: pin) as? MKMarkerAnnotationView { dress(marker, as: pin.type) }
            } else {
                let pin = MapKitMarker(child)
                pin.take()
                pins[child] = pin
                addAnnotation(pin)
            }
        }
    }

    // MARK: - What the map shows

    /// The region shown: the circle its shorter side holds.
    public var shownRegion: MapRegion {
        let rect = visibleMapRect
        let width = MKMapPoint(x: rect.minX, y: rect.midY).distance(to: MKMapPoint(x: rect.maxX, y: rect.midY))
        let height = MKMapPoint(x: rect.midX, y: rect.minY).distance(to: MKMapPoint(x: rect.midX, y: rect.maxY))
        return MapFraming.region(
            center: Location(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude),
            width: width, height: height)
    }

    /// The kind of map drawn.
    public var shownType: MapType {
        switch preferredConfiguration {
        case is MKImageryMapConfiguration: .satellite
        case is MKHybridMapConfiguration: .hybrid
        default: .standard
        }
    }

    /// Whether the roads are coloured by traffic.
    public var showsTrafficNow: Bool {
        switch preferredConfiguration {
        case let standard as MKStandardMapConfiguration: standard.showsTraffic
        case let hybrid as MKHybridMapConfiguration: hybrid.showsTraffic
        default: false
        }
    }

    /// The marker MapKit holds for `child`.
    public func pin(of child: ChildElement<MarkerContract>) -> MapKitMarker? {
        pins[child]
    }

    // MARK: - What the user does

    /// A click or tap on the map at `point` of the view, heard as the place it fell on.
    public func clicked(at point: CGPoint) {
        let place = convert(point, toCoordinateFrom: self)
        onClicked?(Location(latitude: place.latitude, longitude: place.longitude))
    }

    /// The view MapKit shows for a marker: its callout, dressed as its kind says.
    public func mapView(_ map: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        guard let pin = annotation as? MapKitMarker,
              let marker = map.dequeueReusableAnnotationView(withIdentifier: Self.marker, for: pin)
                as? MKMarkerAnnotationView
        else { return nil }
        marker.canShowCallout = true
        dressCallout(marker, of: pin)
        dress(marker, as: pin.type)
        return marker
    }

    /// A marker the user chose: heard on it.
    public func mapView(_ map: MKMapView, didSelect view: MKAnnotationView) {
        (view.annotation as? MapKitMarker)?.child.reports.raise(MarkerContract.selected)
    }

    /// Gives `marker` the colour and symbol of a marker's kind (`MarkerLook`), as the platform draws them.
    open func dress(_ marker: MKMarkerAnnotationView, as type: MarkerType) {}

    /// Gives `marker`'s callout the details button the platform shows, whose click is heard on `pin`.
    open func dressCallout(_ marker: MKMarkerAnnotationView, of pin: MapKitMarker) {}
}
