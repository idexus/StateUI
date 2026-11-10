// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import XCTest

@MainActor
final class MapFramingTests: XCTestCase {
    /// A region's shorter side spans the whole circle: twice the radius.
    func testTheShorterSideSpansTheCircle() {
        XCTAssertEqual(MapFraming.side(of: MapRegion(center: Location(latitude: 52.23, longitude: 21.01), radiusMeters: 5_000)), 10_000)
    }

    /// What a map shows is the circle its shorter side holds, whichever side that is.
    func testTheRegionShownIsTheCircleTheShorterSideHolds() {
        let wide = MapFraming.region(center: Location(latitude: 52.23, longitude: 21.01), width: 20_000, height: 10_000)
        let tall = MapFraming.region(center: Location(latitude: 52.23, longitude: 21.01), width: 10_000, height: 20_000)

        XCTAssertEqual(wide, MapRegion(center: Location(latitude: 52.23, longitude: 21.01), radiusMeters: 5_000))
        XCTAssertEqual(tall, wide)
    }

    /// A map shows a region whose middle stands on the globe and whose reach is a number above nought: a longitude
    /// taken round, a reach past a quarter of the way round held there; the rest it does not show.
    func testAMapShowsARegionOnTheGlobeAlone() {
        func region(_ latitude: Double, _ longitude: Double, _ radius: Double) -> MapRegion {
            MapRegion(center: Location(latitude: latitude, longitude: longitude), radiusMeters: radius)
        }
        XCTAssertEqual(MapFraming.shown(region(52, 21, 5_000)), region(52, 21, 5_000))
        XCTAssertEqual(MapFraming.shown(region(90, -180, 5_000)), region(90, -180, 5_000), "a pole, the date line")
        XCTAssertEqual(MapFraming.shown(region(0, 400, 5_000)), region(0, 40, 5_000), "taken round")
        XCTAssertEqual(MapFraming.shown(region(0, -540, 5_000)), region(0, -180, 5_000))
        XCTAssertEqual(MapFraming.shown(region(0, 0, .infinity)), region(0, 0, MapFraming.farthest))
        for shown in [region(100, 0, 1), region(-90.5, 0, 1), region(.nan, 0, 1), region(0, .infinity, 1),
                      region(0, 0, .nan), region(0, 0, 0), region(0, 0, -1)] {
            XCTAssertNil(MapFraming.shown(shown), "\(shown)")
        }
    }

    /// A region framed and read back is the region: the side it asks for, shown, gives its radius again.
    func testARegionFramedReadsBackAsItself() {
        let region = MapRegion(center: Location(latitude: 50.06, longitude: 19.94), radiusMeters: 2_000)
        let side = MapFraming.side(of: region)

        XCTAssertEqual(MapFraming.region(center: Location(latitude: 50.06, longitude: 19.94), width: side * 2, height: side), region)
    }
}
