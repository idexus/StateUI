// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// A layout's children travel to the places a patch gives them, under the
/// layout's motion, and follow a room that moves with no patch behind it.
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

    /// An absolute layout holding one 50 x 50 box at `y`, or nothing.
    private func absolute(y: Double?) -> HostPatch {
        var layout = HostPatch(id: .manual("layout"), type: .absoluteLayout)
        layout.motion = HostLayoutMotion(motion: .eased(200, .linear), lanes: .all)
        layout.children = .arranged(y.map { y in
            var box = HostPatch(id: .manual("box"), type: .colorBox)
            box.properties[.absoluteLayoutBounds] = .numbers([0, y, 50, 50])
            return [box]
        } ?? [])
        return layout
    }

    /// A child a patch moves starts from where it stood, travels on the
    /// layout's law, and lands exactly on its new place.
    @MainActor
    func testAChildAPatchMovesTravelsToItsNewPlace() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
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
        renderer.stepTripsForTesting()
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 20, accuracy: 0.001, "halfway on a linear 200 ms walk")

        now = 200
        renderer.stepTripsForTesting()
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 0, accuracy: 0.001, "and it lands exactly")
        XCTAssertFalse(renderer.tripsMovingForTesting)
    }

    /// A room that resizes with no patch behind it holds nothing different:
    /// its children follow it exactly, because a child that glides after the
    /// reader's own hand is late every frame.
    @MainActor
    func testARoomThatResizesSnapsItsChildren() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var layout = HostPatch(id: .manual("layout"), type: .absoluteLayout)
        layout.motion = HostLayoutMotion(motion: .eased(200, .linear), lanes: .all)
        var box = HostPatch(id: .manual("box"), type: .colorBox)
        box.properties[.absoluteLayoutBounds] = .numbers([1, 0, 50, 50])
        box.properties[.absoluteLayoutProportions] = .enumeration(1)
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
        XCTAssertFalse(renderer.tripsMovingForTesting, "a resize starts no trip")
    }

    /// A size a child states for itself arrives at once - it is either still
    /// or moving on its own - while the places it changes still travel.
    @MainActor
    func testAStatedSizeArrivesWhileThePlacesItMovesTravel() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(stack(["a", "b"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let grown = try XCTUnwrap(renderer.viewForTesting(id: .manual("a")))
        let below = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()

        renderer.applyForTesting(stack(["a", "b"], heights: ["a": 80]))
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(grown.frame.height, 80, accuracy: 0.001, "the stated height arrives")
        XCTAssertEqual(below.frame.minY, 40, accuracy: 0.001, "the child below starts where it stood")

        now = 100
        renderer.stepTripsForTesting()
        XCTAssertEqual(below.frame.minY, 60, accuracy: 0.001, "and travels to its new place")
    }

    /// Where a frame under a layout is read, every child arrives: each step of
    /// a walk would hand the reader a room nobody chose.
    @MainActor
    func testALayoutWhoseFramesAreReadPlacesItsChildrenAtOnce() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(stack(["a", "b"], watched: "a"))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let moved = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()

        renderer.applyForTesting(stack(["b", "a"], watched: "a"))
        native.layoutSubtreeIfNeeded()

        XCTAssertEqual(moved.frame.minY, 0, accuracy: 0.001)
        XCTAssertFalse(renderer.tripsMovingForTesting)
    }

    /// A child that joins a standing layout fades in under the layout's law;
    /// the children of a first arrangement are simply there.
    @MainActor
    func testAChildThatJoinsAStandingLayoutFadesIn() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
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
        renderer.stepTripsForTesting()
        XCTAssertEqual(joined.alphaValue, 0.5, accuracy: 0.001, "halfway on a linear 200 ms fade")

        now = 200
        renderer.stepTripsForTesting()
        XCTAssertEqual(joined.alphaValue, 1, accuracy: 0.001)
        XCTAssertFalse(renderer.tripsMovingForTesting)
    }

    /// A layout told to move nothing places its children at once, and a child
    /// that joins it is simply there - which is what a list says of its rows.
    @MainActor
    func testALayoutToldToMoveNothingPlacesAtOnce() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(stack(["a", "b"], motion: Motion.none))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let moved = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()

        renderer.applyForTesting(stack(["b", "a", "c"], motion: Motion.none))
        native.layoutSubtreeIfNeeded()
        let joined = try XCTUnwrap(renderer.viewForTesting(id: .manual("c")))

        XCTAssertEqual(moved.frame.minY, 0, accuracy: 0.001)
        XCTAssertEqual(joined.alphaValue, 1, accuracy: 0.001)
        XCTAssertFalse(renderer.tripsMovingForTesting)
    }

    /// A layout that says nothing of its own travels the way the application
    /// says, once, for every layout in it.
    @MainActor
    func testALayoutThatSaysNothingTravelsTheApplicationsWay() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        func application(_ order: [String]) -> HostPatch {
            var page = HostPatch(id: .manual("page"), type: .page)
            page.children = .arranged([stack(order, motion: nil)])
            var window = HostPatch(id: .manual("window"), type: .window)
            window.children = .arranged([page])
            var scene = HostPatch(id: .manual("scene"), type: .scene)
            scene.children = .arranged([window])
            var application = HostPatch(id: .manual("application"), type: .application)
            application.motion = HostLayoutMotion(motion: .eased(200, .linear), lanes: .all)
            application.children = .arranged([scene])
            return application
        }

        renderer.applyForTesting(application(["a", "b"]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        let moved = try XCTUnwrap(renderer.viewForTesting(id: .manual("b")))
        native.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        native.layoutSubtreeIfNeeded()
        let stood = moved.frame.minY

        renderer.applyForTesting(application(["b", "a"]))
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, stood, accuracy: 0.001, "a child starts from where it stood")

        now = 100
        renderer.stepTripsForTesting()
        XCTAssertEqual(moved.frame.minY, stood - 20, accuracy: 0.001, "on the application's law")
    }

    /// A child that leaves takes its trip with it: nothing walks a place for
    /// an element the tree no longer holds.
    @MainActor
    func testAChildThatLeavesEndsItsTrip() throws {
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { 0 },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(absolute(y: 0))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("layout")))
        native.frame = NSRect(x: 0, y: 0, width: 200, height: 400)
        native.layoutSubtreeIfNeeded()

        renderer.applyForTesting(absolute(y: 100))
        native.layoutSubtreeIfNeeded()
        XCTAssertTrue(renderer.tripsMovingForTesting)

        renderer.applyForTesting(absolute(y: nil))
        XCTAssertFalse(renderer.tripsMovingForTesting)
    }

    /// A place that changes mid-walk bends the trip from where the child
    /// stands, rather than starting it again from where it was going.
    @MainActor
    func testAPlaceChangedMidWalkBendsFromWhereTheChildStands() throws {
        var now = 0.0
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(absolute(y: 0))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("layout")))
        let moved = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        native.frame = NSRect(x: 0, y: 0, width: 200, height: 400)
        native.layoutSubtreeIfNeeded()

        renderer.applyForTesting(absolute(y: 100))
        native.layoutSubtreeIfNeeded()
        now = 100
        renderer.stepTripsForTesting()
        XCTAssertEqual(moved.frame.minY, 50, accuracy: 0.001)

        renderer.applyForTesting(absolute(y: 200))
        native.layoutSubtreeIfNeeded()
        XCTAssertEqual(moved.frame.minY, 50, accuracy: 0.001, "it bends from where it stands")

        now = 150
        renderer.stepTripsForTesting()
        XCTAssertGreaterThan(moved.frame.minY, 50, "and goes on, never back")
        XCTAssertLessThan(moved.frame.minY, 200)

        now = 300
        renderer.stepTripsForTesting()
        XCTAssertEqual(moved.frame.minY, 200, accuracy: 0.001)
        XCTAssertFalse(renderer.tripsMovingForTesting)
    }

    /// Where the reader asks for less movement, every child arrives and none
    /// fades in.
    @MainActor
    func testUnderReducedMotionEveryChildArrives() throws {
        let renderer = AppKitRenderer(
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
        XCTAssertFalse(renderer.tripsMovingForTesting)
    }
}
#endif
