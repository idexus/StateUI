// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A layout engine: what its arithmetic is handed, where the run puts each child, how the program and the hand move
// the phase, and what it says of an answer it cannot use. The gallery's tests hold the hand at full length.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class LayoutEngineTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// What the arithmetic was handed, a class so the closure that writes it is not walked for state.
    private final class Handed {
        var rooms: [Rect] = []
        var phases: [Double] = []
    }

    /// Where the display clock stands, so two turns in one test are two instants.
    private var turned = 0.0

    /// One cycle of the display's board.
    private func cycle() {
        turned += 16
        _ = Renderer.shared.board(for: .display).cycle(now: turned, reducesMotion: false)
    }

    /// One frame as the host runs it: the board's cycle, and what it wrote read out, so a report after it lands.
    private func frame() {
        turned += 16
        _ = HostBoundary.cycle(.display, now: turned, reducesMotion: false)
    }

    /// The first node of a kind, however deep it sits.
    private func find(_ type: NodeType, in patch: HostPatch) -> HostPatch? {
        if patch.type == type { return patch }

        for child in patch.children {
            if let found = find(type, in: child) { return found }
        }

        return nil
    }

    /// Tells every frame reader in `tree` its room and renders again, until none stands untold - the scroller
    /// stands once its reader knows its room: the whole layout as it stands on screen.
    private func stood(_ renders: Renders, _ tree: () -> Node) -> HostPatch {
        var told: Set<Int> = []
        _ = renders.render(tree())

        for _ in 0..<3 {
            // The whole description: a patch says nothing of a handler that did not change.
            let patch = renders.renderFromScratch(tree())
            var untold: [Int] = []
            func walk(_ node: HostPatch) {
                if let id = node.events?[.frameChanged], !told.contains(id) { untold.append(id) }
                node.children.forEach(walk)
            }
            walk(patch)
            guard !untold.isEmpty else { break }

            for id in untold {
                XCTAssertTrue(renders.fire(id, with: [.numbers([0, 0, 300, 200, 0, 0, 0, 0])]))
                told.insert(id)
            }
            _ = renders.render(tree())
        }

        return renders.renderFromScratch(tree())
    }

    /// Renders `tree`, feeds the layout the room `room` as the host does, and turns the board until the arithmetic
    /// has answered: the run of placements the layout's own area carries.
    private func laid(
        _ renders: Renders, _ tree: () -> Node, room: Rect = Rect(10, 20, 300, 200),
        file: StaticString = #filePath, line: UInt = #line
    ) -> (patch: HostPatch, run: [Placement]) {
        let patch = renders.render(tree())

        guard let layout = find(.layoutEngine, in: patch),
              let fed = layout.driven?[.frame]?.state,
              let placed = layout.driven?[.area]?.state
        else {
            XCTFail("the layout is placed by no number", file: file, line: line)
            return (patch, [])
        }

        // THE FIRST CYCLE OF ALL LATCHES rather than runs, so the room is fed after it.
        cycle()
        moved(fed, to: [room.x, room.y, room.width, room.height])
        cycle()

        return (patch, standing(placed, as: PlacedRun.self)?.placements ?? [])
    }

    // MARK: - The arithmetic

    /// THE ROOM FROM THE LAYOUT'S OWN TOP LEFT: the arithmetic is handed the size the layout was given at the
    /// origin, wherever the layout stands in its parent, and the phase as it stands.
    func testTheArithmeticIsHandedItsRoomFromItsOwnTopLeft() {
        let handed = Handed()

        _ = laid(Renders(), {
            LayoutEngine([1, 2]) { Text("\($0)") } placements: { room, phase in
                handed.rooms.append(room)
                handed.phases.append(phase)
                return [Placement(Rect(0, 0, 10, 10)), Placement(Rect(20, 0, 10, 10))]
            }
            .node
        })

        XCTAssertEqual(handed.rooms.last, Rect(0, 0, 300, 200))
        XCTAssertEqual(handed.phases.last, 0)
    }

    /// THE VIEWS FIRST, IN THE ITEMS' ORDER, then the scroller over them across the whole room: one run places every
    /// child of the element.
    func testTheRunPlacesTheViewsThenTheScroller() {
        let (_, run) = laid(Renders(), {
            LayoutEngine([1, 2]) { Text("\($0)") } placements: { _, _ in
                [Placement(Rect(0, 0, 10, 10), zIndex: 5), Placement(Rect(20, 0, 10, 10))]
            }
            .input(.scroll(.horizontal, pointsPerUnit: 100))
            .snapTargets([0, 1])
            .node
        })

        XCTAssertEqual(run.map(\.bounds), [Rect(0, 0, 10, 10), Rect(20, 0, 10, 10), Rect(0, 0, 300, 200)])
        XCTAssertEqual(run[2].zIndex, 2, "the scroller over every view")
    }

    /// ON A DESKTOP A DRAG IS HEARD ON THE SCROLLER: it spans the room and stands still while its content slides, so
    /// the drag lands anywhere and is measured in a frame the run does not move under the hand.
    func testOnADesktopADragIsHeardOnTheScroller() throws {
        StandardEnvironment.device.info.formFactor = .desktop
        defer { StandardEnvironment.device.info.formFactor = .unknown }
        let renders = Renders()
        func tree() -> Node {
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .input(.scroll(.horizontal, pointsPerUnit: 100))
                .snapTargets([0, 1])
                .node
        }

        _ = laid(renders, tree)
        let scroller = try XCTUnwrap(find(.scrollView, in: stood(renders, tree)))

        XCTAssertNotNil(scroller.events?[.panUpdated], "the drag heard on the scroller")
        XCTAssertNil(scroller.children.first?.events?[.panUpdated], "never on the content sliding under it")
    }

    /// AN ANSWER OF THE WRONG LENGTH IS SAID AND MADE TO FIT: one placement a view, the rest at the top left.
    func testAnAnswerOfTheWrongLengthIsSaidAndMadeToFit() {
        let (_, run) = laid(Renders(), {
            LayoutEngine([1, 2, 3]) { Text("\($0)") } placements: { _, _ in [Placement(Rect(5, 5, 10, 10))] }.node
        })

        XCTAssertEqual(run.prefix(3).map(\.bounds), [Rect(5, 5, 10, 10), .zero, .zero])
        XCTAssertTrue(hasComplained("placements answered 1 placements for 3 views"))
    }

    // MARK: - The phase

    /// THE LAYOUT'S ELEMENT WEARS ITS PHASE, both ways, so the host walks it under the layout's motion and says where
    /// it stands every frame: what makes a move of the phase travel, and an awaited one arrive.
    func testTheLayoutsElementWearsItsPhase() async throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node {
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .phase(phase.projectedValue)
                .node
        }

        let (patch, _) = laid(renders, tree)
        let worn = try XCTUnwrap(find(.layoutEngine, in: patch)?.driven?[.phase])

        XCTAssertEqual(worn.mode, .inOut)
        XCTAssertEqual(worn.kind, .property)

        phase.wrappedValue = 2
        cycle()
        XCTAssertEqual(try XCTUnwrap(standing(worn.state, as: JourneyLanes<Double>.self)).destination, 2,
                       "the phase written is where the host walks it")
    }

    /// A PHASE IS A STATE: a binding worked out from others cannot be worn, so it is said once - its phase would jump.
    func testAPhaseWorkedOutFromOthersIsSaid() {
        var stored = 0.0
        _ = Renders().render(
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [] }
                .phase(Binding(get: { stored }, set: { stored = $0 }))
                .node)

        XCTAssertTrue(hasComplained("A LayoutEngine's phase is a state lent with `$`"))
    }

    /// WITHOUT A HAND THE PHASE TRAVELS AS THE HOST WALKS IT: a write is where the run goes, and the arithmetic is
    /// handed each frame where the host says the phase stands - never the destination at once.
    func testWithoutAHandThePhaseTravelsAsTheHostWalksIt() async throws {
        let handed = Handed()
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node {
            LayoutEngine([1]) { Text("\($0)") } placements: { _, phase in
                handed.phases.append(phase)
                return [Placement(Rect(phase * 10, 0, 10, 10))]
            }
            .phase(phase.projectedValue)
            .node
        }

        let (patch, _) = laid(renders, tree)
        let worn = try XCTUnwrap(find(.layoutEngine, in: patch)?.driven?[.phase]?.state)

        phase.wrappedValue = 2
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)
        _ = await settle()
        cycle()
        XCTAssertEqual(handed.phases.last, 0, "the write is where it goes; the host has walked nothing yet")

        moved(worn, to: 1)
        cycle()
        XCTAssertEqual(handed.phases.last, 1, "a frame on the way")

        moved(worn, to: [2, 2, 0], mask: 0b111)
        cycle()
        XCTAssertEqual(handed.phases.last, 2, "and where it landed")
    }

    /// A SCROLL PASSING A TARGET NAMES THE NEAREST, uneven ones too, as the hand passes halfway between two.
    func testAScrollNamesTheNearestOfUnevenTargets() throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        func tree() -> Node {
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
                .phase(phase.projectedValue)
                .input(.scroll(.horizontal, pointsPerUnit: 100))
                .snapTargets([0, 0.2, 0.5, 1])
                .node
        }

        let worn = try XCTUnwrap(find(.layoutEngine, in: laid(renders, tree).patch)?.driven?[.phase]?.state)
        let offset = try XCTUnwrap(find(.scrollView, in: stood(renders, tree))?.driven?[.scrollOffset]?.state)

        slid(offset, to: Point(40, 0))
        cycle()
        XCTAssertEqual(phase.wrappedValue, 0.5, "0.4 is nearer 0.5 than 0.2")
        let named = try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self))
        XCTAssertEqual(named.value, 0.5, "named where it stands: a reading of the hand, not a journey")

        slid(offset, to: Point(10, 0))
        cycle()
        XCTAssertEqual(phase.wrappedValue, 0, "0.1 is nearer 0 than 0.2")
    }

    /// A SCROLL STARTS WHERE THE PHASE SAYS: until the scroller reports its first layout its offset is nobody's, so
    /// the run is worked out from the phase asked and names nothing, and the scroller is then sent there.
    func testAScrollStartsWhereThePhaseSays() throws {
        let phase = State(wrappedValue: 2.0)
        let handed = Handed()
        let renders = Renders()
        func tree() -> Node {
            LayoutEngine([0, 1, 2]) { Text("\($0)") } placements: { _, at in
                handed.phases.append(at)
                return (0..<3).map { _ in Placement(Rect(0, 0, 10, 10)) }
            }
            .phase(phase.projectedValue)
            .input(.scroll(.horizontal, pointsPerUnit: 100))
            .snapTargets([0, 1, 2])
            .node
        }

        _ = laid(renders, tree)

        XCTAssertEqual(phase.wrappedValue, 2, "named by no scroller laid out yet")
        XCTAssertEqual(Set(handed.phases), [2], "worked out from the phase asked, never from a scroller at its start")

        let offset = try XCTUnwrap(find(.scrollView, in: stood(renders, tree))?.driven?[.scrollOffset]?.state)
        cycle()

        XCTAssertEqual(try XCTUnwrap(standing(offset, as: JourneyLanes<Point>.self)).destination.x, 200, accuracy: 0.001)
        XCTAssertEqual(phase.wrappedValue, 2, "and the phase it started at kept")
    }

    /// UNDER A SCROLL THE SCROLLER FOLLOWS THE PHASE ON ITS WAY: the program's write travels as the phase, and each
    /// frame the scroller is snapped to where the phase stands, so a scroll and its arithmetic never part.
    func testUnderAScrollTheScrollerFollowsThePhaseOnItsWay() async throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        let (worn, offset) = try scrolled(renders, phase)

        phase.wrappedValue = 1
        cycle()
        moved(worn, to: 0.25)
        cycle()

        let followed = try XCTUnwrap(standing(offset, as: JourneyLanes<Point>.self))
        XCTAssertEqual(followed.value.x, 25, accuracy: 0.001, "where the phase stands")
        XCTAssertEqual(followed.destination.x, 25, accuracy: 0.001, "snapped there, travelling nowhere of its own")
        XCTAssertEqual(phase.wrappedValue, 1, "and the phase still going where the program sent it")
    }

    /// A HAND TAKING THE RUN ON ITS WAY STOPS THE PHASE'S TRAVEL: the scroller leads again, and the phase is named
    /// where the hand holds it rather than going on where the program sent it.
    func testAHandTakingTheRunOnItsWayStopsThePhasesTravel() async throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        let (worn, offset) = try scrolled(renders, phase)

        phase.wrappedValue = 1
        frame()
        moved(worn, to: 0.3)
        frame()
        slid(offset, to: Point(60, 0))
        frame()

        let journey = try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self))
        XCTAssertEqual(journey.destination, 0.5, "the target nearest the hand, no longer the program's")
        XCTAssertEqual(journey.value, 0.5, "named where the hand holds it")
        XCTAssertEqual(phase.wrappedValue, 0.5)
    }

    /// AT REST THE RUN TRAVELS ON FROM WHERE THE HAND LEFT IT: the phase stands where the scroller stopped and goes
    /// to the nearest target as a journey of its own, which the scroller follows.
    func testAtRestTheRunTravelsOnFromWhereTheHandLeftIt() async throws {
        let phase = State(wrappedValue: 0.0)
        let renders = Renders()
        let (worn, offset) = try scrolled(renders, phase)
        let stopped = try XCTUnwrap(find(.scrollView, in: renders.renderFromScratch(scrollingTree(phase)))?
            .events?[.scrollStopped])

        slid(offset, to: Point(40, 0))
        cycle()
        XCTAssertTrue(renders.fire(stopped))
        cycle()

        let journey = try XCTUnwrap(standing(worn, as: JourneyLanes<Double>.self))
        XCTAssertEqual(journey.value, 0.4, accuracy: 0.001, "from where the hand left it")
        XCTAssertEqual(journey.destination, 0.5, "to the nearest target")
    }

    /// A layout scrolled over targets 0, 0.5 and 1, a hundred points a unit.
    private func scrollingTree(_ phase: State<Double>) -> Node {
        LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [Placement(Rect(0, 0, 10, 10))] }
            .phase(phase.projectedValue)
            .input(.scroll(.horizontal, pointsPerUnit: 100))
            .snapTargets([0, 0.5, 1])
            .node
    }

    /// The scrolled layout laid out and its scroller standing: the numbers of the phase it wears and of the
    /// scroller's offset.
    private func scrolled(_ renders: Renders, _ phase: State<Double>) throws -> (phase: Int32, offset: Int32) {
        let (patch, _) = laid(renders, { scrollingTree(phase) })
        let worn = try XCTUnwrap(find(.layoutEngine, in: patch)?.driven?[.phase]?.state)
        let offset = try XCTUnwrap(find(.scrollView, in: stood(renders, { scrollingTree(phase) }))?
            .driven?[.scrollOffset]?.state)
        cycle()

        return (worn, offset)
    }

    /// A SCROLL NEEDS ITS TARGETS: they say how far it runs, so one given none lays no scroller and says why.
    func testAScrollWithNoSnapTargetsLaysNoScroller() {
        let patch = Renders().render(
            LayoutEngine([1]) { Text("\($0)") } placements: { _, _ in [] }
                .input(.scroll(.vertical, pointsPerUnit: 50))
                .node)

        XCTAssertNil(find(.scrollView, in: patch))
        XCTAssertTrue(hasComplained("given a scroll but no snapTargets"))
    }

    // MARK: - A tap

    /// WITHOUT A HAND A TAP LANDS ON THE VIEW ITSELF, with its item: nothing lies over the views.
    func testWithoutAScrollATapLandsOnTheViewItself() async throws {
        var heard: [Int] = []
        let renders = Renders()
        let patch = renders.render(
            LayoutEngine([7, 8]) { Text("\($0)") } placements: { _, _ in [] }
                .onItemTapped { heard.append($0) }
                .node)
        let layout = try XCTUnwrap(find(.layoutEngine, in: patch))
        let tap = try XCTUnwrap(layout.children[1].events?[.tapped])

        XCTAssertTrue(renders.fire(tap))
        _ = await settle()

        XCTAssertEqual(heard, [8])
    }
}

