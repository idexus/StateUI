// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// What a rectangle in a stack reads of where it stands, a stage each.
@MainActor
private enum Staged {
    static var layout = State(wrappedValue: Rect.zero)
    static var presentation = State(wrappedValue: Rect.zero)
    static var heardLayout: [[Double]] = []
    static var heardPresentation: [[Double]] = []
    static var moved = State(wrappedValue: 0.0)
}

private struct StagedApplication: Application {
    var body: some Scene { WindowGroup { StagedPage() } }
}

/// A rectangle reading both of its rectangles, each into a state and to a handler, moved across by a state.
private struct StagedPage: View {
    var body: some View {
        VStack {
            Rectangle()
                .width(100)
                .height(60)
                .translationX(Staged.moved.projectedValue)
                .frame(into: Staged.layout.projectedValue)
                .frame(into: Staged.presentation.projectedValue, stage: .presentation)
                .onEvent(ViewContract.layoutFrameChanged) { Staged.heardLayout.append($0) }
                .onEvent(ViewContract.presentationFrameChanged) { Staged.heardPresentation.append($0) }
        }
    }
}

/// A view a layout places, standing where it was last put.
@MainActor
private final class Seated: PlacedView {
    var placedFrame = Rect(x: 0, y: 0, width: 0, height: 0)
}

/// The two rectangles a view has: where its layout puts it, and the rectangle around what is drawn of it - one
/// while it stands at its place with no transform, apart while it travels there or is drawn moved.
/// Design: docs/design/host/runtime.md#two-rectangles
@MainActor
final class GeometryStageTests: XCTestCase {
    /// A view a hundred by sixty, ten and twenty into its parent, its corner at 110, 120 in the window.
    private let standing: [Double] = [10, 20, 100, 60, 110, 120, 110, 80]

    private func staged() throws -> (runtime: HostRuntime, view: MountedElement, stack: MountedElement) {
        Staged.layout = State(wrappedValue: .zero)
        Staged.presentation = State(wrappedValue: .zero)
        Staged.moved = State(wrappedValue: 0, motion: .none)
        Staged.heardLayout = []
        Staged.heardPresentation = []
        StagedApplication.register()
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let view = try XCTUnwrap(runtime.tree.root?.first(type: .rectangle))
        let stack = try XCTUnwrap(runtime.tree.root?.first(type: .vStack))
        return (runtime, view, stack)
    }

    /// A VIEW AT REST WITH NO TRANSFORM SAYS ONE RECTANGLE AT BOTH STAGES.
    func testAViewAtRestSaysOneRectangleAtBothStages() throws {
        let (runtime, view, _) = try staged()

        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()

        XCTAssertEqual(Staged.layout.wrappedValue, Rect(10, 20, 100, 60))
        XCTAssertEqual(Staged.presentation.wrappedValue, Rect(10, 20, 100, 60))
        XCTAssertEqual(Staged.heardLayout, [standing])
        XCTAssertEqual(Staged.heardPresentation, [standing])
    }

    /// A TRANSFORM MOVES THE PRESENTATION ALONE: the layout's rectangle stands, the presentation's is the
    /// rectangle around what is drawn, its corner in the window with it.
    func testATransformMovesThePresentationAlone() throws {
        let (runtime, view, _) = try staged()
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()

        Staged.moved.wrappedValue = 30
        runtime.pump.turn()
        runtime.displayCycle.frame(now: 0)
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()

        XCTAssertEqual(Staged.layout.wrappedValue, Rect(10, 20, 100, 60), "where its layout puts it")
        XCTAssertEqual(Staged.presentation.wrappedValue, Rect(40, 20, 100, 60), "where it is drawn")
        XCTAssertEqual(Staged.heardLayout.count, 1, "the layout's rectangle said once")
        XCTAssertEqual(Staged.heardPresentation.last, [40, 20, 100, 60, 140, 120, 140, 80])
    }

    /// A VIEW TRAVELLING TO A NEW PLACE IS AT ITS DESTINATION FOR THE LAYOUT STAGE, said once, and where it stands
    /// on the way for the presentation stage, said at each place.
    func testATravellingViewIsAtItsDestinationForTheLayoutStage() throws {
        let (runtime, view, _) = try staged()
        let (places, seat) = (TravelingPlaces(), Seated())
        places.layoutMotion = runtime.layoutMotion
        places.motion = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
        func arrange(at place: Rect) {
            places.patchArrived()
            places.begin(width: 300)
            var values = LayoutValues()
            (values.width, values.height) = (100, 60)
            places.place(seat, mount: view.mount, at: place, values: values, natural: { .zero }, fadeIn: nil)
        }
        arrange(at: Rect(x: 10, y: 20, width: 100, height: 60))
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()

        // Its layout puts it forty points down; it stands where it stood, on its way.
        arrange(at: Rect(x: 10, y: 60, width: 100, height: 60))
        XCTAssertEqual(seat.placedFrame.y, 20)
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()

        XCTAssertEqual(Staged.layout.wrappedValue, Rect(10, 60, 100, 60), "its destination, at once")
        XCTAssertEqual(Staged.heardLayout.last, [10, 60, 100, 60, 110, 160, 110, 120], "its corner where it will stand")
        XCTAssertEqual(Staged.presentation.wrappedValue, Rect(10, 20, 100, 60), "where it stands now")
        XCTAssertEqual(Staged.heardLayout.count, 2)
        XCTAssertEqual(Staged.heardPresentation.count, 1, "it has not moved yet")
    }

    /// THE WAY IS THE PRESENTATION'S ALONE: wherever the toolkit holds a view on its way - at a third of a point,
    /// its corner worked out with its arithmetic's last digits - the layout's stage has said its destination and
    /// says nothing more, and the presentation's says each place.
    func testTheLayoutStageSaysNothingOfTheWay() throws {
        let (runtime, view, _) = try staged()
        let (places, seat) = (TravelingPlaces(), Seated())
        places.layoutMotion = runtime.layoutMotion
        places.motion = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
        func arrange(at place: Rect) {
            places.patchArrived()
            places.begin(width: 300)
            var values = LayoutValues()
            (values.width, values.height) = (100, 60)
            places.place(seat, mount: view.mount, at: place, values: values, natural: { .zero }, fadeIn: nil)
        }
        arrange(at: Rect(x: 10, y: 20, width: 100, height: 60))
        view.reportFrame(standing, in: runtime)
        arrange(at: Rect(x: 10, y: 60, width: 100, height: 60))
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()
        let (said, drawn) = (Staged.heardLayout.count, Staged.heardPresentation.count)

        for step in 1...3 {
            let down = Double(step) * 40 / 3
            view.reportFrame([10, 20 + down, 100, 60, 110, 120.1 + down - 0.1, 110, 80.3 + down - 0.3], in: runtime)
            runtime.pump.turn()
        }

        XCTAssertEqual(Staged.heardLayout.count, said, "its destination was said: the way says nothing more")
        XCTAssertEqual(Staged.heardPresentation.count, drawn + 3, "each place of the way")
        XCTAssertEqual(Staged.presentation.wrappedValue.y, 60, accuracy: 1e-9)

        // At rest the toolkit's own numbers stand, the corner as it is: the same place, said no second time.
        places.patchArrived()
        runtime.layoutMotion.remove(mount: view.mount)
        view.reportFrame([10, 60, 100, 60, 110, 160, 110, 120], in: runtime)
        runtime.pump.turn()
        XCTAssertEqual(Staged.heardLayout.count, said, "come to rest: nothing new for the layout's stage")
    }

    /// THE LAST STEP OF A VALUE COMING TO REST IS SAID, however short: a width less than a billionth of a point
    /// from where it rests is another width, at both stages.
    func testTheLastStepOfAValueComingToRestIsSaid() throws {
        let (runtime, view, _) = try staged()

        view.reportFrame([10, 20, 89.99999999926833, 60, 110, 120, 110, 80], in: runtime)
        view.reportFrame([10, 20, 90, 60, 110, 120, 110, 80], in: runtime)
        runtime.pump.turn()

        XCTAssertEqual(Staged.layout.wrappedValue.width, 90)
        XCTAssertEqual(Staged.presentation.wrappedValue.width, 90)
        XCTAssertEqual(Staged.heardLayout.count, 2)
        XCTAssertEqual(Staged.heardPresentation.count, 2)
    }

    /// A CORNER THAT STANDS IS COMPARED AS IT IS: with no place on its way, a corner the toolkit says a hair off
    /// is another corner.
    func testACornerNothingCarriedIsComparedAsItIs() throws {
        let (runtime, view, _) = try staged()

        view.reportFrame([10, 20, 100, 60, 110, 120, 110, 80], in: runtime)
        view.reportFrame([10, 20, 100, 60, 110, 120.0000001, 110, 80.0000001], in: runtime)
        runtime.pump.turn()

        XCTAssertEqual(Staged.heardLayout.count, 2)
    }

    /// A LAYOUT ON ITS WAY CARRIES ITS VIEWS' CORNERS: a view standing still in a stack that travels is, for the
    /// layout stage, where it stands once the stack has come to its place.
    func testALayoutOnItsWayCarriesItsViewsCorners() throws {
        let (runtime, view, stack) = try staged()
        let (places, seat) = (TravelingPlaces(), Seated())
        places.layoutMotion = runtime.layoutMotion
        places.motion = HostLayoutMotion(motion: .eased(.milliseconds(200), curve: .linear), lanes: .all)
        func arrange(at place: Rect) {
            places.patchArrived()
            places.begin(width: 300)
            places.place(seat, mount: stack.mount, at: place, values: LayoutValues(), natural: { .zero }, fadeIn: nil)
        }
        arrange(at: Rect(x: 0, y: 0, width: 300, height: 200))
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()

        arrange(at: Rect(x: 0, y: 50, width: 300, height: 200))
        view.reportFrame(standing, in: runtime)
        runtime.pump.turn()

        XCTAssertEqual(Staged.heardLayout.last, [10, 20, 100, 60, 110, 170, 110, 130], "fifty down with its stack")
        XCTAssertEqual(Staged.heardPresentation.count, 1, "and drawn where it was")
    }

    /// THE RECTANGLE AROUND A PLACE AS A TRANSFORM DRAWS IT: moved, scaled and turned about its pivot.
    func testTheRectangleAroundAPlaceUnderATransform() {
        let place = Rect(x: 10, y: 20, width: 100, height: 60)
        func transform(
            x: Double = 0, y: Double = 0, rotation: Double = 0, scaleX: Double = 1, scaleY: Double = 1,
            pivotX: Double = 0.5, pivotY: Double = 0.5
        ) -> HostDrawingTransform {
            HostDrawingTransform(
                translationX: x, translationY: y, rotation: rotation, rotationX: 0, rotationY: 0, scaleX: scaleX,
                scaleY: scaleY, pivotX: pivotX, pivotY: pivotY)
        }
        func near(_ one: Rect, _ other: Rect) -> Bool {
            abs(one.x - other.x) < 1e-9 && abs(one.y - other.y) < 1e-9 && abs(one.width - other.width) < 1e-9
                && abs(one.height - other.height) < 1e-9
        }

        XCTAssertEqual(transform().bounds(of: place), place, "no transform: the place itself")
        XCTAssertTrue(near(transform(x: 5, y: -3).bounds(of: place), Rect(x: 15, y: 17, width: 100, height: 60)))
        XCTAssertTrue(
            near(transform(scaleX: 2, scaleY: 2).bounds(of: place), Rect(x: -40, y: -10, width: 200, height: 120)),
            "about its middle")
        XCTAssertTrue(
            near(transform(scaleX: 2, pivotX: 0, pivotY: 0).bounds(of: place), Rect(x: 10, y: 20, width: 200, height: 60)),
            "about its corner")
        XCTAssertTrue(
            near(transform(rotation: 90).bounds(of: place), Rect(x: 30, y: 0, width: 60, height: 100)),
            "a quarter turn about its middle")
    }
}
