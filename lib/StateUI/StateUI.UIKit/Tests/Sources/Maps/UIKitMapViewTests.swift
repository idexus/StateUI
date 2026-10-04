// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
import MapKit
import ObjectiveC
@testable import StateUIUIKit
import XCTest

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
}
