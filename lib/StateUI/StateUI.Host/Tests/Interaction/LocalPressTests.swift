// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A view's own press: its effect asked once a frame, what it answers laid over the view - over its own transform
// where no layout program places it, over its place where one does - and gone when the press lifts.

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// How often an effect was asked and what it was handed, a class so the closure that writes it is not walked for
/// state.
private final class Asked {
    var presses: [PressInput] = []
}

@MainActor
final class LocalPressTests: XCTestCase {
    private let bench = LayoutBench()

    /// A press with no spring pulling its view `most` points toward the edge it stands at, across.
    private static func pulled(_ most: Double) -> Interaction {
        .press(values: .translation) { press in
            PresentationOffset(translation: Point(x: press.normalizedLocation.x * most, y: 0))
        }
    }

    /// A press at `phase` standing at `point` of a view 100 by 40, heard by `element`, and a frame after it.
    private func press(_ phase: GesturePhase, at point: Point, on element: MountedElement) {
        bench.cycle(on: element) { runtime, element in
            element.hear(.press(phase, at: point, size: LayoutSize(width: 100, height: 40), byFinger: false), in: runtime)
        }
    }

    // MARK: - A view no layout program places

    /// A PRESS LAYS ITS OFFSET OVER THE VIEW'S OWN TRANSFORM AND LEAVES IT WHEN IT LIFTS: the view listens for
    /// presses, is drawn as its effect says while one stands, and as its layout has it once it is gone.
    func testAPressOffsetsAPlainViewUntilItLifts() throws {
        bench.mounted {
            VStack {
                Rectangle()
                    .width(100).height(40)
                    .interaction(.press(values: .scale) { _ in PresentationOffset(scaleX: 0.9, scaleY: 0.9) })
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))
        XCTAssertTrue(view.hearing.contains(.presses))
        XCTAssertFalse(view.hearing.contains(.taps), "watched, not taken: no tap comes of it")

        press(.began, at: Point(x: 50, y: 20), on: view)
        XCTAssertEqual(view.drawingTransform.scaleX, 0.9)
        XCTAssertEqual(view.drawingTransform.scaleY, 0.9)

        press(.ended, at: Point(x: 50, y: 20), on: view)
        XCTAssertEqual(view.drawingTransform.scaleX, 1)
    }

    /// THE OFFSET IS LAID OVER WHAT THE VIEW SAYS OF ITSELF: its own move and scale stand under it.
    func testAPressIsLaidOverTheViewsOwnTransform() throws {
        bench.mounted {
            VStack {
                Rectangle()
                    .width(100).height(40)
                    .translationX(10)
                    .scale(2)
                    .interaction(.press(values: .all) { _ in
                        PresentationOffset(translation: Point(x: 5, y: 0), scaleX: 1.5, scaleY: 1)
                    })
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))

        press(.began, at: Point(x: 50, y: 20), on: view)

        XCTAssertEqual(view.drawingTransform.scaleX, 3, "the view's own scale times the press's")
        XCTAssertEqual(view.drawingTransform.scaleY, 2)
        XCTAssertEqual(view.drawingTransform.translationX, 20, "its own move, scaled by the press's, and the press's")
    }

    /// A PRESS IS ASKED ONCE A FRAME, OF WHERE IT LAST STOOD: told faster than the display draws, its effect is
    /// handed the latest - how far it has gone since it went down, and where about the view's middle.
    func testAPressIsAskedOnceAFrameOfWhereItLastStood() throws {
        let asked = Asked()
        bench.mounted {
            VStack {
                Rectangle()
                    .width(100).height(40)
                    .interaction(.press(values: .translation) { press in
                        asked.presses.append(press)
                        return PresentationOffset(translation: press.displacement)
                    })
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))
        let size = LayoutSize(width: 100, height: 40)

        press(.began, at: Point(x: 50, y: 20), on: view)
        bench.cycle(on: view) { runtime, view in
            view.hear(.press(.changed, at: Point(x: 60, y: 20), size: size, byFinger: false), in: runtime)
            view.hear(.press(.changed, at: Point(x: 100, y: 30), size: size, byFinger: false), in: runtime)
        }

        XCTAssertEqual(asked.presses.map(\.phase), [.began, .changed], "once a frame")
        XCTAssertEqual(asked.presses.last?.displacement, Point(x: 50, y: 10))
        XCTAssertEqual(asked.presses.last?.normalizedLocation, Point(x: 1, y: 0.5))
        XCTAssertEqual(view.drawingTransform.translationX, 50)

        bench.cycle()
        XCTAssertEqual(asked.presses.count, 2, "a press standing still asks nothing")
    }

    /// A PRESS IS MEASURED IN THE VIEW AS ITS LAYOUT PLACES IT: its effect moving and growing the view, a pointer
    /// standing still is told at another point of the view as it is drawn - and the effect is handed where it
    /// stood before, so what it answers moves nothing it is handed.
    func testAPressIsMeasuredInTheViewAsItsLayoutPlacesIt() throws {
        let asked = Asked()
        bench.mounted {
            VStack {
                Rectangle()
                    .width(100).height(40)
                    .interaction(.press(values: .all) { press in
                        asked.presses.append(press)
                        return PresentationOffset(translation: Point(x: 10, y: 0), scaleX: 2, scaleY: 1)
                    })
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))

        press(.began, at: Point(x: 90, y: 20), on: view)
        // Twice as wide about its middle and ten points on, the point of the view under the same pointer is
        // forty from the middle halved, and ten back: 50 + 40 / 2 - 10 / 2.
        press(.changed, at: Point(x: 65, y: 20), on: view)

        XCTAssertEqual(asked.presses.last?.location, Point(x: 90, y: 20))
        XCTAssertEqual(asked.presses.last?.displacement, .zero)
    }

    /// A VIEW THAT HEARS TAPS HEARS ITS PRESS BY THEM: it asks for no second listening, which would tell each
    /// press twice.
    func testAViewHearingTapsAsksForNoSecondPress() throws {
        bench.mounted {
            VStack {
                Rectangle().width(100).height(40).interaction(Self.pulled(6)).onTapped {}
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))

        XCTAssertTrue(view.hearing.contains(.taps))
        XCTAssertFalse(view.hearing.contains(.presses))
        press(.began, at: Point(x: 100, y: 20), on: view)
        XCTAssertEqual(view.drawingTransform.translationX, 6, "the tap's press moves it")
    }

    /// A PRESS TAKEN AWAY LEAVES THE VIEW AS ITS LAYOUT HAS IT, as one lifted does.
    func testAPressTakenAwayLeavesTheView() throws {
        bench.mounted {
            VStack {
                Rectangle().width(100).height(40).interaction(Self.pulled(8))
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))

        press(.began, at: Point(x: 100, y: 20), on: view)
        XCTAssertEqual(view.drawingTransform.translationX, 8)

        press(.cancelled, at: Point(x: 100, y: 20), on: view)
        XCTAssertEqual(view.drawingTransform.translationX, 0)
    }

    // MARK: - A press with a spring of its own

    /// AN ELASTIC PRESS GROWS THE VIEW WITH NO JUMP: the frame the press goes down the view is as it was, then it
    /// grows on the press's own spring to what the press answers - a view that is no body of any layout - and
    /// goes back the same way once the press lifts.
    func testAnElasticPressGrowsTheViewWithNoJump() throws {
        bench.mounted {
            VStack {
                Rectangle().width(100).height(40).interaction(.elasticPress(maximumOffset: 8, scale: 1.05, maximumScale: 1.2))
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))

        press(.began, at: Point(x: 50, y: 20), on: view)
        XCTAssertEqual(view.drawingTransform.scaleX, 1, accuracy: 0.000_1, "the frame it goes down: no jump")
        bench.frames(3)
        let growing = view.drawingTransform.scaleX
        XCTAssertGreaterThan(growing, 1, "growing")
        XCTAssertLessThan(growing, 1.05, "on its way")

        bench.frames(60)
        XCTAssertEqual(view.drawingTransform.scaleX, 1.05, accuracy: 0.001, "grown as a press at its middle draws it")
        XCTAssertEqual(view.drawingTransform.scaleY, 1.05, accuracy: 0.001)

        // Moved to the right edge, it is pulled there and drawn wider - as tall as before.
        press(.changed, at: Point(x: 100, y: 20), on: view)
        bench.frames(60)
        XCTAssertEqual(view.drawingTransform.translationX, 8, accuracy: 0.01)
        XCTAssertEqual(view.drawingTransform.scaleX, 1.2, accuracy: 0.001)
        XCTAssertEqual(view.drawingTransform.scaleY, 1.05, accuracy: 0.001)

        press(.ended, at: Point(x: 100, y: 20), on: view)
        bench.frames(3)
        XCTAssertGreaterThan(view.drawingTransform.translationX, 0, "coming back, not there at once")
        bench.frames(90)
        XCTAssertEqual(view.drawingTransform.translationX, 0, accuracy: 0.01)
        XCTAssertEqual(view.drawingTransform.scaleX, 1, accuracy: 0.001)
        XCTAssertFalse(view.localFollow.moves, "at rest: nothing asks for a frame")
    }

    // MARK: - A view a layout program places

    /// A layout of one view, 100 by 40 at 20, 30, pulled toward a press, coming onto its place as `body` says.
    private func pressedLayout(_ body: LayoutBody) -> () -> Node {
        let still = State(wrappedValue: 0.0)
        return {
            MotionLayout([1], parameters: still.projectedValue) { _ in
                Rectangle().interaction(Self.pulled(8)).layoutBody(body)
            } placements: { _, _ in
                [Placement(Rect(x: 20, y: 30, width: 100, height: 40))]
            }
            .node
        }
    }

    /// A PRESS ON A LAYOUT'S VIEW MOVES ITS PLACE: the layout's element shows the view's view moved by the press, its
    /// rectangle the layout's, and where the layout puts it again once the press lifts.
    func testAPressOnALayoutsViewMovesItsPlace() throws {
        bench.laid(pressedLayout(.none))
        let layout = try XCTUnwrap(bench.layout)
        let view = try XCTUnwrap(layout.children.first?.children.first)
        XCTAssertTrue(view.hearing.contains(.presses), "the view in its view answers its press")

        press(.began, at: Point(x: 100, y: 20), on: view)

        XCTAssertEqual(layout.programPlaces.first?.translationX, 8)
        XCTAssertEqual(layout.programPlaces.first?.bounds, Rect(x: 20, y: 30, width: 100, height: 40))
        XCTAssertEqual(view.drawingTransform.translationX, 0, "laid over its place, not over its own transform too")

        press(.ended, at: Point(x: 100, y: 20), on: view)
        XCTAssertEqual(layout.programPlaces.first?.translationX, 0)
    }

    /// A BODY FOLLOWING ITS LAYOUT LAGS BEHIND A PRESS AND SPRINGS BACK: the press moves the view's place, and the
    /// body comes after it on its spring - toward the press while it stands, back once it lifts.
    func testABodyFollowingItsLayoutLagsBehindAPressAndSpringsBack() throws {
        bench.laid(pressedLayout(.followsLayout(response: .milliseconds(300), damping: 1)))
        let layout = try XCTUnwrap(bench.layout)
        let view = try XCTUnwrap(layout.children.first?.children.first)

        press(.began, at: Point(x: 100, y: 20), on: view)
        XCTAssertEqual(layout.programPlaces.first?.translationX, 0, "the frame the press moved its place: not yet after it")
        bench.frames(3)
        let first = try XCTUnwrap(layout.programPlaces.first?.translationX)
        XCTAssertGreaterThan(first, 0, "on its way toward the press")
        XCTAssertLessThan(first, 8, "behind it")

        bench.frames(60)
        XCTAssertEqual(try XCTUnwrap(layout.programPlaces.first?.translationX), 8, accuracy: 0.05, "come up with it")

        press(.ended, at: Point(x: 100, y: 20), on: view)
        bench.frames(3)
        let back = try XCTUnwrap(layout.programPlaces.first?.translationX)
        XCTAssertLessThan(back, 8)
        XCTAssertGreaterThan(back, 0, "springing back, not there at once")

        bench.frames(60)
        XCTAssertEqual(try XCTUnwrap(layout.programPlaces.first?.translationX), 0, accuracy: 0.05)
    }
}
