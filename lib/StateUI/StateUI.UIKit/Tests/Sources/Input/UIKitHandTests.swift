// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// The hand over a layout as UIKit's pan tells it, and the press it begins with.
final class UIKitHandTests: XCTestCase {
    /// What a layout's handler was told, a class so the closure that writes it is not walked for state.
    private final class Told {
        var items: [Int] = []
    }

    /// A pan that says in which view each reading of it was asked.
    private final class AskedPan: UIPanGestureRecognizer {
        var asked: [UIView?] = []
        override var state: UIGestureRecognizer.State {
            get { .changed }
            set {}
        }

        override func translation(in view: UIView?) -> CGPoint {
            asked.append(view)
            return CGPoint(x: 10, y: 0)
        }
    }

    /// THE HAND IS READ IN A VIEW IT DOES NOT MOVE: a view saying its own drag comes after the hand, and a pan read
    /// in the view itself tells less than the finger went - the view trailing it. The pan is read in the view the
    /// host layer names, the stack the view stands in.
    @MainActor
    func testAViewsOwnDragIsReadInAViewTheHandDoesNotMove() throws {
        let host = UIKitRenderer.running {
            VStack {
                Rectangle()
                    .fill(.red)
                    .width(40)
                    .height(40)
                    .interaction(.drag(.both))
            }
        }
        defer { host.finish() }
        let element = try XCTUnwrap(host.runtime.tree.root?.first(type: .rectangle))
        let native = try XCTUnwrap(element.native as? UIKitElement)
        let space = try XCTUnwrap((element.handSpace?.native as? UIKitElement)?.view)
        let pan = AskedPan(target: nil, action: nil)

        try XCTUnwrap(native.listening).handMoved(pan)

        XCTAssertEqual(pan.asked.count, 1)
        XCTAssertTrue(pan.asked.first.flatMap { $0 } === space, "read in the stack the view stands in")
        XCTAssertFalse(space === native.view, "which is not the view the hand moves")
    }

    /// A FIRST MOVE UIKIT LEAVES TO THE PAGE IS NO HOLD: a press on a view taken by a long press, moved before it
    /// stood its time - its pan declining it, so no move of it is told after - lifts no view, however long it
    /// stays down.
    @MainActor
    func testAFirstMoveLeftToThePageIsNoLongPress() throws {
        let (clock, told, turn) = (TestClock(), Told(), State(wrappedValue: 0.0))
        let host = UIKitRenderer.running(clock: clock) {
            MotionLayout([0, 1, 2], parameters: turn.projectedValue) { _ in
                Rectangle()
                    .fill(.red)
                    .interaction(.drag(.both, begins: .longPress))
            } placements: { _, at in
                (0..<3).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 80, height: 80)) }
            }
            .interaction(
                .value(turn.projectedValue, input: .translation(.horizontal, unit: .frontItem))
                    .reversed(true).range(0...2).snaps(.every(1)))
            .onItemDragged { told.items.append($0.id) }
            .width(300)
            .height(100)
        }
        defer { host.finish() }
        let element = try XCTUnwrap(host.runtime.tree.root?.first(type: .rectangle))
        let listening = try XCTUnwrap((element.native as? UIKitElement)?.listening)

        // The finger goes down on the first view, as the pan tells it, then moves down two icons' height.
        listening.hand(.began, moved: .zero, point: Point(x: 40, y: 40))
        XCTAssertFalse(listening.handBegins(first: Point(x: 2, y: 40)), "UIKit leaves it to the page")
        for _ in 0..<40 {
            clock.now += 16
            host.frame()
        }

        XCTAssertEqual(told.items, [], "no view lifted")
    }

    /// A VIEW HELD BY ITS LONG PRESS KEEPS THE FIRST MOVE FROM ITS LAYOUT: UIKit gives a touch to one of the two pans,
    /// so the layout's declines a move, whichever way it goes, while a view it places holds the hand - else it takes
    /// the touch, and the held view, its own pan failed, hears neither its moves nor its lift.
    @MainActor
    func testAViewHeldByItsLongPressKeepsTheFirstMoveFromItsLayout() throws {
        let (clock, told, turn) = (TestClock(), Told(), State(wrappedValue: 0.0))
        let host = UIKitRenderer.running(clock: clock) {
            MotionLayout([0, 1, 2], parameters: turn.projectedValue) { _ in
                Rectangle()
                    .fill(.red)
                    .interaction(.drag(.both, begins: .longPress))
            } placements: { _, at in
                (0..<3).map { Placement(Rect(x: (Double($0) - at) * 100, y: 0, width: 80, height: 80)) }
            }
            .interaction(
                .value(turn.projectedValue, input: .translation(.horizontal, unit: .frontItem))
                    .reversed(true).range(0...2).snaps(.every(1)))
            .onItemDragged { told.items.append($0.id) }
            .width(300)
            .height(100)
        }
        defer { host.finish() }
        let element = try XCTUnwrap(host.runtime.tree.root?.first(type: .rectangle))
        let held = try XCTUnwrap((element.native as? UIKitElement)?.listening)
        let placing = try XCTUnwrap((element.handSpace?.native as? UIKitElement)?.listening)

        // The finger goes down on the first view - both pans tell it - and stands still its time.
        placing.hand(.began, moved: .zero, point: Point(x: 40, y: 40))
        held.hand(.began, moved: .zero, point: Point(x: 40, y: 40))
        for _ in 0..<Int(HandReading.longPress / 16) + 4 {
            clock.now += 16
            host.frame()
        }
        XCTAssertFalse(told.items.isEmpty, "held still its time, the view is lifted")

        XCTAssertTrue(held.handBegins(first: Point(x: 30, y: 0)), "the held view's own pan takes the move")
        XCTAssertFalse(placing.handBegins(first: Point(x: 30, y: 0)), "the layout's leaves it, along its way too")
    }
}
