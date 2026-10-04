// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import XCTest

final class MapFramingTests: XCTestCase {
    /// A region's shorter side spans the whole circle: twice the radius.
    func testTheShorterSideSpansTheCircle() {
        XCTAssertEqual(MapFraming.side(of: MapRegion(latitude: 52.23, longitude: 21.01, radiusMeters: 5_000)), 10_000)
    }

    /// What a map shows is the circle its shorter side holds, whichever side that is.
    func testTheRegionShownIsTheCircleTheShorterSideHolds() {
        let wide = MapFraming.region(latitude: 52.23, longitude: 21.01, width: 20_000, height: 10_000)
        let tall = MapFraming.region(latitude: 52.23, longitude: 21.01, width: 10_000, height: 20_000)

        XCTAssertEqual(wide, MapRegion(latitude: 52.23, longitude: 21.01, radiusMeters: 5_000))
        XCTAssertEqual(tall, wide)
    }

    /// A region framed and read back is the region: the side it asks for, shown, gives its radius again.
    func testARegionFramedReadsBackAsItself() {
        let region = MapRegion(latitude: 50.06, longitude: 19.94, radiusMeters: 2_000)
        let side = MapFraming.side(of: region)

        XCTAssertEqual(MapFraming.region(latitude: 50.06, longitude: 19.94, width: side * 2, height: side), region)
    }
}
