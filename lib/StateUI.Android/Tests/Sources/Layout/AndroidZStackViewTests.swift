// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

/// Three layers told apart by their widths: red 10, blue 20, green 30. A button raises blue by a described
/// `zIndex`, another green by a bound one.
struct LayeredBoxes: ContentView {
    @State private var blueInFront = false
    @State private var green = 0

    var content: any View {
        VStack {
            ZStack {
                ColorBox(.red).width(10).zIndex(blueInFront ? 0 : 1)
                ColorBox(.blue).width(20).zIndex(blueInFront ? 1 : 0)
                ColorBox(.green).width(30).zIndex($green)
            }
            .height(40)

            Button("Blue").onClicked { blueInFront = true }
            Button("Green").onClicked { green = 5 }
        }
    }
}

final class AndroidZStackViewTests: XCTestCase {
    static var allTests: [(String, (AndroidZStackViewTests) -> () throws -> Void)] {
        [
            ("testAZStackStandsEachChildInItsArea", testAZStackStandsEachChildInItsArea),
            ("testAPlacementRunStandsAndDrawsEachChildAsItSays", testAPlacementRunStandsAndDrawsEachChildAsItSays),
            ("testAZStackHoldsItsChildrenInTheDrawingOrder", testAZStackHoldsItsChildrenInTheDrawingOrder),
            ("testAZStacksPaddingNarrowsItsRoom", testAZStacksPaddingNarrowsItsRoom),
        ]
    }

    /// An area in points, and one in fractions of the room: its bottom right quarter.
    func testAZStackStandsEachChildInItsArea() {
        onMainActor {
            let host = AndroidRenderer.running {
                ZStack {
                    ColorBox(.red).area(.absolute(10, 20, 30, 40))
                    ColorBox(.blue).area(.proportional(0.5, 0.5, 0.5, 0.5))
                }
            }

            host.layOut(width: 1080, height: 1920)

            let boxes = host.views(AndroidColorBoxView.self)
            XCTAssertEqual(boxes.count, 2)
            XCTAssertTrue(boxes[0].frame == (20, 40, 60, 80), "\(boxes[0].frame)")
            XCTAssertTrue(boxes[1].frame == (540, 960, 540, 960), "\(boxes[1].frame)")
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
            let layout = try XCTUnwrap(host.views(AndroidZStackView.self).first)
            let holders = host.views(AndroidGridView.self)
            XCTAssertEqual(holders.count, 2)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            clock.now = 16
            host.frame()
            host.layOut()

            XCTAssertTrue(holders[0].frame == (20, 40, 60, 80), "\(holders[0].frame)")
            XCTAssertTrue(holders[1].frame == (0, 0, 100, 100), "\(holders[1].frame)")
            XCTAssertEqual(Java.callFloat(holders[1].reference, JavaAPI.getAlpha), 0.5, accuracy: 0.001)
            XCTAssertEqual(layout.drawingOrder, [1, 0], "the higher rank drawn last")
            XCTAssertTrue(layout.holds(inOrder: [holders[0], holders[1]]), "and nothing moved in the group")

            let boxes = host.views(AndroidColorBoxView.self)
            XCTAssertTrue(boxes[0].frame == (0, 0, 60, 80), "\(boxes[0].frame)")
            XCTAssertTrue(boxes[1].frame == (0, 0, 100, 100), "\(boxes[1].frame)")
        }
    }

    /// The group holds a ZStack's children in their drawing order - by `zIndex`, ties as written - restacked by a
    /// described `zIndex`, and by a bound one in the frame.
    func testAZStackHoldsItsChildrenInTheDrawingOrder() throws {
        try onMainActor {
            let clock = TestClock()
            let host = AndroidRenderer.running(clock: clock) { LayeredBoxes() }
            host.layOut()
            let layout = try XCTUnwrap(host.views(AndroidZStackView.self).first)
            @MainActor func drawn() -> [Int32] {
                host.views(AndroidColorBoxView.self)
                    .sorted {
                        Java.callInt(layout.reference, TestJava.indexOfChild, .object($0.reference))
                            < Java.callInt(layout.reference, TestJava.indexOfChild, .object($1.reference))
                    }
                    .map { $0.frame.width }
            }
            XCTAssertEqual(drawn(), [40, 60, 20], "blue and green as written, red in front")

            let buttons = host.views(AndroidButtonView.self)
            buttons[0].click()
            host.layOut()
            XCTAssertEqual(drawn(), [20, 60, 40], "blue in front")

            buttons[1].click()
            clock.now = 16
            host.frame()
            host.layOut()
            XCTAssertEqual(drawn(), [20, 40, 60], "green in front, from the frame")
        }
    }

    /// A ZStack's padding narrows the room its children stand in: the whole room, and an area counted from
    /// inside it.
    func testAZStacksPaddingNarrowsItsRoom() {
        onMainActor {
            let host = AndroidRenderer.running {
                ZStack {
                    ColorBox(.red)
                    ColorBox(.blue).area(.absolute(10, 20, 30, 40))
                }
                .padding(10, 5, 20, 15)
            }

            host.layOut(width: 1080, height: 1920)

            let boxes = host.views(AndroidColorBoxView.self)
            XCTAssertEqual(boxes.count, 2)
            XCTAssertTrue(boxes[0].frame == (20, 10, 1080 - 60, 1920 - 40), "\(boxes[0].frame)")
            XCTAssertTrue(boxes[1].frame == (40, 50, 60, 80), "\(boxes[1].frame)")
        }
    }
}
