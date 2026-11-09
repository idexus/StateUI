// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How a map frames a region alike on every host: the radius is the circle around the center that the map shows
/// whole, so the shorter side of what it shows spans the circle's width.
/// Design: docs/design/host/maps.md#a-region
@_spi(Host) public enum MapFraming {
    /// The farthest a region reaches from its middle, in meters: a quarter of the way round the globe.
    public static let farthest = 10_000_000.0

    /// The region a map shows for `region`: its middle on the globe - a latitude within 90° each way, a longitude
    /// taken round to within 180° - and its reach a number above nought, held to `farthest`; nil for one whose
    /// middle stands off the globe or whose numbers are none, which the map does not show.
    /// Design: docs/design/host/maps.md#a-region
    public static func shown(_ region: MapRegion) -> MapRegion? {
        let (latitude, longitude, radius) = (region.center.latitude, region.center.longitude, region.radiusMeters)
        guard (-90...90).contains(latitude), longitude.isFinite, radius > 0 else { return nil }
        var around = (longitude + 180).truncatingRemainder(dividingBy: 360)
        if around < 0 { around += 360 }
        return MapRegion(
            center: Location(latitude: latitude, longitude: around - 180), radiusMeters: min(radius, farthest))
    }

    /// The ground, in meters, the shorter side of a map spans to show `region`.
    public static func side(of region: MapRegion) -> Double {
        2 * region.radiusMeters
    }

    /// The region a map shows, centered at `center`, its sides spanning `width` and `height` meters of ground: the
    /// circle its shorter side holds.
    public static func region(center: Location, width: Double, height: Double) -> MapRegion {
        MapRegion(center: center, radiusMeters: min(width, height) / 2)
    }
}
