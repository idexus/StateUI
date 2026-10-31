// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
import MapKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple

/// A Map on UIKit: the map Apple's hosts share, its tap heard by a recognizer beside MapKit's own, a marker's callout
/// showing the platform's details disclosure, a marker dressed in UIKit's colors.
/// Design: docs/design/platforms/apple/maps.md#a-map
@MainActor
final class UIKitMapView: MapKitView {
    /// Whether a tap is the map's: a delegate of its own, as the map answers MapKit's own recognizers.
    /// Design: docs/design/host/maps.md#a-tap-on-the-map
    private let taps = UIKitMapTaps()

    override init() {
        super.init()
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

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        clicked(at: recognizer.location(in: self))
    }

    override func dressCallout(_ marker: MKMarkerAnnotationView, of pin: MapKitMarker) {
        marker.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
    }

    @objc func mapView(
        _ map: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl
    ) {
        (view.annotation as? MapKitMarker)?.child.reports.raise(MarkerContract.detailsClicked)
    }

    override func dress(_ marker: MKMarkerAnnotationView, as type: MarkerType) {
        let look = MarkerLook(type)
        marker.markerTintColor = Self.tint(look.hue)
        marker.glyphImage = look.sfSymbol.flatMap { UIImage(systemName: $0) }
    }

    /// The platform's own color of a marker's hue.
    static func tint(_ hue: MarkerLook.Hue) -> UIColor {
        switch hue {
        case .red: .systemRed
        case .blue: .systemBlue
        case .yellow: .systemYellow
        case .purple: .systemPurple
        }
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

    /// A tap waits for a double tap - MapKit's zoom - to fail: a double tap is no two taps on the map.
    func gestureRecognizer(
        _ recognizer: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer
    ) -> Bool {
        (other as? UITapGestureRecognizer).map { $0.numberOfTapsRequired > 1 } ?? false
    }
}
#endif
