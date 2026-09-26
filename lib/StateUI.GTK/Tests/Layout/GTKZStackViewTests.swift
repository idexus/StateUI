// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import StateUIConformance
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

final class GTKZStackViewTests: XCTestCase {
    /// An area in logical pixels, and one in fractions of the room: its bottom right quarter.
    func testAZStackStandsEachChildInItsArea() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                ZStack {
                    ColorBox(.red).area(.absolute(10, 20, 30, 40))
                    ColorBox(.blue).area(.proportional(0.5, 0.5, 0.5, 0.5))
                }
            }
            let room = try XCTUnwrap(host.views(GTKZStackView.self).first).frame

            let boxes = host.views(GTKColorBoxView.self)
            XCTAssertEqual(boxes.count, 2)
            XCTAssertTrue(boxes[0].frame == (10, 20, 30, 40), "\(boxes[0].frame)")
            XCTAssertEqual(boxes[1].frame.x, room.width / 2, accuracy: 0.5, "\(boxes[1].frame) in \(room)")
            XCTAssertEqual(boxes[1].frame.y, room.height / 2, accuracy: 0.5)
            XCTAssertEqual(boxes[1].frame.width, room.width / 2, accuracy: 0.5)
            XCTAssertEqual(boxes[1].frame.height, room.height / 2, accuracy: 0.5)
        }
    }

    /// An engine's run: each view's holder at its rectangle, as opaque as it says, the higher rank drawn over the
    /// lower.
    func testAPlacementRunStandsAndDrawsEachChildAsItSays() throws {
        try onUIThread {
            let clock = TestClock()
            let run = State(wrappedValue: PlacedRun())
            let host = GTKRenderer.running(clock: clock) {
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
            let layout = try XCTUnwrap(host.views(GTKZStackView.self).first)
            let holders = host.views(GTKGridView.self)
            XCTAssertEqual(holders.count, 2)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            clock.now = 16
            host.frame()

            XCTAssertTrue(holders[0].frame == (10, 20, 30, 40), "\(holders[0].frame)")
            XCTAssertTrue(holders[1].frame == (0, 0, 50, 50), "\(holders[1].frame)")
            XCTAssertEqual(holders[1].drawnOpacity, 0.5, accuracy: GTKView.opacityStep)
            let drawn = layout.pixels(at: [(20, 30), (45, 10)])
            XCTAssertEqual(drawn[0], red, "the higher rank drawn over the lower one")
            XCTAssertTrue(near(drawn[1], 0x7F00_007F), "the lower one half opaque: \(String(drawn[1], radix: 16))")
        }
    }

    /// The drawing order is by `zIndex`, ties as written - restacked by a described `zIndex`, and by a bound one in
    /// the frame: the middle of the three shows the one in front.
    func testAZStackDrawsItsChildrenInTheirOrder() throws {
        try onUIThread {
            let clock = TestClock()
            let host = GTKRenderer.running(clock: clock) { LayeredBoxes() }
            let layout = try XCTUnwrap(host.views(GTKZStackView.self).first)
            let middle = [(20.0, 20.0)]
            XCTAssertEqual(layout.pixels(at: middle), [red], "red in front")

            let buttons = host.views(GTKButtonView.self)
            buttons[0].click()
            XCTAssertEqual(layout.pixels(at: middle), [blue], "blue in front")

            buttons[1].click()
            clock.now = 16
            host.frame()
            XCTAssertEqual(layout.pixels(at: middle), [green], "green in front, from the frame")
        }
    }

    /// A ZStack's padding narrows the room its children stand in: the whole room, and an area counted from
    /// inside it.
    func testAZStacksPaddingNarrowsItsRoom() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                ZStack {
                    ColorBox(.red)
                    ColorBox(.blue).area(.absolute(10, 20, 30, 40))
                }
                .padding(10, 5, 20, 15)
            }
            let room = try XCTUnwrap(host.views(GTKZStackView.self).first).frame

            let boxes = host.views(GTKColorBoxView.self)
            XCTAssertEqual(boxes.count, 2)
            XCTAssertTrue(boxes[0].frame == (10, 5, room.width - 30, room.height - 20), "\(boxes[0].frame) in \(room)")
            XCTAssertTrue(boxes[1].frame == (20, 25, 30, 40), "\(boxes[1].frame)")
        }
    }

    /// A card tipped about its vertical axis is drawn through the core's matrix, the perspective's division
    /// included: GTK draws its far corner where the matrix sends it.
    func testATurnInDepthIsDrawnThroughTheCoresMatrix() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    ColorBox(.red).width(100).height(40).rotationY(60).horizontalAlignment(.start)
                }
            }
            let box = try XCTUnwrap(host.views(GTKColorBoxView.self).first)
            let place = try XCTUnwrap(box.placed)
            let matrix = HostDrawingTransform(rotationY: 60).matrix(width: 100, height: 40)
            let w = 100 * matrix.m14 + 40 * matrix.m24 + matrix.m44
            let x = (100 * matrix.m11 + 40 * matrix.m21 + matrix.m41) / w
            let y = (100 * matrix.m12 + 40 * matrix.m22 + matrix.m42) / w

            let drawn = box.drawn((100, 40))
            XCTAssertEqual(drawn.x, place.x + x, accuracy: 0.05)
            XCTAssertEqual(drawn.y, place.y + y, accuracy: 0.05)
            XCTAssertLessThan(drawn.x - place.x, 75, "the far edge nearer the middle than a turn with no perspective")
        }
    }

    /// A layout paints its own box - the outline, the fill inside it, a rounded corner left empty - and cuts what
    /// it holds to that shape where it clips, and not where it does not.
    func testALayoutPaintsItsBoxAndCutsWhatItHoldsWhereItClips() {
        onUIThread {
            let host = GTKRenderer.running {
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

            let layouts = host.views(GTKZStackView.self)
            let boxes = host.views(GTKColorBoxView.self)
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
