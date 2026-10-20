// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import MapKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A Map as Apple's hosts register it.
/// Design: docs/design/platforms/apple/maps.md#a-map
extension MapKitView {
    /// Registers a Map in `registry`, its view made by `make` - the host's own map: the region it opens on, the kind
    /// of map, what the user may do with it, a click or tap on it - and its markers as MapKit's markers.
    public static func register<View: AnyObject, Map: MapKitView>(
        in registry: Registry<View>, making make: @escaping @MainActor () -> Map
    ) {
        registry.add(MapContract.self, create: { reports in
            let map = make()
            map.onClicked = { reports.raise(MapContract.mapClicked, $0) }
            return map
        }, members: { map in
            map.property(MapContract.region) { view, region in
                if let region { view.show(region, sliding: false) }
            }
            map.applies([MapContract.mapType, MapContract.showsTraffic]) { view, values in
                view.style(values[MapContract.mapType] ?? .standard, traffic: values[MapContract.showsTraffic] ?? false)
            }
            map.property(MapContract.isScrollEnabled) { view, on in view.isScrollEnabled = on ?? true }
            map.property(MapContract.isZoomEnabled) { view, on in view.isZoomEnabled = on ?? true }
            map.property(MapContract.showsUserLocation) { view, on in view.showUser(on ?? false) }
            map.raises(MapContract.mapClicked)
            map.children(MarkerContract.self, members: [
                MarkerContract.label, MarkerContract.subtitle, MarkerContract.type, MarkerContract.location,
                MarkerContract.selected, MarkerContract.detailsClicked,
            ]) { view, pins in
                view.show(pins)
            }
        })
    }
}
