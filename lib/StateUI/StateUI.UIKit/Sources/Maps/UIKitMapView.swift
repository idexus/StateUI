// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
import MapKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Map: MapKit's own map. It shows the region the tree gives it or an act slides it to, the kind of map and what
/// the user may do with it, and its markers as MapKit's markers; a tap on the map itself is heard where it fell, a tap
/// on a marker or on its details on the marker.
/// Design: docs/design/host/maps.md
@MainActor
final class UIKitMapView: MKMapView, MKMapViewDelegate {
    /// What the view does when the user taps the map itself, not a marker, at a place.
    var onTapped: ((Location) -> Void)?

    /// The markers shown, each kept by its child for as long as it lives.
    private var pins: [ChildElement<MarkerContract>: UIKitMapMarker] = [:]

    /// Whether a tap is the map's: a delegate of its own, as the map answers MapKit's own recognizers.
    /// Design: docs/design/host/maps.md#a-tap-on-the-map
    private let taps = UIKitMapTaps()

    /// What asks the user, once, for leave to know where they are.
    private let locations = CLLocationManager()

    private static let marker = "pin"

    init() {
        super.init(frame: .zero)
        delegate = self
        register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Self.marker)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        taps.map = self
        tap.delegate = taps
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitMapView is made in code")
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
    func showUser(_ on: Bool) {
        if on, locations.authorizationStatus == .notDetermined { locations.requestWhenInUseAuthorization() }
        showsUserLocation = on
    }

    /// Shows `children` as markers: one kept for each child for as long as it lives, its values taken again.
    func show(_ children: [ChildElement<MarkerContract>]) {
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
                let pin = UIKitMapMarker(child)
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
        default: .standard
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

    /// The marker MapKit holds for `child`.
    func pin(of child: ChildElement<MarkerContract>) -> UIKitMapMarker? {
        pins[child]
    }

    // MARK: - What the user does

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        tap(at: recognizer.location(in: self))
    }

    /// A tap on the map at `point` of the view, heard as the place it fell on.
    func tap(at point: CGPoint) {
        let place = convert(point, toCoordinateFrom: self)
        onTapped?(Location(latitude: place.latitude, longitude: place.longitude))
    }

    func mapView(_ map: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        guard let pin = annotation as? UIKitMapMarker,
              let marker = map.dequeueReusableAnnotationView(withIdentifier: Self.marker, for: pin)
                as? MKMarkerAnnotationView
        else { return nil }
        marker.canShowCallout = true
        marker.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        Self.dress(marker, as: pin.type)
        return marker
    }

    func mapView(_ map: MKMapView, didSelect view: MKAnnotationView) {
        (view.annotation as? UIKitMapMarker)?.child.reports.raise(MarkerContract.selected)
    }

    func mapView(_ map: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        (view.annotation as? UIKitMapMarker)?.child.reports.raise(MarkerContract.detailsClicked)
    }

    /// Gives `marker` the colour and symbol of a marker's kind.
    static func dress(_ marker: MKMarkerAnnotationView, as type: MarkerType) {
        let look = UIKitMapMarker.look(of: type)
        marker.markerTintColor = look.tint
        marker.glyphImage = look.symbol.flatMap { UIImage(systemName: $0) }
    }
}

/// Whether a tap is the map's own: one on a marker, or on what a marker opened, is the marker's; it is heard beside the map's
/// own recognizers.
@MainActor
private final class UIKitMapTaps: NSObject, UIGestureRecognizerDelegate {
    weak var map: UIKitMapView?

    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let each = view, each !== map {
            if each is MKAnnotationView || each is UIControl { return false }
            view = each.superview
        }
        return true
    }

    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
#endif
