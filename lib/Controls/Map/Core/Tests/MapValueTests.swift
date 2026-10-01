// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
import StateUIMap

/// A map's values as they cross to a host and back.
final class MapValueTests: XCTestCase {
    /// A region crosses as its three numbers, a place as its two; any other count reads as no value.
    func testARegionAndAPlaceCrossAsTheirNumbers() {
        XCTAssertEqual(MapRegion(latitude: 52, longitude: 21, radiusMeters: 1500).propValue, .numbers([52, 21, 1500]))
        XCTAssertEqual(Location(latitude: 52.25, longitude: 21.01).propValue, .numbers([52.25, 21.01]))
        XCTAssertNil(MapRegion(propValue: .numbers([52, 21])), "two numbers, not three")
        XCTAssertNil(Location(propValue: .numbers([52, 21, 1500])), "three numbers, not two")
    }

    /// Every value reads back as it crossed.
    func testEveryValueReadsBackAsItCrossed() {
        let region = MapRegion(latitude: 52.25, longitude: 21.01, radiusMeters: 1500)
        let place = Location(latitude: 52.25, longitude: 21.01)
        XCTAssertEqual(MapRegion(propValue: region.propValue), region)
        XCTAssertEqual(Location(propValue: place.propValue), place)
        XCTAssertEqual(MapType(propValue: MapType.satellite.propValue), .satellite)
        XCTAssertEqual(PinType(propValue: PinType.place.propValue), .place)
    }

    /// Each report's payload decodes as its contract declares.
    func testEveryReportsPayloadDecodesAsDeclared() {
        XCTAssertNotNil(MemberValues.decode([.numbers([52.25, 21.01])], as: Location.self))
    }
}
