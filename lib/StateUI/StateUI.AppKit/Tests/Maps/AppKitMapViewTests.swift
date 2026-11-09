// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import MapKit
import ObjectiveC
@_spi(Host) import StateUI
@_spi(Host) import StateUIApple
@testable import StateUIAppKit
import XCTest

@MainActor
final class AppKitMapViewTests: XCTestCase {
    /// MapKit's map is the delegate of its own recognizers, so the host's map answers none of their questions: one
    /// it answered it would answer for all of them, and a click on a marker no longer chose its pin.
    /// Design: docs/design/host/maps.md#a-tap-on-the-map
    @MainActor
    func testTheMapLeavesMapKitsRecognizersToMapKit() {
        let questions = [
            #selector(NSGestureRecognizerDelegate.gestureRecognizer(_:shouldAttemptToRecognizeWith:)),
            #selector(NSGestureRecognizerDelegate.gestureRecognizerShouldBegin(_:)),
            #selector(NSGestureRecognizerDelegate.gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)),
            #selector(NSGestureRecognizerDelegate.gestureRecognizer(_:shouldRequireFailureOf:)),
            #selector(NSGestureRecognizerDelegate.gestureRecognizer(_:shouldBeRequiredToFailBy:)),
        ]
        for question in questions {
            XCTAssertEqual(
                class_getInstanceMethod(AppKitMapView.self, question).map(method_getImplementation),
                class_getInstanceMethod(MKMapView.self, question).map(method_getImplementation),
                "AppKitMapView answers \(question) for MapKit's recognizers")
        }
    }

    /// A region MapKit cannot show - its middle off the globe, its reach no number, below nothing or past the
    /// globe - never stops the application.
    func testARegionMapKitCannotShowNeverStopsTheApplication() {
        let map = AppKitMapView()
        map.frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let regions = [
            MapRegion(center: Location(latitude: 100, longitude: 0), radiusMeters: 1_000),
            MapRegion(center: Location(latitude: 0, longitude: 400), radiusMeters: 1_000),
            MapRegion(center: Location(latitude: .nan, longitude: 0), radiusMeters: 1_000),
            MapRegion(center: Location(latitude: 52, longitude: 21), radiusMeters: .nan),
            MapRegion(center: Location(latitude: 52, longitude: 21), radiusMeters: -1_000),
            MapRegion(center: Location(latitude: 52, longitude: 21), radiusMeters: 1e12),
            MapRegion(center: Location(latitude: 52, longitude: 21), radiusMeters: .infinity),
            MapRegion(center: Location(latitude: 90, longitude: 0), radiusMeters: 1_000),
            MapRegion(center: Location(latitude: -89.9, longitude: 180), radiusMeters: 1e9),
        ]
        for region in regions { map.show(region, sliding: false) }
        map.show(MapRegion(center: Location(latitude: 52.23, longitude: 21.01), radiusMeters: 5_000), sliding: false)
        XCTAssertEqual(map.centerCoordinate.latitude, 52.23, accuracy: 0.01, "a region it can show shows")
    }
}
#endif
