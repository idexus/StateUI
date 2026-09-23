// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidAbsoluteLayoutViewTests: XCTestCase {
    static var allTests: [(String, (AndroidAbsoluteLayoutViewTests) -> () throws -> Void)] {
        [
            ("testAnAbsoluteLayoutStandsEachChildAtItsBounds", testAnAbsoluteLayoutStandsEachChildAtItsBounds),
            ("testAPlacementRunStandsAndDrawsEachChildAsItSays", testAPlacementRunStandsAndDrawsEachChildAsItSays),
        ]
    }

    /// Bounds in points, and a position of one against the far edge.
    func testAnAbsoluteLayoutStandsEachChildAtItsBounds() {
        onMainActor {
            let host = AndroidRenderer.running {
                AbsoluteLayout {
                    ColorBox(.red).absoluteLayoutBounds(Rect(10, 20, 30, 40))
                    ColorBox(.blue).absoluteLayoutBounds(Rect(1, 1, 50, 50)).absoluteLayoutProportions(.position)
                }
            }

            host.layOut(width: 1080, height: 1920)

            let boxes = host.views(AndroidColorBoxView.self)
            XCTAssertEqual(boxes.count, 2)
            XCTAssertTrue(boxes[0].frame == (20, 40, 60, 80), "\(boxes[0].frame)")
            XCTAssertTrue(boxes[1].frame == (980, 1820, 100, 100), "\(boxes[1].frame)")
        }
    }

    /// An engine's run: each view's holder at its rectangle, as opaque as it says, the higher rank drawn over the lower.
    func testAPlacementRunStandsAndDrawsEachChildAsItSays() throws {
        try onMainActor {
            let clock = TestClock()
            let run = State(wrappedValue: PlacedRun())
            let host = AndroidRenderer.running(clock: clock) {
                VStack {
                    PlacedLayout(["back", "front"], id: \.self) { name in
                        ColorBox(name == "back" ? .red : .blue)
                    }
                    .placement(run.projectedValue)
                    .height(200)

                    Button("Place").onClicked {
                        run.wrappedValue = PlacedRun([
                            Placement(Rect(10, 20, 30, 40), zIndex: 1),
                            Placement(Rect(0, 0, 50, 50), opacity: 0.5),
                        ])
                    }
                }
            }
            host.layOut()
            let layout = try XCTUnwrap(host.views(AndroidAbsoluteLayoutView.self).first)
            let holders = host.views(AndroidGridView.self)
            XCTAssertEqual(holders.count, 2)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            clock.now = 16
            host.frame()
            host.layOut()

            XCTAssertTrue(holders[0].frame == (20, 40, 60, 80), "\(holders[0].frame)")
            XCTAssertTrue(holders[1].frame == (0, 0, 100, 100), "\(holders[1].frame)")
            XCTAssertEqual(Java.callFloat(holders[1].reference, JavaAPI.getAlpha), 0.5, accuracy: 0.001)
            XCTAssertTrue(layout.holds(inOrder: [holders[1], holders[0]]))

            let boxes = host.views(AndroidColorBoxView.self)
            XCTAssertTrue(boxes[0].frame == (0, 0, 60, 80), "\(boxes[0].frame)")
            XCTAssertTrue(boxes[1].frame == (0, 0, 100, 100), "\(boxes[1].frame)")
        }
    }
}
