// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PolylineContract` on a host: a polyline is drawn through its points, anew where the tree moves them, and filled by
/// its rule.
@_spi(Host) public enum PolylineTests: ConformanceFamily {
    public static let name = "Polyline"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Polyline"),
        ]
    }

    /// A run down the left side to `y`, across the room at `y`, and down the right side: as tall and wide as the
    /// room its figure stands in, so the points read are the room's own.
    static func across(at y: Double) -> [Point] {
        [Point(0, 0), Point(0, y), Point(40, y), Point(40, 40)]
    }
}
