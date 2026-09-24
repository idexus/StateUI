// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidMotionTests: XCTestCase {
    static var allTests: [(String, (AndroidMotionTests) -> () throws -> Void)] {
        [
            ("testTheTransitionSurfaceIsClosedAroundWhatTheHostPresents", testTheTransitionSurfaceIsClosedAroundWhatTheHostPresents),
            ("testAPropertyTransitionBeginsWhereItStandsAndLandsExactly", testAPropertyTransitionBeginsWhereItStandsAndLandsExactly),
            ("testLessMotionPutsThePropertyAtItsValueAtOnce", testLessMotionPutsThePropertyAtItsValueAtOnce),
            ("testAJourneyMovesEveryBoundControlOnTheSameFrames", testAJourneyMovesEveryBoundControlOnTheSameFrames),
            ("testTheViewIsMovedTurnedAndScaledWhereItsLayoutPutIt", testTheViewIsMovedTurnedAndScaledWhereItsLayoutPutIt),
            ("testPositiveTurnsSendTheTopAndTheRightEdgeAway", testPositiveTurnsSendTheTopAndTheRightEdgeAway),
            ("testAMoveCarriedByAJourneyTravelsOnTheDisplaysFrames", testAMoveCarriedByAJourneyTravelsOnTheDisplaysFrames),
        ]
    }

    func testTheTransitionSurfaceIsClosedAroundWhatTheHostPresents() {
        onMainActor { Self.theTransitionSurfaceIsClosedAroundWhatTheHostPresents() }
    }

    @MainActor
    private static func theTransitionSurfaceIsClosedAroundWhatTheHostPresents() {
        XCTAssertTrue(AndroidTransitionSurface.presents(.opacity, on: .label))
        XCTAssertTrue(AndroidTransitionSurface.presents(.translationX, on: .button))
        XCTAssertTrue(AndroidTransitionSurface.presents(.value, on: .slider))
        XCTAssertTrue(AndroidTransitionSurface.presents(.spacing, on: .vStack))
        XCTAssertFalse(AndroidTransitionSurface.presents(.value, on: .label))
        XCTAssertTrue(AndroidTransitionSurface.presents(.opacity, on: .checkBox), "every registered view")
        XCTAssertFalse(AndroidTransitionSurface.presents(.opacity, on: .positionIndicator))
        XCTAssertFalse(AndroidTransitionSurface.presents(Prop("custom"), on: .label))
    }

    func testAPropertyTransitionBeginsWhereItStandsAndLandsExactly() throws {
        try onMainActor {
            let clock = TestClock()
            let host = AndroidRenderer.bare(clock: clock)
            var initial = HostPatch(id: .manual("label"), type: .label)
            initial.properties[.opacity] = .number(0.25)
            host.apply(initial)

            var changed = HostPatch(id: .manual("label"), type: .label)
            changed.properties[.opacity] = .number(0.75)
            changed.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
            host.apply(changed)

            let label = try XCTUnwrap(host.view(id: .manual("label")))
            XCTAssertEqual(label.opacity, 0.25, accuracy: 1e-6)

            clock.now = 100
            host.frame()
            XCTAssertEqual(label.opacity, 0.5, accuracy: 1e-6)

            clock.now = 200
            host.frame()
            XCTAssertEqual(label.opacity, 0.75, accuracy: 1e-6)
            XCTAssertFalse(host.describedMotion.isActive)
        }
    }

    func testLessMotionPutsThePropertyAtItsValueAtOnce() throws {
        try onMainActor {
            let host = AndroidRenderer.bare(clock: TestClock(), reducesMotion: true)
            var initial = HostPatch(id: .manual("label"), type: .label)
            initial.properties[.opacity] = .number(0.25)
            host.apply(initial)

            var changed = HostPatch(id: .manual("label"), type: .label)
            changed.properties[.opacity] = .number(0.75)
            changed.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
            host.apply(changed)

            XCTAssertEqual(try XCTUnwrap(host.view(id: .manual("label"))).opacity, 0.75, accuracy: 1e-6)
            XCTAssertFalse(host.animator.isMoving)
        }
    }

    /// One state, one channel: both sliders stand at the same value on every frame, and the waiter hears the arrival.
    func testAJourneyMovesEveryBoundControlOnTheSameFrames() throws {
        try onMainActor {
            let clock = TestClock()
            let level = State(wrappedValue: 0.0)
            let arrived = State(wrappedValue: false)
            let host = AndroidRenderer.running(clock: clock) {
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
            let sliders = host.views(AndroidSliderView.self)
            XCTAssertEqual(sliders.count, 2)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            clock.now = 100
            host.frame()
            XCTAssertEqual(sliders.map(\.value), [0.5, 0.5])

            clock.now = 200
            host.frame()
            XCTAssertEqual(sliders.map(\.value), [1, 1])

            host.settle { arrived.wrappedValue }
            XCTAssertEqual(host.views(AndroidLabelView.self).map(\.text), ["arrived"])
        }
    }

    func testTheViewIsMovedTurnedAndScaledWhereItsLayoutPutIt() throws {
        try onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Label("turned")
                        .translationX(10)
                        .rotation(30)
                        .scale(2)
                        .scaleX(1.5)
                        .pivotX(0)
                }
            }
            host.layOut()
            let label = try XCTUnwrap(host.views(AndroidLabelView.self).first)

            XCTAssertEqual(Java.callFloat(label.reference, TestJava.getTranslationX), 20, "ten points at two pixels a point")
            XCTAssertEqual(Java.callFloat(label.reference, TestJava.getRotation), 30)
            XCTAssertEqual(Java.callFloat(label.reference, TestJava.getScaleX), 3)
            XCTAssertEqual(Java.callFloat(label.reference, TestJava.getScaleY), 2)
            XCTAssertEqual(Java.callFloat(label.reference, TestJava.getPivotX), 0)
            XCTAssertEqual(label.frame.x, 0, "the layout's place stays where the layout put it")
        }
    }

    /// StateUI's turns: a positive `rotationX` sends the top away, a positive `rotationY` the right edge.
    func testPositiveTurnsSendTheTopAndTheRightEdgeAway() {
        onMainActor {
            let host = AndroidRenderer.running {
                VStack {
                    Label("tipped").width(100).height(100).rotationX(30)
                    Label("turned").width(100).height(100).rotationY(30)
                }
            }
            host.layOut()
            let labels = host.views(AndroidLabelView.self)

            // A far edge is drawn shorter: its corners come in towards the middle.
            let tipped = labels[0].drawn([(0, 0), (0, 200)])
            XCTAssertGreaterThan(tipped[0].0, tipped[1].0, "the top edge is the shorter one")
            let turned = labels[1].drawn([(0, 0), (200, 0)])
            XCTAssertGreaterThan(turned[1].1, turned[0].1, "the right edge is the shorter one")
        }
    }

    func testAMoveCarriedByAJourneyTravelsOnTheDisplaysFrames() throws {
        try onMainActor {
            let clock = TestClock()
            let offset = State(wrappedValue: 0.0)
            let host = AndroidRenderer.running(clock: clock) {
                VStack {
                    Label("moving").translationX(offset.projectedValue)
                    Button("Go").onClicked {
                        try await offset.projectedValue.journey.move(to: 100, .eased(200, .linear))
                    }
                }
            }
            let label = try XCTUnwrap(host.views(AndroidLabelView.self).first)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            clock.now = 100
            host.frame()
            XCTAssertEqual(Java.callFloat(label.reference, TestJava.getTranslationX), 100, accuracy: 0.01)

            clock.now = 200
            host.frame()
            XCTAssertEqual(Java.callFloat(label.reference, TestJava.getTranslationX), 200, accuracy: 0.01)
        }
    }
}
