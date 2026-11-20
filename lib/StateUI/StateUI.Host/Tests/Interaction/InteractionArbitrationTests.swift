// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// What follows of one gesture taking the touch from another, the same on every host: a drag takes a view's
/// press and its tap, the hand that takes a layout takes the presses of the views in it - their own effects too -
/// and a view's press and its drag go on together, each over its own numbers.
/// Design: docs/design/host/interaction.md#one-gesture-taking-anothers-touch
@MainActor
final class InteractionArbitrationTests: XCTestCase {
    private let bench = LayoutBench()
    private let size = LayoutSize(width: 100, height: 40)

    /// What a view's handlers were told, in order.
    private final class Told {
        var said: [String] = []
    }

    /// What `element` hears, and a frame after it; whether it took it.
    @discardableResult
    private func hear(_ input: HeardInput, on element: MountedElement) -> Bool {
        var took = false
        bench.cycle(on: element) { runtime, element in took = element.hear(input, in: runtime) }
        return took
    }

    /// A press shrinking its view to nine tenths, at once.
    private static let shrinking = Interaction.press(values: .scale) { _ in PresentationOffset(scaleX: 0.9, scaleY: 0.9) }

    /// A PAN TAKING A VIEW'S PRESS TAPS NOTHING: the press goes out as the pan begins, and its lift over the view
    /// is no tap.
    func testAPanTakingAViewsPressTapsNothing() throws {
        let told = Told()
        bench.mounted {
            VStack {
                Rectangle()
                    .width(100).height(40)
                    .onTapped { told.said.append("tapped") }
                    .onPanUpdated { pan in told.said.append("pan \(pan.phase)") }
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))
        let at = Point(x: 10, y: 10)

        hear(.press(.began, at: at, size: size, byFinger: false), on: view)
        XCTAssertTrue(view.buttonPress.isPressed)
        hear(.drag(.began, x: 0, y: 0, from: at), on: view)
        XCTAssertFalse(view.buttonPress.isPressed, "the pan took the press")
        hear(.drag(.ended, x: 2, y: 0, from: at), on: view)
        hear(.press(.ended, at: at, size: size, byFinger: false), on: view)

        XCTAssertEqual(told.said, ["pan began", "pan ended"], "and its lift over the view taps nothing")
    }

    /// A VIEW'S PRESS YIELDS TO THE HAND THAT TAKES ITS LAYOUT: the effect of a press on a view lets go as the
    /// hand begins to move the run it stands in - and stands while the hand is still.
    func testAViewsPressYieldsToTheHandThatTakesItsLayout() throws {
        let turn = State(wrappedValue: 0.0)
        bench.laid {
            MotionLayout([0, 1], parameters: turn.projectedValue) { _ in
                Rectangle().interaction(Self.shrinking)
            } placements: { _, at in
                (0..<2).map { Placement(Rect(x: (Double($0) - at) * 120, y: 0, width: 100, height: 40)) }
            }
            .interaction(.value(turn.projectedValue, input: .translation(.horizontal, unit: .points(120))).range(0...1))
            .layoutBodies(LayoutBody.none)
            .node
        }
        let layout = try XCTUnwrap(bench.layout)
        let view = try XCTUnwrap(layout.children.first?.children.first)

        hear(.press(.began, at: Point(x: 50, y: 20), size: size, byFinger: true), on: view)
        hear(.hand(.began, moved: .zero, speed: nil), on: layout)
        XCTAssertEqual(layout.programPlaces.first?.scaleX, 0.9, "pressed, under a hand that stands still")

        hear(.hand(.changed, moved: Point(x: -40, y: 0), speed: nil), on: layout)
        bench.cycle()
        XCTAssertEqual(layout.programPlaces.first?.scaleX, 1, "the hand took the run: the press let go")

        hear(.press(.changed, at: Point(x: 30, y: 20), size: size, byFinger: true), on: view)
        bench.cycle()
        XCTAssertEqual(layout.programPlaces.first?.scaleX, 1, "and nothing more of that press is the view's")
    }

    /// A VIEW'S PRESS AND ITS DRAG GO ON TOGETHER, EACH OVER ITS OWN NUMBERS: the view shrinks under the press
    /// while the hand carries it, and the press taken away lets the scale go and leaves the view in the hand.
    func testAViewsPressAndItsDragGoOnTogether() throws {
        bench.mounted {
            VStack {
                Rectangle()
                    .width(100).height(40)
                    .interaction(.simultaneous([Self.shrinking, .drag(.both)]))
            }
            .node
        }
        let view = try XCTUnwrap(bench.element(.rectangle))
        let at = Point(x: 50, y: 20)

        hear(.press(.began, at: at, size: size, byFinger: false), on: view)
        hear(.hand(.began, moved: .zero, speed: nil, point: at), on: view)
        hear(.hand(.changed, moved: Point(x: 30, y: 10), speed: nil), on: view)
        XCTAssertEqual(view.drawingTransform.scaleX, 0.9, accuracy: 0.001, "shrunk by its press")
        XCTAssertEqual(view.drawingTransform.translationX, 30, accuracy: 0.001, "and carried by the hand")

        hear(.press(.cancelled, at: at, size: size, byFinger: false), on: view)
        XCTAssertEqual(view.drawingTransform.scaleX, 1, accuracy: 0.001, "the press taken away lets its numbers go")
        XCTAssertEqual(view.drawingTransform.translationX, 30, accuracy: 0.001, "the hand keeps its own")

        hear(.hand(.ended, moved: .zero, speed: .zero), on: view)
        XCTAssertEqual(view.drawingTransform.translationX, 0, accuracy: 0.001)
    }
}
