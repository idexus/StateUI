// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
import StateUIConformance
import XCTest

@MainActor
final class GTKMotionTests: XCTestCase {
    func testTheTransitionSurfaceIsClosedAroundWhatTheHostPresents() {
        onUIThread {
            XCTAssertTrue(GTKTransitionSurface.presents(.opacity, on: .text))
            XCTAssertTrue(GTKTransitionSurface.presents(.translationX, on: .button))
            XCTAssertTrue(GTKTransitionSurface.presents(.value, on: .slider))
            XCTAssertTrue(GTKTransitionSurface.presents(.spacing, on: .vStack))
            XCTAssertFalse(GTKTransitionSurface.presents(.value, on: .text))
            XCTAssertTrue(GTKTransitionSurface.presents(.opacity, on: .switch), "every registered view")
            XCTAssertFalse(GTKTransitionSurface.presents(.opacity, on: .map))
            XCTAssertFalse(GTKTransitionSurface.presents(Prop("custom"), on: .text))
        }
    }

    func testAPropertyTransitionBeginsWhereItStandsAndLandsExactly() throws {
        try onUIThread {
            let clock = TestClock()
            let host = GTKRenderer.bare(clock: clock)
            var initial = HostPatch(id: .manual("label"), type: .text)
            initial.properties[.opacity] = .number(0.25)
            host.apply(initial)

            var changed = HostPatch(id: .manual("label"), type: .text)
            changed.properties[.opacity] = .number(0.75)
            changed.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
            host.apply(changed)

            let label = try XCTUnwrap(host.view(id: .manual("label")))
            XCTAssertEqual(label.drawnOpacity, 0.25, accuracy: GTKView.opacityStep)

            clock.now = 100
            host.frame()
            XCTAssertEqual(label.drawnOpacity, 0.5, accuracy: GTKView.opacityStep)

            clock.now = 200
            host.frame()
            XCTAssertEqual(label.drawnOpacity, 0.75, accuracy: GTKView.opacityStep)
            XCTAssertFalse(host.runtime.describedMotion.isActive)
        }
    }

    func testLessMotionPutsThePropertyAtItsValueAtOnce() throws {
        try onUIThread {
            let host = GTKRenderer.bare(clock: TestClock(), reducesMotion: true)
            var initial = HostPatch(id: .manual("label"), type: .text)
            initial.properties[.opacity] = .number(0.25)
            host.apply(initial)

            var changed = HostPatch(id: .manual("label"), type: .text)
            changed.properties[.opacity] = .number(0.75)
            changed.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
            host.apply(changed)

            XCTAssertEqual(try XCTUnwrap(host.view(id: .manual("label"))).drawnOpacity, 0.75, accuracy: GTKView.opacityStep)
            XCTAssertFalse(host.runtime.animator.isMoving)
        }
    }

    /// One state, one channel: both sliders stand at the same value on every frame, and the waiter hears the arrival.
    func testAJourneyMovesEveryBoundControlOnTheSameFrames() throws {
        try onUIThread {
            let clock = TestClock()
            let level = State(wrappedValue: 0.0)
            let arrived = State(wrappedValue: false)
            let host = GTKRenderer.running(clock: clock) {
                VStack {
                    Text(arrived.wrappedValue ? "arrived" : "away")
                    Slider(level.projectedValue)
                    Slider(level.projectedValue)
                    Button("Go").onClicked {
                        try await level.projectedValue.journey.move(to: 1, .eased(200, .linear)).arrived()
                        arrived.wrappedValue = true
                    }
                }
            }
            let sliders = host.views(GTKSliderView.self)
            XCTAssertEqual(sliders.count, 2)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            clock.now = 100
            host.frame()
            XCTAssertEqual(sliders.map(\.value), [0.5, 0.5])

            clock.now = 200
            host.frame()
            XCTAssertEqual(sliders.map(\.value), [1, 1])

            host.settle { arrived.wrappedValue }
            XCTAssertEqual(host.views(GTKTextView.self).map(\.text), ["arrived"])
        }
    }

    /// The transform stands on the element where its layout put it, turning and scaling about its pivot: GTK draws
    /// the pivot moved by the translation alone, a step along the width three times longer and turned 30 degrees,
    /// and a step down the height twice as long.
    func testTheViewIsMovedTurnedAndScaledWhereItsLayoutPutIt() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    Text("turned")
                        .width(100)
                        .height(40)
                        .translationX(10)
                        .rotation(30)
                        .scale(2)
                        .scaleX(1.5)
                        .pivotX(0)
                }
            }
            let label = try XCTUnwrap(host.views(GTKTextView.self).first)
            let place = try XCTUnwrap(label.placed)
            let pivot = label.drawn((0, 20))
            let along = label.drawn((1, 20))
            let down = label.drawn((0, 21))

            XCTAssertEqual(place.y, 0, "the layout's place stays where the layout put it")
            XCTAssertEqual(pivot.x, place.x + 10, accuracy: 0.01, "the pivot's left edge, moved by the translation")
            XCTAssertEqual(pivot.y, place.y + 20, accuracy: 0.01, "halfway down the 40 it was placed at")
            XCTAssertEqual(along.x - pivot.x, 3 * 0.866_025, accuracy: 0.01)
            XCTAssertEqual(along.y - pivot.y, 3 * 0.5, accuracy: 0.01)
            XCTAssertEqual(down.x - pivot.x, -2 * 0.5, accuracy: 0.01)
            XCTAssertEqual(down.y - pivot.y, 2 * 0.866_025, accuracy: 0.01)
        }
    }

    func testAMoveCarriedByAJourneyTravelsOnTheDisplaysFrames() throws {
        try onUIThread {
            let clock = TestClock()
            let offset = State(wrappedValue: 0.0)
            let host = GTKRenderer.running(clock: clock) {
                VStack {
                    Text("moving").translationX(offset.projectedValue)
                    Button("Go").onClicked {
                        try await offset.projectedValue.journey.move(to: 100, .eased(200, .linear)).arrived()
                    }
                }
            }
            let label = try XCTUnwrap(host.views(GTKTextView.self).first)

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            let place = try XCTUnwrap(label.placed)
            clock.now = 100
            host.frame()
            XCTAssertEqual(label.drawn((0, 0)).x - place.x, 50, accuracy: 0.01)

            clock.now = 200
            host.frame()
            XCTAssertEqual(label.drawn((0, 0)).x - place.x, 100, accuracy: 0.01)
        }
    }

    /// A view moved, turned or scaled draws its own colour wherever GSK renders it - the cairo renderer, without GL,
    /// draws a transform of no known kind as hot pink.
    func testAMovedViewDrawsItsOwnColour() throws {
        try onUIThread {
            let host = GTKRenderer.running {
                VStack {
                    ZStack {
                        ColorBox(.red).width(20).height(20).horizontalAlignment(.start).verticalAlignment(.start)
                            .translationX(30).translationY(30)
                        ColorBox(.blue).width(20).height(20).horizontalAlignment(.start).verticalAlignment(.start)
                            .translationX(60).rotation(45)
                    }.width(100).height(100).id("room")
                }.horizontalAlignment(.start).verticalAlignment(.start)
            }
            host.layOut()
            let room = try XCTUnwrap(host.view(id: .manual("room")))

            XCTAssertEqual(room.pixels(at: [(40, 40)]), [0xFFFF_0000], "moved")
            XCTAssertEqual(room.pixels(at: [(70, 10)]), [0xFF00_00FF], "moved and turned")
        }
    }
}
