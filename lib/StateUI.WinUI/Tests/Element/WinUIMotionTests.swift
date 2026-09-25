// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@testable import StateUIWinUI
import XCTest

/// A red box cut to its outline, which a click moves.
private struct CutPage: ContentView {
    @State private var moved = false

    var content: any View {
        VStack {
            VStack { Label("cut") }
                .width(40)
                .height(40)
                .background(Color("#FF0000"))
                .clipsContent(true)
                .horizontalAlignment(.start)
                .translationX(moved ? 50 : 0)
            Button("Move").onClicked { moved = true }
        }
        .width(100)
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

final class WinUIMotionTests: XCTestCase {
    func testTheTransitionSurfaceIsClosedAroundWhatTheHostPresents() {
        onUIThread {
            XCTAssertTrue(WinUITransitionSurface.presents(.opacity, on: .label))
            XCTAssertTrue(WinUITransitionSurface.presents(.translationX, on: .button))
            XCTAssertTrue(WinUITransitionSurface.presents(.value, on: .slider))
            XCTAssertTrue(WinUITransitionSurface.presents(.spacing, on: .vStack))
            XCTAssertFalse(WinUITransitionSurface.presents(.value, on: .label))
            XCTAssertTrue(WinUITransitionSurface.presents(.opacity, on: .switch), "every registered view")
            XCTAssertFalse(WinUITransitionSurface.presents(.opacity, on: .positionIndicator))
            XCTAssertFalse(WinUITransitionSurface.presents(Prop("custom"), on: .label))
        }
    }

    func testAPropertyTransitionBeginsWhereItStandsAndLandsExactly() throws {
        try onUIThread {
            let clock = TestClock()
            let host = WinUIRenderer.bare(clock: clock)
            var initial = HostPatch(id: .manual("label"), type: .label)
            initial.properties[.opacity] = .number(0.25)
            host.apply(initial)

            var changed = HostPatch(id: .manual("label"), type: .label)
            changed.properties[.opacity] = .number(0.75)
            changed.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
            host.apply(changed)

            let label = try XCTUnwrap(host.view(id: .manual("label")))
            XCTAssertEqual(label.drawnOpacity, 0.25, accuracy: 1e-6)

            clock.now = 100
            host.frame()
            XCTAssertEqual(label.drawnOpacity, 0.5, accuracy: 1e-6)

            clock.now = 200
            host.frame()
            XCTAssertEqual(label.drawnOpacity, 0.75, accuracy: 1e-6)
            XCTAssertFalse(host.describedMotion.isActive)
        }
    }

    func testLessMotionPutsThePropertyAtItsValueAtOnce() throws {
        try onUIThread {
            let host = WinUIRenderer.bare(clock: TestClock(), reducesMotion: true)
            var initial = HostPatch(id: .manual("label"), type: .label)
            initial.properties[.opacity] = .number(0.25)
            host.apply(initial)

            var changed = HostPatch(id: .manual("label"), type: .label)
            changed.properties[.opacity] = .number(0.75)
            changed.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
            host.apply(changed)

            XCTAssertEqual(try XCTUnwrap(host.view(id: .manual("label"))).drawnOpacity, 0.75, accuracy: 1e-6)
            XCTAssertFalse(host.animator.isMoving)
        }
    }

    /// One state, one channel: both sliders stand at the same value on every frame, and the waiter hears the arrival.
    func testAJourneyMovesEveryBoundControlOnTheSameFrames() throws {
        try onUIThread {
            let clock = TestClock()
            let level = State(wrappedValue: 0.0)
            let arrived = State(wrappedValue: false)
            let host = WinUIRenderer.running(clock: clock) {
                VStack {
                    Label(arrived.wrappedValue ? "arrived" : "away")
                    Slider(level.projectedValue)
                    Slider(level.projectedValue)
                    Button("Go").onClicked {
                        try await level.projectedValue.journey.move(to: 1, .eased(200, .linear))
                        arrived.wrappedValue = true
                    }
                }
            }
            let sliders = host.views(WinUISliderView.self)
            XCTAssertEqual(sliders.count, 2)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            clock.now = 100
            host.frame()
            XCTAssertEqual(sliders.map(\.value), [0.5, 0.5])

            clock.now = 200
            host.frame()
            XCTAssertEqual(sliders.map(\.value), [1, 1])

            host.settle { arrived.wrappedValue }
            XCTAssertEqual(host.views(WinUILabelView.self).map(\.text), ["arrived"])
        }
    }

    /// The transform stands on the element where its layout put it, turning and scaling about its pivot.
    func testTheViewIsMovedTurnedAndScaledWhereItsLayoutPutIt() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Label("turned")
                        .width(100)
                        .height(40)
                        .translationX(10)
                        .rotation(30)
                        .scale(2)
                        .scaleX(1.5)
                        .pivotX(0)
                }
            }
            let label = try XCTUnwrap(host.views(WinUILabelView.self).first)
            let drawn = label.drawnTransform

            XCTAssertEqual(drawn.translationX, 10)
            XCTAssertEqual(drawn.rotation, 30)
            XCTAssertEqual(drawn.scaleX, 3)
            XCTAssertEqual(drawn.scaleY, 2)
            XCTAssertEqual(drawn.centerX, 0, "the pivot's left edge")
            XCTAssertEqual(drawn.centerY, 20, "halfway down the 40 DIPs it was placed at")
            XCTAssertEqual(label.frame.y, 0, "the layout's place stays where the layout put it")
        }
    }

    func testAMoveCarriedByAJourneyTravelsOnTheDisplaysFrames() throws {
        try onUIThread {
            let clock = TestClock()
            let offset = State(wrappedValue: 0.0)
            let host = WinUIRenderer.running(clock: clock) {
                VStack {
                    Label("moving").translationX(offset.projectedValue)
                    Button("Go").onClicked {
                        try await offset.projectedValue.journey.move(to: 100, .eased(200, .linear))
                    }
                }
            }
            let label = try XCTUnwrap(host.views(WinUILabelView.self).first)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            clock.now = 100
            host.frame()
            XCTAssertEqual(label.drawnTransform.translationX, 50, accuracy: 0.01)

            clock.now = 200
            host.frame()
            XCTAssertEqual(label.drawnTransform.translationX, 100, accuracy: 0.01)
        }
    }

    /// A layout cut to its outline is still moved, turned and scaled: the cut takes the element's own visual, and
    /// what moves it must be what WinUI still lets move it.
    func testALayoutCutToItsOutlineIsStillMoved() throws {
        try onUIThread {
            let host = WinUIRenderer.running { CutPage() }
            let page = try XCTUnwrap(host.views(WinUIStackView.self).first)
            host.settle { page.pixels(at: [(20, 20)]) == [0xFFFF_0000] }

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { page.pixels(at: [(70, 20)]) == [0xFFFF_0000] }

            XCTAssertEqual(page.pixels(at: [(20, 20), (70, 20)]), [0, 0xFFFF_0000])
        }
    }
}
