// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import MapKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple

/// A Map on AppKit: the map Apple's hosts share, its click heard by a recognizer beside MapKit's own, a marker's
/// callout showing a details button, a marker dressed in AppKit's colors.
/// Design: docs/design/platforms/apple/maps.md#a-map
@MainActor
final class AppKitMapView: MapKitView {
    /// Whether a click is the map's: a delegate of its own, as the map answers MapKit's own recognizers.
    /// Design: docs/design/host/maps.md#a-tap-on-the-map
    private let clicks = AppKitMapClicks()

    override init() {
        super.init()
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

    @objc private func clicked(_ recognizer: NSClickGestureRecognizer) {
        clicked(at: recognizer.location(in: self))
    }

    override func dressCallout(_ marker: MKMarkerAnnotationView, of pin: MapKitMarker) {
        let details = AppKitPinDetailsButton(
            image: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Details") ?? NSImage(),
            target: self, action: #selector(detailsClicked(_:)))
        details.isBordered = false
        details.pin = pin
        marker.rightCalloutAccessoryView = details
    }

    @objc private func detailsClicked(_ button: AppKitPinDetailsButton) {
        button.pin?.child.reports.raise(MarkerContract.detailsClicked)
    }

    override func dress(_ marker: MKMarkerAnnotationView, as type: MarkerType) {
        let look = MarkerLook(type)
        marker.markerTintColor = Self.tint(look.hue)
        marker.glyphImage = look.sfSymbol.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
    }

    /// The platform's own color of a marker's hue.
    static func tint(_ hue: MarkerLook.Hue) -> NSColor {
        switch hue {
        case .red: .systemRed
        case .blue: .systemBlue
        case .yellow: .systemYellow
        case .purple: .systemPurple
        }
    }
}

/// Whether a click is the map's own: one on a marker, or on what a marker opened, is the marker's.
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
