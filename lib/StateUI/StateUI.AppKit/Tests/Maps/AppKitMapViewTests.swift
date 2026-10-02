// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import MapKit
import ObjectiveC
@testable import StateUIAppKit
import XCTest

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
}
#endif
