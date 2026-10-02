// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import MapKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Map: MapKit's own map. It shows the region the tree gives it or an act slides it to, the kind of map and what
/// the user may do with it, and its pins as MapKit's markers; a click on the map itself is heard where it fell, a
/// click on a pin or on its details on the pin.
/// Design: docs/design/host/maps.md
@MainActor
final class AppKitMapView: MKMapView, MKMapViewDelegate {
    /// What the view does when the user clicks the map itself, not a pin, at a place.
    var onClicked: ((Location) -> Void)?

    /// The pins shown, each kept by its child for as long as it lives.
    private var pins: [ChildElement<PinContract>: AppKitMapPin] = [:]

    /// Whether a click is the map's: a delegate of its own, as the map answers MapKit's own recognizers.
    /// Design: docs/design/host/maps.md#a-tap-on-the-map
    private let clicks = AppKitMapClicks()

    /// What asks the user, once, for leave to know where they are.
    private let locations = CLLocationManager()

    private static let marker = "pin"

    init() {
        super.init(frame: .zero)
        delegate = self
        register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Self.marker)
        let click = NSClickGestureRecognizer(target: self, action: #selector(clicked(_:)))
        clicks.map = self
        click.delegate = clicks
        click.delaysPrimaryMouseButtonEvents = false
        addGestureRecognizer(click)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitMapView is made in code")
    }

    // MARK: - What the tree says

    /// Shows `region`, sliding to it where `sliding`: the circle its shorter side spans.
    func show(_ region: MapRegion, sliding: Bool) {
        let side = MapFraming.side(of: region)
        let center = CLLocationCoordinate2D(latitude: region.latitude, longitude: region.longitude)
        setRegion(MKCoordinateRegion(center: center, latitudinalMeters: side, longitudinalMeters: side), animated: sliding)
    }

    /// Draws the world as `type` says, the roads coloured by traffic where `traffic` and the map has roads.
    func style(_ type: MapType, traffic: Bool) {
        switch type {
        case .street:
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
    func showUser(_ on: Bool) {
        if on, locations.authorizationStatus == .notDetermined { locations.requestWhenInUseAuthorization() }
        showsUserLocation = on
    }

    /// Shows `children` as markers: one kept for each child for as long as it lives, its values taken again.
    func show(_ children: [ChildElement<PinContract>]) {
        let kept = Set(children)
        for (child, pin) in pins where !kept.contains(child) {
            removeAnnotation(pin)
            pins[child] = nil
        }
        for child in children {
            if let pin = pins[child] {
                pin.take()
                if let marker = view(for: pin) as? MKMarkerAnnotationView { Self.dress(marker, as: pin.type) }
            } else {
                let pin = AppKitMapPin(child)
                pin.take()
                pins[child] = pin
                addAnnotation(pin)
            }
        }
    }

    // MARK: - What the map shows

    /// The region shown: the circle its shorter side holds.
    var shownRegion: MapRegion {
        let rect = visibleMapRect
        let width = MKMapPoint(x: rect.minX, y: rect.midY).distance(to: MKMapPoint(x: rect.maxX, y: rect.midY))
        let height = MKMapPoint(x: rect.midX, y: rect.minY).distance(to: MKMapPoint(x: rect.midX, y: rect.maxY))
        return MapFraming.region(
            latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude, width: width, height: height)
    }

    /// The kind of map drawn.
    var shownType: MapType {
        switch preferredConfiguration {
        case is MKImageryMapConfiguration: .satellite
        case is MKHybridMapConfiguration: .hybrid
        default: .street
        }
    }

    /// Whether the roads are coloured by traffic.
    var showsTrafficNow: Bool {
        switch preferredConfiguration {
        case let standard as MKStandardMapConfiguration: standard.showsTraffic
        case let hybrid as MKHybridMapConfiguration: hybrid.showsTraffic
        default: false
        }
    }

    /// The pin MapKit holds for `child`.
    func pin(of child: ChildElement<PinContract>) -> AppKitMapPin? {
        pins[child]
    }

    // MARK: - What the user does

    @objc private func clicked(_ recognizer: NSClickGestureRecognizer) {
        click(at: recognizer.location(in: self))
    }

    /// A click on the map at `point` of the view, heard as the place it fell on.
    func click(at point: NSPoint) {
        let place = convert(point, toCoordinateFrom: self)
        onClicked?(Location(latitude: place.latitude, longitude: place.longitude))
    }

    func mapView(_ map: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        guard let pin = annotation as? AppKitMapPin,
              let marker = map.dequeueReusableAnnotationView(withIdentifier: Self.marker, for: pin)
                as? MKMarkerAnnotationView
        else { return nil }
        marker.canShowCallout = true
        let details = AppKitPinDetailsButton(
            image: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Details") ?? NSImage(),
            target: self, action: #selector(detailsClicked(_:)))
        details.isBordered = false
        details.pin = pin
        marker.rightCalloutAccessoryView = details
        Self.dress(marker, as: pin.type)
        return marker
    }

    func mapView(_ map: MKMapView, didSelect view: MKAnnotationView) {
        (view.annotation as? AppKitMapPin)?.child.reports.raise(PinContract.pinClicked)
    }

    @objc private func detailsClicked(_ button: AppKitPinDetailsButton) {
        button.pin?.child.reports.raise(PinContract.pinDetailsClicked)
    }

    /// Gives `marker` the colour and symbol of a pin's kind.
    static func dress(_ marker: MKMarkerAnnotationView, as type: PinType) {
        let look = AppKitMapPin.look(of: type)
        marker.markerTintColor = look.tint
        marker.glyphImage = look.symbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
    }
}

/// Whether a click is the map's own: one on a pin, or on what a pin opened, is the pin's.
@MainActor
private final class AppKitMapClicks: NSObject, NSGestureRecognizerDelegate {
    weak var map: AppKitMapView?

    func gestureRecognizer(_ recognizer: NSGestureRecognizer, shouldAttemptToRecognizeWith event: NSEvent) -> Bool {
        guard let map, let point = map.superview?.convert(event.locationInWindow, from: nil) else { return true }
        var view = map.hitTest(point)
        while let each = view, each !== map {
            if each is MKAnnotationView || each is NSControl { return false }
            view = each.superview
        }
        return true
    }
}
#endif
