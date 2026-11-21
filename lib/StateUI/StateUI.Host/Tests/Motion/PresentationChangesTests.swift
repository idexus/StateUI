// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Whether the application below shows its panel whole, and the aim on that panel.
@MainActor private let panelShown = State(wrappedValue: true)
@MainActor private let aimedPanel = Aim(VStack.self)

/// A panel that fades by its own motion, beside a line that stands.
private struct Fading: View {
    var body: some View {
        VStack {
            VStack { Text("panel") }
                .opacity(panelShown.wrappedValue ? 1 : 0)
                .motion(.eased(.milliseconds(200), curve: .linear))
                .aim(aimedPanel)
            Text("beside")
        }
    }
}

private struct FadingApplication: Application {
    var body: some Scene { WindowGroup { Fading() } }
}

/// Two states a host carries - one moving a line in the panel, one a line beside it - and the aim on the panel.
@MainActor private let panelShift = State(wrappedValue: 0.0, motion: .eased(.milliseconds(200), curve: .linear))
@MainActor private let besideShift = State(wrappedValue: 0.0, motion: .eased(.milliseconds(600), curve: .linear))
@MainActor private let slidingPanel = Aim(VStack.self)

/// A panel whose line a state moves, beside a line another state moves.
private struct Sliding: View {
    var body: some View {
        VStack {
            VStack { Text("panel").translationX(panelShift.projectedValue) }
                .aim(slidingPanel)
            Text("beside").translationX(besideShift.projectedValue)
        }
    }
}

private struct SlidingApplication: Application {
    var body: some Scene { WindowGroup { Sliding() } }
}

/// A presentation change on the host's side: what its render starts under the view it aims at is what it waits
/// for, and each of its two answers is said once.
@MainActor
final class PresentationChangesTests: XCTestCase {
    /// A tree of a root stack holding a panel and a line beside it, on a clock a test winds.
    @MainActor
    private final class Bench {
        let clock = WoundClock()
        let runtime: HostRuntime

        /// A bench whose views keep a child that left where `keeps`, the application moving in `milliseconds`.
        init(keeps: Bool = true, motion milliseconds: Int = 200) {
            runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in
                let view = NoView()
                view.animatesProperties = true
                view.keepsExits = keeps
                return view
            }, log: { _ in })
            runtime.layoutMotion.applicationMotion = .eased(.milliseconds(milliseconds), curve: .linear)
            show(panel: 1, beside: 1, lines: ["line"], complete: true)
            place("line", at: 0)
        }

        var tree: MountedTree { runtime.tree }

        /// A text of `id` at `opacity`, moving there in `milliseconds` where given.
        private static func text(_ id: String, _ opacity: Double?, in milliseconds: Int?) -> HostPatch {
            var patch = HostPatch(id: .manual(id), type: .text)
            if let opacity { patch.properties = [.opacity: .number(opacity)] }
            if let milliseconds {
                patch.transitions = [.opacity: HostTransition(motion: .eased(.milliseconds(milliseconds), curve: .linear))]
            }
            return patch
        }

        /// Says the panel's opacity and the line's beside it, each moving there in so many milliseconds; nil says
        /// nothing of one, which stands as it is. `lines` are the texts the panel holds, where they change.
        func show(
            panel: Double?, over panelTime: Int? = nil, beside: Double?, besideOver besideTime: Int? = nil,
            lines: [String]? = nil, complete: Bool = false
        ) {
            var root = HostPatch(id: .manual("root"), type: .vStack)
            var panelPatch = HostPatch(id: .manual("panel"), type: .vStack)
            if let panel { panelPatch.properties = [.opacity: .number(panel)] }
            if let panelTime {
                panelPatch.transitions = [.opacity: HostTransition(motion: .eased(.milliseconds(panelTime), curve: .linear))]
            }
            if let lines {
                panelPatch.children = .arranged(lines.map { name in
                    var line = HostPatch(id: .manual(name), type: .text)
                    // A line named "going" leaves by fading.
                    if name == "going" { line.properties = [.transition: Self.fades.propValue] }
                    return line
                })
            }
            root.children = .arranged([panelPatch, Self.text("beside", beside, in: besideTime)])
            tree.apply(root, complete: complete)
        }

        static let fades = Transition(enter: .identity, exit: .opacity)

        var panel: MountedElement { tree.root!.children[0] }

        /// The views places are given to, by the line's name.
        private var views: [String: Placed] = [:]

        /// The panel's layout pass: stands its line `name` at `y`, as an arrangement placing what a patch said.
        func place(_ name: String, at y: Double, entering: Bool = false) {
            guard let line = panel.children.first(where: { $0.id == .manual(name) }) else { return }

            let view = views[name, default: Placed()]
            views[name] = view
            let law = Motion.eased(.milliseconds(200), curve: .linear)
            runtime.layoutMotion.place(
                view, mount: line.mount, at: Rect(x: 0, y: y, width: 100, height: 20), stated: [], words: .none,
                natural: { LayoutSize(width: 100, height: 20) },
                enter: entering ? { entry in line.enter(Shown(), as: entry) } : nil,
                in: Arrangement(law: law, lanes: .all, joins: true), room: nil)
        }

        /// A change aimed at the panel - or at a view that stands nowhere - whose render `apply` applies.
        func change(aimedAt name: String = "panel", applying apply: () -> Void) -> PresentationChange {
            let change = Renderer.shared.change(aimedAt: [.manual("root"), .manual(name)])
            tree.changes.begin(Renderer.shared.takeChanges(), in: tree)
            apply()
            tree.changes.close()
            return change
        }

        func frame(at time: Double) {
            clock.time = time
            runtime.displayCycle.frame(now: time)
        }
    }

    /// A view a place is given to.
    private final class Placed: PlacedView {
        var placedFrame = Rect(x: 0, y: 0, width: 0, height: 0)
        var heldWords: LayoutSize?
    }

    /// A view an entry fades.
    private final class Shown: FadingView {
        var isShown = true
        var opacity = 1.0
        func setShown(_ shown: Bool) {}
        func setOpacity(_ opacity: Double) { self.opacity = opacity }
        func setIgnoresInput(_ ignores: Bool) {}
    }

    override func setUp() async throws {
        _ = Renderer.shared.takeChanges()
    }

    /// A CHANGE WAITS FOR THE PLACES ITS PATCH MOVED, though they set out in the layout pass after it: the panel's
    /// line travels to where the next arrangement stands it, and the change is settled as it lands.
    func testAChangeWaitsForThePlacesItsPatchMoved() {
        let bench = Bench()

        let change = bench.change { bench.show(panel: 0.9, beside: nil) }
        XCTAssertNil(change.answered.settled, "its layout has not placed anything yet")
        bench.place("line", at: 40)
        bench.frame(at: 50)
        bench.frame(at: 100)
        XCTAssertNil(change.answered.settled, "the line is on its way")

        bench.frame(at: 250)
        XCTAssertEqual(change.answered.settled, .settled)
    }

    /// A CHANGE WAITS FOR THE ENTRY OF A VIEW ITS PATCH BROUGHT: the entry is told in the layout pass, as the view is
    /// given its first place.
    func testAChangeWaitsForTheEntryOfAViewItBrought() {
        let bench = Bench()
        let comes = Transition(enter: .opacity, exit: .identity)

        let change = bench.change {
            var root = HostPatch(id: .manual("root"), type: .vStack)
            var panel = HostPatch(id: .manual("panel"), type: .vStack)
            var coming = HostPatch(id: .manual("coming"), type: .text)
            coming.properties = [.transition: comes.propValue]
            panel.children = .arranged([HostPatch(id: .manual("line"), type: .text), coming])
            root.children = .arranged([panel, HostPatch(id: .manual("beside"), type: .text)])
            bench.tree.apply(root, complete: false)
        }
        bench.place("coming", at: 20, entering: true)
        XCTAssertTrue(bench.tree.describedMotion.isActive, "the entry is under way")
        bench.frame(at: 50)
        bench.frame(at: 100)
        XCTAssertNil(change.answered.settled, "the view is fading in")

        bench.frame(at: 400)
        XCTAssertEqual(change.answered.settled, .settled)
    }

    /// A CHANGE WAITS FOR THE EXIT OF A VIEW ITS PATCH DROPPED: the view is the application's no more at once, and
    /// the change is settled as its exit lands.
    func testAChangeWaitsForTheExitOfAViewItDropped() {
        let bench = Bench()
        bench.show(panel: nil, beside: nil, lines: ["line", "going"])

        let change = bench.change { bench.show(panel: nil, beside: nil, lines: ["line"]) }
        bench.frame(at: 50)
        bench.frame(at: 100)
        XCTAssertNil(change.answered.settled, "the view is fading out")

        bench.frame(at: 250)
        XCTAssertEqual(change.answered.settled, .settled)
    }

    /// AN EXIT NOTHING DRAWS IS SAID: where the view holding it keeps no child that left, the change ends
    /// `.unsupported`; cut short by the budget of kept views, `.limited`; and the same view coming back as it
    /// leaves supersedes it.
    func testAnExitNotDrawnToItsEndIsSaidWhy() {
        let unkept = Bench(keeps: false)
        unkept.show(panel: nil, beside: nil, lines: ["line", "going"])
        let refused = unkept.change { unkept.show(panel: nil, beside: nil, lines: ["line"]) }
        unkept.frame(at: 16)
        unkept.frame(at: 32)
        XCTAssertEqual(refused.answered.settled, .interrupted([.unsupported]))

        let slow = Bench(motion: 3_000)
        slow.show(panel: nil, beside: nil, lines: ["line", "going"])
        let limited = slow.change { slow.show(panel: nil, beside: nil, lines: ["line"]) }
        slow.frame(at: 1_000)
        XCTAssertNil(limited.answered.settled, "kept, and fading")
        slow.frame(at: KeptExits.timeLimit + 100)
        XCTAssertEqual(limited.answered.settled, .interrupted([.limited]))

        let returning = Bench()
        returning.show(panel: nil, beside: nil, lines: ["line", "going"])
        let left = returning.change { returning.show(panel: nil, beside: nil, lines: ["line"]) }
        returning.frame(at: 50)
        returning.show(panel: nil, beside: nil, lines: ["line", "going"])
        returning.frame(at: 66)
        XCTAssertEqual(left.answered.settled, .interrupted([.superseded]), "the view came back before it had gone")
    }

    /// A CHANGE'S LAYOUT WINDOW ENDS WITH THE SECOND FRAME AFTER IT: a patch that reached the view and moved nothing
    /// is settled then, and holds the frame clock until then - while a change whose patch reached nothing under
    /// its view is settled at once.
    func testAChangesLayoutWindowEndsWithTheSecondFrame() {
        let bench = Bench()

        let change = bench.change { bench.show(panel: 0.9, beside: nil) }
        XCTAssertNil(change.answered.settled)
        XCTAssertTrue(bench.tree.changes.wantsFrames, "the frames go on for it")
        bench.frame(at: 16)
        XCTAssertNil(change.answered.settled, "one frame: a toolkit may lay out after it")
        bench.frame(at: 32)
        XCTAssertEqual(change.answered.settled, .settled)
        XCTAssertFalse(bench.tree.changes.wantsFrames)

        let beside = bench.change { bench.show(panel: nil, beside: 0.5) }
        XCTAssertEqual(beside.answered.settled, .settled, "nothing under its view was reached")
    }

    /// AN ARRANGEMENT IS ITS PATCH'S: what a later patch's layout pass moves is no part of an earlier change, and
    /// two changes whose patches wait for one pass both have what it moves.
    func testAnArrangementBelongsToThePatchesThatWaitedForIt() {
        let bench = Bench()
        let first = bench.change { bench.show(panel: 0.9, beside: nil) }
        bench.place("line", at: 0)
        bench.frame(at: 16)
        let second = bench.change { bench.show(panel: 0.8, beside: nil) }
        bench.place("line", at: 40)
        bench.frame(at: 32)
        XCTAssertEqual(first.answered.settled, .settled, "its own pass moved nothing; the later one is not its own")
        XCTAssertNil(second.answered.settled)
        bench.frame(at: 300)
        XCTAssertEqual(second.answered.settled, .settled)

        let third = bench.change { bench.show(panel: 0.7, beside: nil) }
        let fourth = bench.change { bench.show(panel: 0.6, beside: nil) }
        bench.place("line", at: 80)
        bench.frame(at: 316)
        bench.frame(at: 332)
        XCTAssertNil(third.answered.settled, "one pass placed what both patches said")
        XCTAssertNil(fourth.answered.settled)
        bench.frame(at: 600)
        XCTAssertEqual(third.answered.settled, .settled)
        XCTAssertEqual(fourth.answered.settled, .settled)
    }

    /// A CHANGE WAITS FOR WHAT ITS RENDER STARTED UNDER ITS VIEW, AND FOR NOTHING ELSE: applied once the patch is,
    /// settled as the panel's own movement rests - while a movement beside the panel is still under way.
    func testAChangeWaitsForWhatItsRenderStartedUnderItsView() {
        let bench = Bench()

        let change = bench.change { bench.show(panel: 0, over: 200, beside: 0, besideOver: 600) }
        XCTAssertEqual(change.answered.applied, .applied)
        bench.frame(at: 100)
        XCTAssertEqual(bench.tree.changes.waitingCount, 1, "its movement is under way")

        bench.frame(at: 200)
        XCTAssertEqual(bench.tree.changes.waitingCount, 0)
        XCTAssertEqual(change.answered.settled, .settled)
        XCTAssertTrue(bench.tree.describedMotion.isActive, "the movement beside it goes on, and was never waited for")
    }

    /// THE CORE AND THE HOST LAYER TOGETHER: a change an application makes through its aim is carried by the next
    /// render, waits for the movement its write started, and is answered as that rests - and one that writes
    /// nothing still gets its turn, and is settled at once.
    func testAnApplicationsChangeIsAnsweredAsItsMovementRests() throws {
        panelShown.wrappedValue = true
        FadingApplication.register()
        let clock = WoundClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in
            let view = NoView()
            view.animatesProperties = true
            return view
        }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()

        let fading = try aimedPanel.presentationChange { panelShown.wrappedValue = false }
        runtime.pump.turn()
        XCTAssertEqual(fading.answered.applied, .applied)
        XCTAssertEqual(runtime.tree.changes.waitingCount, 1, "the fade is under way")

        for time in [125.0, 250] {
            clock.time = time
            runtime.displayCycle.frame(now: time)
        }
        XCTAssertEqual(fading.answered.settled, .settled)

        let idle = try aimedPanel.presentationChange {}
        runtime.pump.turn()
        XCTAssertEqual(idle.answered.settled, .settled, "a change that wrote nothing is carried all the same")
    }

    /// A runtime showing the sliding application, both its states at rest at nought, on a clock wound by hand.
    private func sliding() -> (runtime: HostRuntime, frame: (Double) -> Void) {
        panelShift.projectedValue.journey.snap(to: 0)
        besideShift.projectedValue.journey.snap(to: 0)
        SlidingApplication.register()
        let clock = WoundClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.connectWindow()
        runtime.pump.turn()
        return (runtime, { time in
            clock.time = time
            runtime.pump.turn()
            runtime.displayCycle.frame(now: time)
        })
    }

    /// A CHANGE WAITS FOR THE RUN OF A STATE ITS WRITES SENT, where that state is shown under its view - the run is
    /// born in the core's cycle, before the render that carries the change - and for no run of a state shown
    /// only beside it.
    func testAChangeWaitsForTheRunOfAStateItSent() throws {
        let (runtime, frame) = sliding()

        let change = try slidingPanel.presentationChange {
            panelShift.wrappedValue = 100
            besideShift.wrappedValue = 100
        }
        frame(0)
        XCTAssertEqual(change.answered.applied, .applied)
        frame(100)
        XCTAssertNil(change.answered.settled, "its state is on its way")

        frame(250)
        XCTAssertEqual(change.answered.settled, .settled)
        XCTAssertTrue(runtime.animator.isMoving, "the state beside the view travels on, and was never waited for")
    }

    /// A RUN STOPPED, OR SENT ELSEWHERE BY A LATER WRITE, ENDS THE CHANGE SAYING SO; and a write that sends a state
    /// where it stands starts nothing, and is settled once the change's window is over.
    func testARunStoppedOrSentElsewhereEndsTheChangeSayingSo() throws {
        let (_, frame) = sliding()

        let stopped = try slidingPanel.presentationChange { panelShift.wrappedValue = 100 }
        frame(0)
        frame(100)
        panelShift.projectedValue.journey.stop()
        frame(116)
        XCTAssertEqual(stopped.answered.settled, .interrupted([.stopped]))

        let superseded = try slidingPanel.presentationChange { panelShift.wrappedValue = 200 }
        frame(200)
        frame(216)
        panelShift.wrappedValue = 0
        frame(232)
        XCTAssertEqual(superseded.answered.settled, .interrupted([.superseded]))

        frame(600)
        let still = try slidingPanel.presentationChange { panelShift.wrappedValue = 0 }
        frame(616)
        frame(632)
        frame(648)
        XCTAssertEqual(still.answered.settled, .settled, "there already: nothing set out")
    }

    /// A CHANGE THAT STARTED NOTHING IS SETTLED AT ONCE, AND ONE AIMED AT NOTHING SHOWN IS NOT PRESENTED.
    func testAChangeThatStartedNothingIsSettledAtOnce() {
        let bench = Bench()

        let still = bench.change { bench.show(panel: nil, beside: 0, besideOver: 200) }
        XCTAssertEqual(still.answered.applied, .applied)
        XCTAssertEqual(still.answered.settled, .settled, "what moved was not under its view")

        let nowhere = bench.change(aimedAt: "absent") { bench.show(panel: 0, over: 200, beside: nil) }
        XCTAssertEqual(nowhere.answered.applied, .notPresented)
        XCTAssertEqual(nowhere.answered.settled, .notPresented)
    }

    /// A LATER WRITE THAT SENDS THE VIEW ELSEWHERE ENDS THE CHANGE AS SUPERSEDED, and the movement that write
    /// started is the later change's alone: it prolongs no wait of the first.
    func testALaterWriteSupersedesAndJoinsNothing() {
        let bench = Bench()
        let first = bench.change { bench.show(panel: 0, over: 200, beside: nil) }
        bench.frame(at: 100)

        let second = bench.change { bench.show(panel: 1, over: 200, beside: nil) }
        bench.frame(at: 116)
        XCTAssertEqual(first.answered.settled, .interrupted([.superseded]))
        XCTAssertEqual(bench.tree.changes.waitingCount, 1, "the later change waits for the movement it started")

        bench.frame(at: 300)
        XCTAssertEqual(second.answered.settled, .settled)
    }

    /// A VIEW THAT LEAVES WHILE ITS MOVEMENT IS UNDER WAY ENDS THE CHANGE AS DETACHED.
    func testAViewThatLeavesEndsTheChangeAsDetached() {
        let bench = Bench()
        let change = bench.change { bench.show(panel: 0, over: 200, beside: nil) }
        bench.frame(at: 100)

        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([HostPatch(id: .manual("beside"), type: .text)])
        bench.tree.apply(root, complete: false)
        bench.frame(at: 116)

        XCTAssertEqual(change.answered.settled, .interrupted([.detached]))
    }
}
