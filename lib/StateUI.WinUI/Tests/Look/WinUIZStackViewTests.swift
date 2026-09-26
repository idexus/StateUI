// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import StateUIHostConformance
import XCTest

/// Three layers, one inside another: red 10 wide, blue 20, green 30. A button raises blue by a described `zIndex`,
/// another green by a bound one.
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
            .width(40)
            .height(40)
            .horizontalAlignment(.start)

            Button("Blue").onClicked { blueInFront = true }
            Button("Green").onClicked { green = 5 }
        }
    }
}

private let red: UInt32 = 0xFFFF_0000
private let green: UInt32 = 0xFF00_8000
private let blue: UInt32 = 0xFF00_00FF

final class WinUIZStackViewTests: XCTestCase {
    /// An engine's run: each view's holder at its rectangle, as opaque as it says, the higher rank drawn over the
    /// lower.
    func testAPlacementRunStandsAndDrawsEachChildAsItSays() throws {
        try onUIThread {
            let clock = TestClock()
            let run = State(wrappedValue: PlacedRun())
            let host = WinUIRenderer.running(clock: clock) {
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
            let layout = try XCTUnwrap(host.views(WinUIZStackView.self).first)
            let holders = host.views(WinUIGridView.self)
            XCTAssertEqual(holders.count, 2)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            clock.now = 16
            host.frame()

            XCTAssertTrue(holders[0].frame == (10, 20, 30, 40), "\(holders[0].frame)")
            XCTAssertTrue(holders[1].frame == (0, 0, 50, 50), "\(holders[1].frame)")
            XCTAssertEqual(holders[1].drawnOpacity, 0.5, accuracy: 0.001)
            XCTAssertEqual(
                layout.pixels(at: [(20, 30), (45, 10)]), [red, 0x7F00_007F],
                "the higher rank drawn over the half-opaque lower one")
        }
    }

    /// The drawing order is by `zIndex`, ties as written - restacked by a described `zIndex`, and by a bound one in
    /// the frame: the middle of the three shows the one in front.
    func testAZStackDrawsItsChildrenInTheirOrder() throws {
        try onUIThread {
            let clock = TestClock()
            let host = WinUIRenderer.running(clock: clock) { LayeredBoxes() }
            let layout = try XCTUnwrap(host.views(WinUIZStackView.self).first)
            let middle = [(20.0, 20.0)]
            XCTAssertEqual(layout.pixels(at: middle), [red], "red in front")

            let buttons = host.views(WinUIButtonView.self)
            buttons[0].invoke()
            XCTAssertEqual(layout.pixels(at: middle), [blue], "blue in front")

            buttons[1].invoke()
            clock.now = 16
            host.frame()
            XCTAssertEqual(layout.pixels(at: middle), [green], "green in front, from the frame")
        }
    }

    /// A layout paints its own box - the outline, the fill inside it, a rounded corner left empty - and cuts what
    /// it holds to that shape where it clips, and not where it does not.
    func testALayoutPaintsItsBoxAndCutsWhatItHoldsWhereItClips() {
        onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    ZStack { ColorBox(.red) }
                        .padding(10)
                        .background(Color("#00FF00"))
                        .stroke(Color("#0000FF"))
                        .strokeWidth(2)
                        .shape(.roundedRectangle(20))
                        .clipsContent(true)
                        .width(100)
                        .height(80)
                        .horizontalAlignment(.start)
                    ZStack { ColorBox(.red) }
                        .shape(.roundedRectangle(20))
                        .width(100)
                        .height(80)
                        .horizontalAlignment(.start)
                    ZStack { ColorBox(.red) }
                        .shape(.roundedRectangle(20))
                        .clipsContent(true)
                        .width(100)
                        .height(80)
                        .horizontalAlignment(.start)
                }
            }

            let layouts = host.views(WinUIZStackView.self)
            let boxes = host.views(WinUIColorBoxView.self)
            XCTAssertEqual(layouts.count, 3)
            guard layouts.count == 3 else { return }
            XCTAssertTrue(layouts[0].frame == (0, 0, 100, 80), "\(layouts[0].frame)")
            XCTAssertTrue(boxes[0].frame == (10, 10, 80, 60), "\(boxes[0].frame)")

            let drawn = layouts[0].pixels(at: [(50, 0.5), (50, 5), (0.5, 0.5), (50, 40)])
            XCTAssertEqual(drawn, [blue, 0xFF00_FF00, 0, red], drawn.map { String($0, radix: 16) }.description)
            XCTAssertEqual(layouts[1].pixels(at: [(0.5, 0.5)]), [red], "a layout that does not clip cuts nothing")
            XCTAssertEqual(
                layouts[2].pixels(at: [(0.5, 0.5), (50, 40)]), [0, red], "one that clips cuts its child's corner")
        }
    }
}
