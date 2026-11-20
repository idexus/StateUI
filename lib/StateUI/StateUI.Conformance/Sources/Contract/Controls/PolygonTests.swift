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
        Point(x: 0, y: 0), Point(x: 40, y: 0), Point(x: 40, y: 40), Point(x: 0, y: 40), Point(x: 0, y: 0),
        Point(x: 10, y: 10), Point(x: 30, y: 10), Point(x: 30, y: 30), Point(x: 10, y: 30), Point(x: 10, y: 10),
    ]
}
