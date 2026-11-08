// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PolygonContract` on a host: a polygon is filled inside its points, drawn anew where the tree moves them, and a
/// figure crossing itself is filled by its rule.
@_spi(Host) public enum PolygonTests: ConformanceFamily {
    public static let name = "Polygon"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Polygon"),
        ]
    }

    /// A square gone round, then its middle gone round the same way again: its middle wound twice.
    static let woundTwice = [
        Point(0, 0), Point(40, 0), Point(40, 40), Point(0, 40), Point(0, 0),
        Point(10, 10), Point(30, 10), Point(30, 30), Point(10, 30), Point(10, 10),
    ]
}
