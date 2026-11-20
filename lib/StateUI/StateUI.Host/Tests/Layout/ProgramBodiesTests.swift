// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A change of a motion layout where its parameters stand, seen whole: the layout answers where each view goes, and
/// the host brings each from where it was shown - a view leaving and the others closing up, one joining, a new
/// order, a value read in the body, a change on its way changed again - while the parameters keep their own move.
/// Design: docs/design/views/motion-layout.md#a-change-where-the-parameters-stand
@MainActor
final class ProgramBodiesTests: XCTestCase {
    private let quick = Duration.milliseconds(160)

    /// A row of `items`, `gap` apart, moved a gap a unit of `phase`: every view the body `bodies`, the first of
    /// them `own` where one is given.
    private struct Row: View {
        let items: Binding<[Int]>
        let gap: Binding<Double>
        let phase: Binding<Double>
        var bodies: LayoutBody
        var own: LayoutBody?
        var settled: Settles?

        var body: some View {
            let (shown, apart, own, settled) = (items.wrappedValue, gap.wrappedValue, own, settled)
            let first = shown.first

            return MotionLayout(shown, parameters: phase) { item in
                if let own, item == first {
                    Text("\(item)").layoutBody(own)
                } else {
                    Text("\(item)")
                }
            } placements: { _, at in
                shown.indices.map { Placement(Rect(x: (Double($0) - at) * apart, y: 0, width: 10, height: 10)) }
            }
            .layoutBodies(bodies)
            .onSettled { _ in settled?.count += 1 }
        }
    }

    /// How many times a layout said it came to rest.
    private final class Settles {
        var count = 0
    }

    /// The states a test moves, and the row built on them.
    @MainActor
    private struct Scene {
        let items = State(wrappedValue: [0, 1, 2])
        let gap = State(wrappedValue: 100.0)
        let phase = State(wrappedValue: 0.0, motion: .none)

        func bench(
            bodies: LayoutBody, own: LayoutBody? = nil, settled: Settles? = nil, reducesMotion: Bool = false
        ) throws -> Bench {
            let row = Row(
                items: items.projectedValue, gap: gap.projectedValue, phase: phase.projectedValue, bodies: bodies,
                own: own, settled: settled)
            return try Bench(reducesMotion: reducesMotion) { row }
        }
    }

    /// A page on a real runtime whose native halves keep nothing: mounted, its layout told a room, and turned frame
    /// by frame on a clock wound by hand.
    @MainActor
    private final class Bench {
        let runtime: HostRuntime
        let layout: MountedElement
        private let clock = WoundClock()

        init(reducesMotion: Bool, @ViewBuilder _ page: @escaping @MainActor () -> any View) throws {
            Renderer.shared.setApplication(OneWindowApplication(page: page))
            runtime = HostRuntime(clock: clock, reducesMotion: { reducesMotion }, makeNative: { _ in NoView() }, log: { _ in })
            runtime.connectWindow()
            runtime.pump.turn()
            layout = try XCTUnwrap(runtime.tree.root?.first(type: .motionLayout))
            layout.reportFrame([0, 0, 300, 200, 0, 0, 0, 0], in: runtime)
            frames(2)
        }

        /// `count` frames of the display, a turn before each.
        func frames(_ count: Int) {
            for _ in 0..<count {
                runtime.pump.turn()
                clock.time += 16
                runtime.displayCycle.frame(now: clock.time)
            }
        }

        /// Where the layout's views are shown now, across.
        var shown: [Double] { layout.placement?.placements.map(\.bounds.x) ?? [] }

        var placements: [HostPlacement] { layout.placement?.placements ?? [] }
    }

    /// A VIEW LEAVING GOES AT ONCE, AND THE OTHERS CLOSE UP from where they stood, on the layout's bodies' spring.
    func testTheOthersCloseUpFromWhereTheyStood() throws {
        let scene = Scene()
        let bench = try scene.bench(bodies: .onChange(response: quick))

        scene.items.wrappedValue = [1, 2]
        bench.frames(1)
        XCTAssertEqual(bench.shown.count, 2, "the view left at once")
        XCTAssertEqual(bench.shown[0], 100, accuracy: 12, "a frame of its spring from where it stood")

        bench.frames(5)
        XCTAssertLessThan(bench.shown[0], 100, "on its way")
        XCTAssertGreaterThan(bench.shown[0], 0)

        bench.frames(60)
        XCTAssertEqual(bench.shown[0], 0, accuracy: 0.001, "where its arithmetic puts it")
        XCTAssertFalse(bench.runtime.tree.layoutBodiesMove)
    }

    /// A VIEW JOINING FADES IN where its arithmetic puts it, the others as they were.
    func testAViewJoiningFadesIn() throws {
        let scene = Scene()
        scene.items.wrappedValue = [0, 1]
        let bench = try scene.bench(bodies: .onChange(response: quick))

        scene.items.wrappedValue = [0, 1, 2]
        bench.frames(1)
        XCTAssertEqual(bench.shown[2], 200, accuracy: 0.001, "where it goes")
        XCTAssertLessThan(bench.placements[2].opacity, 0.2, "little of it yet")
        XCTAssertEqual(bench.placements[0].opacity, 1, "the others as they were")

        bench.frames(5)
        XCTAssertGreaterThan(bench.placements[2].opacity, 0.2, "fading in")
        bench.frames(60)
        XCTAssertEqual(bench.placements[2].opacity, 1, accuracy: 0.001)
    }

    /// A NEW ORDER SLIDES: each view from where it stood to its new place.
    func testANewOrderSlides() throws {
        let scene = Scene()
        let bench = try scene.bench(bodies: .onChange(response: quick))

        scene.items.wrappedValue = [2, 1, 0]
        bench.frames(1)
        XCTAssertEqual(bench.shown[0], 200, accuracy: 20, "each a frame of its spring from where it stood")
        XCTAssertEqual(bench.shown[2], 0, accuracy: 20)

        bench.frames(60)
        XCTAssertEqual(bench.shown.map { ($0 * 1_000).rounded() / 1_000 }, [0, 100, 200])
    }

    /// A VALUE READ IN THE BODY IS A CHANGE OF THE DESCRIPTION, and the new places are traveled to.
    func testAValueReadInTheBodyTravels() throws {
        let scene = Scene()
        let bench = try scene.bench(bodies: .onChange(response: quick))

        scene.gap.wrappedValue = 50
        bench.frames(1)
        XCTAssertEqual(bench.shown[2], 200, accuracy: 12, "a frame of its spring from where it stood")
        XCTAssertGreaterThan(bench.shown[2], 150)
        bench.frames(60)
        XCTAssertEqual(bench.shown[2], 100, accuracy: 0.001)
    }

    /// A CHANGE WHILE THE PARAMETERS MOVE LEAVES THE PARAMETERS THEIR OWN MOVE: the change is measured where the
    /// last frame stood, so each frame shows the parameters where they are, the change on its way.
    func testAChangeLeavesTheParametersTheirMove() throws {
        let scene = Scene()
        let bench = try scene.bench(bodies: .onChange(response: quick))
        scene.phase.wrappedValue = 0.5
        bench.frames(2)
        XCTAssertEqual(bench.shown[2], 150, accuracy: 0.001, "(2 - 0.5) × 100")

        scene.gap.wrappedValue = 50
        bench.frames(1)
        XCTAssertEqual(bench.shown[2], 150, accuracy: 10, "a frame of its spring from where it stood")

        scene.phase.wrappedValue = 1
        bench.frames(60)
        XCTAssertEqual(bench.shown[2], 50, accuracy: 0.001, "(2 - 1) × 50: the parameters', the change's")
    }

    /// A CHANGE ON ITS WAY, CHANGED AGAIN, sets out from where each view is shown: no jump.
    func testAChangeChangedAgainSetsOutFromWhereItIsShown() throws {
        let scene = Scene()
        let bench = try scene.bench(bodies: .onChange(response: quick))
        scene.gap.wrappedValue = 50
        bench.frames(6)
        let halfway = bench.shown[2]
        XCTAssertGreaterThan(halfway, 100)
        XCTAssertLessThan(halfway, 200)

        scene.gap.wrappedValue = 100
        bench.frames(1)
        XCTAssertEqual(bench.shown[2], halfway, accuracy: 20, "a frame of its spring on from there")
        bench.frames(60)
        XCTAssertEqual(bench.shown[2], 200, accuracy: 0.001)
    }

    /// LESS MOTION SHOWS A CHANGE AT ONCE, and so does a layout whose views have no body.
    func testLessMotionAndNoBodyShowAChangeAtOnce() throws {
        let reduced = Scene()
        let slow = try reduced.bench(bodies: .onChange(response: quick), reducesMotion: true)
        reduced.items.wrappedValue = [1, 2]
        slow.frames(1)
        XCTAssertEqual(slow.shown[0], 0, accuracy: 0.001)

        let bare = Scene()
        let plain = try bare.bench(bodies: .none)
        bare.items.wrappedValue = [1, 2]
        plain.frames(1)
        XCTAssertEqual(plain.shown[0], 0, accuracy: 0.001)
    }

    /// A VIEW'S OWN BODY WINS OVER ITS LAYOUT'S, either way: one saying none lands while the others travel, and one
    /// saying a body travels in a layout whose views have none.
    func testAViewsOwnBodyWinsOverItsLayouts() throws {
        let landing = Scene()
        let bodies = try landing.bench(bodies: .onChange(response: quick), own: LayoutBody.none)
        landing.items.wrappedValue = [1, 2]
        bodies.frames(1)
        XCTAssertEqual(bodies.shown[0], 0, accuracy: 0.001, "no body: at its place at once")
        XCTAssertEqual(bodies.shown[1], 200, accuracy: 12, "a body: from where it stood")

        let traveling = Scene()
        let none = try traveling.bench(bodies: .none, own: .onChange(response: quick))
        traveling.items.wrappedValue = [1, 2]
        none.frames(1)
        XCTAssertEqual(none.shown[0], 100, accuracy: 12, "its own body: from where it stood")
        XCTAssertEqual(none.shown[1], 100, accuracy: 0.001, "the layout's none: at its place at once")
    }

    /// A CHANGE TELLS THE REST ONCE ITS VIEWS STAND AT THEIR PLACES: not while the host still brings them there.
    func testAChangeTellsTheRestOnceItsViewsStand() async throws {
        let scene = Scene()
        let settled = Settles()
        let bench = try scene.bench(bodies: .onChange(response: quick), settled: settled)
        for _ in 0..<50 { await Task.yield() }
        let before = settled.count

        scene.items.wrappedValue = [1, 2]
        bench.frames(4)
        for _ in 0..<50 { await Task.yield() }
        XCTAssertTrue(bench.runtime.tree.layoutBodiesMove)
        XCTAssertEqual(settled.count, before, "on their way: no rest yet")

        bench.frames(80)
        XCTAssertFalse(bench.runtime.tree.layoutBodiesMove)
        // The rest is told through the handler's own run.
        for _ in 0..<200 {
            guard settled.count == before else { break }
            await Task.yield()
            bench.frames(1)
        }
        XCTAssertEqual(settled.count, before + 1, "told once they stand")
    }
}
