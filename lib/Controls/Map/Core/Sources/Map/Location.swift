// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI

/// A point on the world, as an event reports one - the two values every map
/// answer carries.
public struct Location: Equatable, Sendable, HostRepresentable {
    /// Degrees north of the equator, negative south of it.
    public var latitude: Double

    /// Degrees east of Greenwich, negative west of it.
    public var longitude: Double

    /// A place, by its two coordinates.
    ///
    /// - Parameter latitude: degrees north of the equator, negative south.
    /// - Parameter longitude: degrees east of Greenwich, negative west.
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// The pair it crosses as - one `numbers` value, latitude then longitude.
    public var propValue: PropValue { .numbers([latitude, longitude]) }

    /// A place back from its pair - nil for anything else, so a report that
    /// will not read leaves the handler alone.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let pair = propValue.numbers, pair.count == 2 else { return nil }

        self.latitude = pair[0]
        self.longitude = pair[1]
    }
}
