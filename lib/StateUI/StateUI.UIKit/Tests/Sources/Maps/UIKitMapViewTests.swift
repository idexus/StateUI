// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
import MapKit
import ObjectiveC
@testable import StateUIUIKit
import XCTest

@MainActor
final class UIKitMapViewTests: XCTestCase {
    /// MapKit's map is the delegate of its own recognizers, so the host's map answers none of their questions: one
    /// it answered it would answer for all of them - a tap on a marker, a pinch, a pan.
    /// Design: docs/design/host/maps.md#a-tap-on-the-map
    @MainActor
    func testTheMapLeavesMapKitsRecognizersToMapKit() {
        let questions = [
            #selector(UIGestureRecognizerDelegate.gestureRecognizer(_:shouldReceive:) as (UIGestureRecognizerDelegate) -> ((UIGestureRecognizer, UITouch) -> Bool)?),
            #selector(UIGestureRecognizerDelegate.gestureRecognizerShouldBegin(_:)),
            #selector(UIGestureRecognizerDelegate.gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)),
            #selector(UIGestureRecognizerDelegate.gestureRecognizer(_:shouldRequireFailureOf:)),
            #selector(UIGestureRecognizerDelegate.gestureRecognizer(_:shouldBeRequiredToFailBy:)),
        ]
        for question in questions {
            XCTAssertEqual(
                class_getInstanceMethod(UIKitMapView.self, question).map(method_getImplementation),
                class_getInstanceMethod(MKMapView.self, question).map(method_getImplementation),
                "UIKitMapView answers \(question) for MapKit's recognizers")
        }
    }

    /// A tap on the map waits for a double tap to fail: a double tap - MapKit's zoom - is no two taps on the map.
    @MainActor
    func testATapOnTheMapWaitsForADoubleTapToFail() throws {
        let map = UIKitMapView()
        let tap = try XCTUnwrap(map.gestureRecognizers?.first { $0.delegate !== map && $0 is UITapGestureRecognizer })
        let double = UITapGestureRecognizer()
        double.numberOfTapsRequired = 2
        let single = UITapGestureRecognizer()

        XCTAssertEqual(tap.delegate?.gestureRecognizer?(tap, shouldRequireFailureOf: double), true)
        XCTAssertNotEqual(tap.delegate?.gestureRecognizer?(tap, shouldRequireFailureOf: single), true)
    }
}
