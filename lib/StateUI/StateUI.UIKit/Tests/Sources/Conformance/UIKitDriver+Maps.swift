// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
import MapKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// A map and its markers as MapKit holds them: the region shown, the kind of map and what the user may do; a marker's
/// annotation and the marker MapKit drew for it; a tap on the map, a marker chosen, its details opened.
extension UIKitDriver {
    /// What MapKit's map holds of `property`; nil for what is not the map's.
    func mapHolds(_ property: Prop, _ map: UIKitMapView) -> HostValue? {
        switch property {
        case .region: map.shownRegion.propValue
        case .mapType: map.shownType.propValue
        case .showsTraffic: map.showsTrafficNow.propValue
        case .isScrollEnabled: map.isScrollEnabled.propValue
        case .isZoomEnabled: map.isZoomEnabled.propValue
        case .showsUserLocation: map.showsUserLocation.propValue
        default: nil
        }
    }

    /// What MapKit holds of a marker: its annotation's title, subtitle and place, and the kind its marker shows.
    func markerHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        let (map, pin) = try mapPin(element)
        switch property {
        case .label: return pin.title?.propValue
        case .subtitle: return pin.subtitle?.propValue
        case .location: return Location(latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude).propValue
        case .type:
            let tint = try marker(of: pin, on: map).markerTintColor
            let kinds: [MarkerType] = [.generic, .place, .saved, .searchResult]
            return kinds.first { UIKitMapMarker.look(of: $0).tint == tint }?.propValue
        default: throw DriverCannot("read \(property.name) of a Marker")
        }
    }

    /// Chooses a marker as a tap on its marker does, or opens its details as a tap on its callout's button does.
    func performOnMarker(_ act: UserAct, _ element: MountedElement) throws {
        let (map, pin) = try mapPin(element)
        switch act {
        case .activate: map.selectAnnotation(pin, animated: false)
        case .open:
            let marker = try marker(of: pin, on: map)
            guard let details = marker.rightCalloutAccessoryView as? UIControl else {
                throw DriverCannot("open the details of a pin whose callout has no button")
            }
            map.mapView(map, annotationView: marker, calloutAccessoryControlTapped: details)
        default: throw DriverCannot(act, on: element)
        }
    }

    /// The map a marker stands on, and MapKit's annotation for it.
    private func mapPin(_ element: MountedElement) throws -> (UIKitMapView, UIKitMapMarker) {
        guard let renderer, let map = (element.parent?.native as? UIKitElement)?.view as? UIKitMapView,
              let pin = map.pin(of: ChildElement(element.asChild(in: renderer.runtime)))
        else { throw DriverCannot("find a Marker on its map") }
        return (map, pin)
    }

    /// The marker MapKit drew for `marker`.
    private func marker(of pin: UIKitMapMarker, on map: UIKitMapView) throws -> MKMarkerAnnotationView {
        for _ in 0..<50 where map.view(for: pin) == nil { step() }
        guard let marker = map.view(for: pin) as? MKMarkerAnnotationView else {
            throw DriverCannot("read the marker of a pin MapKit has not drawn")
        }
        return marker
    }
}
#endif
