// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import MapKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance

/// A map and its pins as MapKit holds them: the region shown, the kind of map and what the user may do; a pin's
/// annotation and the marker MapKit drew for it; a click on the map, a pin chosen, its details opened.
extension AppKitDriver {
    /// What MapKit's map holds of `property`; nil for what is not the map's.
    func mapHolds(_ property: Prop, _ map: AppKitMapView) -> HostValue? {
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

    /// What MapKit holds of a pin: its annotation's title, subtitle and place, and the kind its marker shows.
    func pinHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        let (map, pin) = try mapPin(element)
        switch property {
        case .label: return pin.title?.propValue
        case .address: return pin.subtitle?.propValue
        case .location: return Location(latitude: pin.coordinate.latitude, longitude: pin.coordinate.longitude).propValue
        case .type:
            let tint = try marker(of: pin, on: map).markerTintColor
            let kinds: [PinType] = [.generic, .place, .savedPin, .searchResult]
            return kinds.first { AppKitMapPin.look(of: $0).tint == tint }?.propValue
        default: throw DriverCannot("read \(property.name) of a Pin")
        }
    }

    /// Chooses a pin as a click on its marker does, or opens its details as a click on its callout's button does.
    func performOnPin(_ act: UserAct, _ element: MountedElement) throws {
        let (map, pin) = try mapPin(element)
        switch act {
        case .activate: map.selectAnnotation(pin, animated: false)
        case .open:
            guard let details = try marker(of: pin, on: map).rightCalloutAccessoryView as? NSButton else {
                throw DriverCannot("open the details of a pin whose callout has no button")
            }
            details.performClick(nil)
        default: throw DriverCannot(act, on: element)
        }
    }

    /// The map a pin stands on, and MapKit's annotation for it.
    private func mapPin(_ element: MountedElement) throws -> (AppKitMapView, AppKitMapPin) {
        guard let renderer, let map = (element.parent?.native as? AppKitElement)?.view as? AppKitMapView,
              let pin = map.pin(of: ChildElement(element.asChild(in: renderer.runtime)))
        else { throw DriverCannot("find a Pin on its map") }
        return (map, pin)
    }

    /// The marker MapKit drew for `pin`.
    private func marker(of pin: AppKitMapPin, on map: AppKitMapView) throws -> MKMarkerAnnotationView {
        for _ in 0..<50 where map.view(for: pin) == nil { step() }
        guard let marker = map.view(for: pin) as? MKMarkerAnnotationView else {
            throw DriverCannot("read the marker of a pin MapKit has not drawn")
        }
        return marker
    }
}
#endif
