// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// A Map: MapKit's own map - the region it opens on, the kind of map, what the user may do with it, a tap on
    /// it - and its pins as MapKit's markers.
    static func maps(_ registry: Registry<UIView>) {
        registry.add(MapContract.self, create: { reports in
            let map = UIKitMapView()
            map.onTapped = { reports.raise(MapContract.mapClicked, $0) }
            return map
        }, members: { map in
            map.property(MapContract.region) { view, region in
                if let region { view.show(region, sliding: false) }
            }
            map.applies([MapContract.mapType, MapContract.showsTraffic]) { view, values in
                view.style(values[MapContract.mapType] ?? .street, traffic: values[MapContract.showsTraffic] ?? false)
            }
            map.property(MapContract.isScrollEnabled) { view, on in view.isScrollEnabled = on ?? true }
            map.property(MapContract.isZoomEnabled) { view, on in view.isZoomEnabled = on ?? true }
            map.property(MapContract.showsUserLocation) { view, on in view.showUser(on ?? false) }
            map.raises(MapContract.mapClicked)
            map.children(PinContract.self, members: [
                PinContract.label, PinContract.address, PinContract.type, PinContract.location,
                PinContract.pinClicked, PinContract.pinDetailsClicked,
            ]) { view, pins in
                view.show(pins)
            }
        })
    }
}
#endif
