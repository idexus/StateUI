// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How a map frames a region alike on every host: the radius is the circle around the centre that the map shows
/// whole, so the shorter side of what it shows spans the circle's width.
/// Design: docs/design/host/maps.md#a-region
@_spi(Host) public enum MapFraming {
    /// The ground, in meters, the shorter side of a map spans to show `region`.
    public static func side(of region: MapRegion) -> Double {
        2 * region.radiusMeters
    }

    /// The region a map shows, centred at `latitude` and `longitude`, its sides spanning `width` and `height`
    /// meters of ground: the circle its shorter side holds.
    public static func region(latitude: Double, longitude: Double, width: Double, height: Double) -> MapRegion {
        MapRegion(latitude: latitude, longitude: longitude, radiusMeters: min(width, height) / 2)
    }
}
