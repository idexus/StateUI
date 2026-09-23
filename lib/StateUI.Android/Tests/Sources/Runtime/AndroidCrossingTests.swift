// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidCrossingTests: XCTestCase {
    static var allTests: [(String, (AndroidCrossingTests) -> () throws -> Void)] {
        [
            ("testAWriteThatChangesNothingCrossesNothing", testAWriteThatChangesNothingCrossesNothing),
            ("testALayoutMovedWithoutResizingLeavesItsChildrenBe", testALayoutMovedWithoutResizingLeavesItsChildrenBe),
        ]
    }

    /// A frame writes only what differs: the same opacity, transform or placing drawing written again does not
    /// cross into Java, and the view's place is the one the host wrote.
    func testAWriteThatChangesNothingCrossesNothing() {
        onMainActor {
            let host = AndroidRenderer.bare()
            let label = AndroidLabelView()
            var transform = HostDrawingTransform.identity
            transform.translationX = 10
            label.setOpacity(0.5)
            label.setTransform(transform)
            label.layout(Rect(x: 0, y: 0, width: 50, height: 20))
            let before = Java.crossings

            label.setOpacity(0.5)
            label.setTransform(transform)
            label.setPlacedDrawing(nil, opacity: 1)
            XCTAssertEqual(label.placedFrame, Rect(x: 0, y: 0, width: 50, height: 20))
            XCTAssertEqual(Java.crossings, before)
            withExtendedLifetime(host) {}
        }
    }

    /// Moved with its size kept, and nothing in it asking to be measured again, a layout leaves its children where
    /// they stand; resized, or asked to lay out, it arranges them.
    func testALayoutMovedWithoutResizingLeavesItsChildrenBe() {
        onMainActor {
            let host = AndroidRenderer.bare()
            let layout = CountingLayout()

            layout.layout(Rect(x: 0, y: 0, width: 100, height: 50))
            XCTAssertEqual(layout.arranged, 1)

            layout.layout(Rect(x: 20, y: 30, width: 100, height: 50))
            XCTAssertEqual(layout.arranged, 1, "moved, not arranged")
            XCTAssertTrue(layout.frame == (40, 60, 200, 100), "\(layout.frame)")

            layout.layout(Rect(x: 20, y: 30, width: 120, height: 50))
            XCTAssertEqual(layout.arranged, 2, "resized, arranged")

            layout.requestLayout()
            layout.layout(Rect(x: 20, y: 30, width: 120, height: 50))
            XCTAssertEqual(layout.arranged, 3, "asked to lay out again, arranged")
            withExtendedLifetime(host) {}
        }
    }
}

/// A layout that counts how often Android has it arrange its children.
private final class CountingLayout: AndroidLayoutView {
    var arranged = 0

    override func arrange(in bounds: Rect) {
        arranged += 1
    }
}
