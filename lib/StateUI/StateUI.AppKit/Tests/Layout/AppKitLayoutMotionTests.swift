// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// A layout's children travel to the places a patch gives them, under the
/// layout's motion, and follow a room that moves with no patch behind it.
@MainActor
final class AppKitLayoutMotionTests: XCTestCase {
    /// A vertical stack of 100-wide boxes, 40 tall unless `heights` says
    /// otherwise, in `order`.
    private func stack(
        _ order: [String],
        motion: Motion? = .eased(200, .linear),
        heights: [String: Double] = [:],
        watched: String? = nil
    ) -> HostPatch {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        if let motion { stack.motion = HostLayoutMotion(motion: motion, lanes: .all) }
        stack.children = .arranged(order.map { name in
            var box = HostPatch(id: .manual(name), type: .colorBox)
            box.properties[.width] = .number(100)
            box.properties[.height] = .number(heights[name] ?? 40)
            if name == watched { box.events = .replace([.frameChanged: 7]) }
            return box
        })
        return stack
    }

    /// A label whose width travels lays its words out at the width it is bound
    /// for: midway, its view is already as wide as it lands, so words that fit
    /// there on one line never break at the widths its place passes through.
    @MainActor
    func testATextsWordsStandAtTheWidthItTravelsTo() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        func caption(_ text: String) -> HostPatch {
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.motion = HostLayoutMotion(motion: .eased(200, .linear), lanes: .all)
            var label = HostPatch(id: .manual("caption"), type: .text)
            label.properties = [.text: .string(text), .horizontalAlignment: .enumeration(Alignment.start.rawValue)]
            stack.children = .arranged([label])
            return stack
        }
        renderer.applyForTesting(caption("Text"))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let label = try XCTUnwrap(renderer.viewForTesting(id: .manual("caption")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        let start = label.frame.width

        renderer.applyForTesting(caption("Text & typing"))
        native.layoutSubtreeIfNeeded()
        now = 100
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()
        let midway = label.frame.width
        now = 200
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(label.frame.width, start + 1, "the caption grew")
        XCTAssertEqual(midway, label.frame.width, accuracy: 0.5, "its words at the width it is bound for")
    }

    /// A child a patch moves starts from where it stood, travels on the
    /// layout's law, and lands exactly on its new place.
    @MainActor
    func testAChildAPatchMovesTravelsToItsNewPlace() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(stack(["a", "b"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let moved = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 40, accuracy: 0.001, "the first arrangement is an arrival")

        renderer.applyForTesting(stack(["b", "a"]))
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 40, accuracy: 0.001, "a child starts from where it stood")

        now = 100
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 20, accuracy: 0.001, "halfway through a linear 200 ms animation")

        now = 200
        renderer.advanceAnimationsForTesting()
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 0, accuracy: 0.001, "and it lands exactly")
        XCTAssertFalse(renderer.animatingForTesting)
    }

    /// A room that resizes with no patch behind it holds nothing different:
    /// its children follow it exactly, because a child that glides after the
    /// user's own hand is late every frame.
    @MainActor
    func testARoomThatResizesSnapsItsChildren() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var layout = HostPatch(id: .manual("layout"), type: .zStack)
        layout.motion = HostLayoutMotion(motion: .eased(200, .linear), lanes: .all)
        var box = HostPatch(id: .manual("box"), type: .colorBox)
        box.properties[.width] = .number(50)
        box.properties[.height] = .number(50)
        box.properties[.horizontalAlignment] = .enumeration(Alignment.end.rawValue)
        layout.children = .arranged([box])

        renderer.applyForTesting(layout)
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("layout")))
        let moved = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        native.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minX, 150, accuracy: 0.001)

        now = 50
        native.frame = NSRect(x: 0, y: 0, width: 400, height: 100)
        native.layoutSubtreeIfNeeded()

        XCTAssertEqual(moved.frame.minX, 350, accuracy: 0.001, "the child follows the room exactly")
        XCTAssertFalse(renderer.animatingForTesting, "a resize starts no animation")
    }

    /// A child that joins a standing layout fades in under the layout's law;
    /// the children of a first arrangement are simply there.
    @MainActor
    func testAChildThatJoinsAStandingLayoutFadesIn() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(stack(["a"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        let first = try XCTUnwrap(renderer.viewForTesting(id: .manual("a")))
        XCTAssertEqual(first.alphaValue, 1, accuracy: 0.001, "a first arrangement does not fade")

        renderer.applyForTesting(stack(["a", "b"]))
        native.layoutSubtreeIfNeeded()
        let joined = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        XCTAssertEqual(joined.alphaValue, 0, accuracy: 0.001, "it starts unseen")

        now = 100
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(joined.alphaValue, 0.5, accuracy: 0.001, "halfway on a linear 200 ms fade")

        now = 200
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(joined.alphaValue, 1, accuracy: 0.001)
        XCTAssertFalse(renderer.animatingForTesting)
    }

    /// Where the user asks for less movement, every child arrives and none
    /// fades in.
    @MainActor
    func testUnderReducedMotionEveryChildArrives() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { true })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(stack(["a", "b"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let moved = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()

        renderer.applyForTesting(stack(["b", "a", "c"]))
        native.layoutSubtreeIfNeeded()
        let joined = try XCTUnwrap(renderer.viewForTesting(id: .manual("c")))

        XCTAssertEqual(moved.frame.minY, 0, accuracy: 0.001)
        XCTAssertEqual(joined.alphaValue, 1, accuracy: 0.001)
        XCTAssertFalse(renderer.animatingForTesting)
    }
}
#endif
