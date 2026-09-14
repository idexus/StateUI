// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitGestureTests: XCTestCase {
    @MainActor
    func testPanPinchAndPointerUseTheStableStateUIPayloads() throws {
        var reports: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reports.append(($0, $1)) })
        defer { renderer.closeForTesting() }
        var box = HostPatch(id: .manual("box"), type: .colorBox)
        box.events = .replace([
            .panUpdated: 10,
            .pinchUpdated: 11,
            .pointerEntered: 12,
            .pointerMoved: 13,
            .pointerPressed: 14,
            .pointerReleased: 15,
            .pointerExited: 16,
        ])
        renderer.applyForTesting(tree(box))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        let pan = try XCTUnwrap(
            native.gestureRecognizers.compactMap { $0 as? AppKitPanRecognizer }.first)
        let pinch = try XCTUnwrap(
            native.gestureRecognizers.compactMap { $0 as? AppKitPinchRecognizer }.first)
        let pointer = try XCTUnwrap(
            native.gestureRecognizers.compactMap { $0 as? AppKitPointerRecognizer }.first)

        pan.emitForTesting(.running, total: NSPoint(x: 8, y: 5))
        pinch.emitForTesting(.running, scale: 1.25, origin: NSPoint(x: 0.2, y: 0.7))
        pointer.emitForTesting(.entered)
        pointer.emitForTesting(.moved, point: NSPoint(x: 3, y: 4))
        pointer.emitForTesting(.pressed, point: NSPoint(x: 5, y: 6))
        pointer.emitForTesting(.released, point: NSPoint(x: 7, y: 8))
        pointer.emitForTesting(.exited)

        XCTAssertEqual(reports.map(\.0), [10, 11, 12, 13, 14, 15, 16])
        XCTAssertEqual(reports[0].1, [.enumeration(1), .number(8), .number(5)])
        XCTAssertEqual(reports[1].1, [
            .enumeration(1), .number(1.25), .numbers([0.2, 0.7]),
        ])
        XCTAssertEqual(reports[2].1, [])
        XCTAssertEqual(reports[3].1, [.numbers([3, 4])])
        XCTAssertEqual(reports[4].1, [.numbers([5, 6])])
        XCTAssertEqual(reports[5].1, [.numbers([7, 8])])
        XCTAssertEqual(reports[6].1, [])
    }

    @MainActor
    func testPanMovesAHostJourneyFromWhereThePointerLanded() throws {
        Renderer.shared.clearInvalidation()
        defer { Renderer.shared.clearInvalidation() }
        let across = State(wrappedValue: 10.0)
        let differ = Differ()
        differ.motion = .standard
        let rendered = differ.reconcile(
            nil,
            with: ColorBox(.transparent).panX(across.projectedValue).body,
            changed: [])
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(rendered.patch))

        let native = try XCTUnwrap(renderer.viewForTesting(id: rendered.patch.id))
        let pan = try XCTUnwrap(
            native.gestureRecognizers.compactMap { $0 as? AppKitPanRecognizer }.first)
        pan.emitForTesting(.started, total: .zero)
        pan.emitForTesting(.running, total: NSPoint(x: 7, y: 0))

        XCTAssertEqual(across.projectedValue.journey.value, 17)
    }

    @MainActor
    func testRemovingPointerEventsDetachesTheNativeRecognizer() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var box = HostPatch(id: .manual("box"), type: .colorBox)
        box.events = .replace([.pointerEntered: 20])
        renderer.applyForTesting(tree(box))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        XCTAssertEqual(
            native.gestureRecognizers.compactMap { $0 as? AppKitPointerRecognizer }.count,
            1)

        var changed = HostPatch(id: .manual("box"), type: .colorBox)
        changed.events = .replace([:])
        renderer.applyForTesting(changedTree(changed))

        XCTAssertTrue(
            native.gestureRecognizers.compactMap { $0 as? AppKitPointerRecognizer }.isEmpty)
    }

    @MainActor
    func testSwipeReportsOneDominantAllowedDirectionBeyondItsThreshold() throws {
        var reports: [[HostValue]] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { _, payload in reports.append(payload) })
        defer { renderer.closeForTesting() }
        var box = HostPatch(id: .manual("box"), type: .colorBox)
        box.properties = [
            .swipeDirection: .enumeration(3),
            .swipeThreshold: .number(50),
        ]
        box.events = .replace([.swiped: 30])
        renderer.applyForTesting(tree(box))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        let swipe = try XCTUnwrap(
            native.gestureRecognizers.compactMap { $0 as? AppKitSwipeRecognizer }.first)
        swipe.emitForTesting(total: NSPoint(x: -40, y: 0))
        swipe.emitForTesting(total: NSPoint(x: 10, y: 70))
        swipe.emitForTesting(total: NSPoint(x: -60, y: 55))

        XCTAssertEqual(reports, [[.enumeration(2)]])
    }
}

#endif
