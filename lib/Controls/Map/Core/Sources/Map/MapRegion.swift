// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// The part of the world a map shows: the region around a point.
///
///     Map(latitude: 52.2479, longitude: 21.0155, radiusMeters: 1500)
///
/// It crosses as its three numbers - latitude, longitude, and the radius in
/// meters.
public struct MapRegion: Equatable, Sendable, HostRepresentable {
    /// Degrees north of the equator, negative south of it.
    public var latitude: Double

    /// Degrees east of Greenwich, negative west of it.
    public var longitude: Double

    /// Half the width of what is shown, in meters.
    public var radiusMeters: Double

    /// A region, by its centre and its radius.
    ///
    /// - Parameters:
    ///   - latitude: degrees north of the equator, negative south.
    ///   - longitude: degrees east of Greenwich, negative west.
    ///   - radiusMeters: half the width of what is shown, in meters.
    public init(latitude: Double, longitude: Double, radiusMeters: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
    }

    /// Its three numbers, in order.
    public var propValue: PropValue { .numbers([latitude, longitude, radiusMeters]) }

    /// A region back from its three numbers - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let numbers = propValue.numbers, numbers.count == 3 else { return nil }

        self.init(latitude: numbers[0], longitude: numbers[1], radiusMeters: numbers[2])
    }
}
