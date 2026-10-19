// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import StateUIConformance
import XCTest

@MainActor
final class AppKitGestureTests: XCTestCase {
    @MainActor
    func testRemovingPointerEventsDetachesTheNativeRecognizer() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var box = HostPatch(id: .manual("box"), type: .rectangle)
        box.events = .replace([.pointerEntered: 20])
        renderer.applyForTesting(tree(box))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        XCTAssertEqual(
            native.gestureRecognizers.compactMap { $0 as? AppKitPointerRecognizer }.count,
            1)

        var changed = HostPatch(id: .manual("box"), type: .rectangle)
        changed.events = .replace([:])
        renderer.applyForTesting(changedTree(changed))

        XCTAssertTrue(
            native.gestureRecognizers.compactMap { $0 as? AppKitPointerRecognizer }.isEmpty)
    }

    /// A pan asked of one pointer is recognised and reaches its handler. A
    /// pan asked of two leaves the view no pan recogniser: AppKit recognises a
    /// one-pointer drag only, so it cannot honour that count.
    @MainActor
    func testOnlyAOnePointerPanIsRecognised() throws {
        let totals = Received<Double>()
        let renderer = AppKitRenderer.running {
            VStack {
                Rectangle().fill(.red).onPanUpdated(touchCount: 1) { totals.values.append($0.totalX) }
                Rectangle().fill(.blue).onPanUpdated(touchCount: 2) { totals.values.append($0.totalX) }
            }
        }
        defer { renderer.closeForTesting() }
        let boxes = renderer.nativeViews(AppKitShapeView.self)
        XCTAssertEqual(boxes.count, 2)
        guard boxes.count == 2 else { return }
        let onePointer = boxes[0].gestureRecognizers.compactMap { $0 as? AppKitPanRecognizer }
        let twoPointers = boxes[1].gestureRecognizers.compactMap { $0 as? AppKitPanRecognizer }

        XCTAssertEqual(onePointer.count, 1)
        XCTAssertTrue(twoPointers.isEmpty)

        onePointer.first?.dragged(.changed, x: 8, y: 5)

        XCTAssertEqual(totals.values, [8])
    }

    /// ⌥ AND A DRAG ARE TWO FINGERS: a layout two fingers move wears a recognizer of a press with ⌥ - and a press
    /// without it, it leaves - whose press and its mirror about the middle spread the magnification as the press goes
    /// twice as far from it.
    @MainActor
    func testAnOptionDragIsTwoFingers() throws {
        let zoom = State(wrappedValue: 1.0)
        let renderer = AppKitRenderer.running {
            LayoutEngine([0, 1]) { Text("\($0)") } placements: { _, at in
                [Placement(Rect(0, 0, 10 * at, 10)), Placement(Rect(20, 0, 10, 10))]
            }
            .phase(zoom.projectedValue)
            .axis(\.self, input: .magnification, range: 1...3, snaps: [2])
        }
        defer { renderer.closeForTesting() }
        let mirrored = try XCTUnwrap(
            renderer.nativeViews(AppKitZStackView.self).lazy
                .compactMap { $0.gestureRecognizers.compactMap { $0 as? AppKitMirroredRecognizer }.first }.first)

        XCTAssertTrue(AppKitMirroredRecognizer.takes([.option]))
        XCTAssertFalse(AppKitMirroredRecognizer.takes([]), "a press without ⌥ is the hand's")

        let middle = Point(150, 100)
        mirrored.mirrored(.began, at: Point(200, 100), middle: middle)
        mirrored.mirrored(.changed, at: Point(250, 100), middle: middle)
        for _ in 0..<150 {
            guard zoom.wrappedValue != 2 else { break }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            renderer.runtime.displayCycle.frame(now: renderer.runtime.clock.now())
            renderer.runtime.pump.turn()
        }

        XCTAssertEqual(zoom.wrappedValue, 2, "twice as far from the middle: twice as large")
    }

    /// A view that answers a tap takes the first click into an inactive window,
    /// as a native control does - so a row opens wherever it is clicked, not only
    /// on its text. A view that answers nothing leaves that click to activate
    /// the window.
    @MainActor
    func testAViewThatAnswersATapTakesTheFirstClick() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                HStack { Text("Fundamentals") }.onTapped {}
                HStack { Text("Plain") }
            }
        }
        defer { renderer.closeForTesting() }
        let stacks = renderer.nativeViews(AppKitStackView.self)
        XCTAssertEqual(stacks.count, 3)

        XCTAssertTrue(stacks[1].acceptsFirstMouse(for: nil), "the row that answers a tap")
        XCTAssertFalse(stacks[2].acceptsFirstMouse(for: nil), "the row that answers nothing")
        XCTAssertFalse(stacks[0].acceptsFirstMouse(for: nil), "the stack around them")
    }
}

#endif
