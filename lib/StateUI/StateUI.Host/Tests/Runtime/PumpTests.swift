// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// One turn of a runtime, and the order the application's handlers run in, over a real application.
@MainActor
final class PumpTests: XCTestCase {
    override func setUp() async throws {
        _ = HostBoundary.takeActCalls()
        Renderer.shared.clearStates()
    }

    /// The first turn renders the application whole and shows its windows.
    @MainActor
    func testTheFirstTurnRendersTheApplication() {
        let runtime = TurnRuntime()

        runtime.pump.turn()

        XCTAssertEqual(runtime.words, "count 0")
        XCTAssertEqual(runtime.shown, ["count 0"])
    }

    /// A native event raises its handler, and the turn after it renders what the handler changed.
    @MainActor
    func testAnEventRendersWhatItsHandlerChanged() {
        let runtime = TurnRuntime()
        runtime.pump.turn()

        runtime.pump.dispatch(runtime.add)
        runtime.pump.dispatch(runtime.add)

        XCTAssertEqual(runtime.shown, ["count 0", "count 1", "count 2"])
    }

    /// A turn after a pass of the platform's loop is taken only where there is work: with none, nothing renders;
    /// with a handler's write waiting, it renders.
    @MainActor
    func testATurnIsTakenOnlyWhereThereIsWork() {
        let runtime = TurnRuntime()
        runtime.pump.turn()

        runtime.pump.turnIfWanted()
        XCTAssertEqual(runtime.shown, ["count 0"], "nothing waited, nothing rendered")

        _ = runtime.core.dispatch(runtime.add)
        runtime.pump.turnIfWanted()
        XCTAssertEqual(runtime.shown, ["count 0", "count 1"], "the write waiting rendered")
    }

    /// The handlers raised inside the user's transaction wait for it, run in their order, and one render shows
    /// what they changed.
    @MainActor
    func testTheUsersTransactionRaisesItsHandlersOnceItIsOver() {
        let runtime = TurnRuntime()
        runtime.pump.turn()

        runtime.pump.performUserTransaction {
            runtime.pump.dispatch(runtime.add)
            runtime.pump.dispatch(runtime.add)
            XCTAssertEqual(runtime.core.needsRender, false, "a handler ran inside the transaction")
        }

        XCTAssertEqual(runtime.shown, ["count 0", "count 2"])
    }

    /// A turn asked for inside the user's transaction - a report that wrote a state - waits for it to be over,
    /// so the two halves of one gesture never render apart.
    @MainActor
    func testATurnAskedInsideTheUsersTransactionWaitsForItsEnd() {
        let runtime = TurnRuntime()
        runtime.pump.turn()

        runtime.pump.performUserTransaction {
            _ = runtime.core.dispatch(runtime.add)
            runtime.pump.turn()
            _ = runtime.core.dispatch(runtime.add)
            runtime.pump.turn()
        }

        XCTAssertEqual(runtime.shown, ["count 0", "count 2"])
    }

    /// A handler raised while a patch applies waits for the patch, and runs once it is in.
    @MainActor
    func testAHandlerRaisedWhileAPatchAppliesRunsOnceItIsIn() {
        let runtime = TurnRuntime()
        runtime.pump.turn()
        runtime.onApply = {
            runtime.onApply = nil
            XCTAssertTrue(runtime.pump.handlers.isHeld)
            runtime.pump.dispatch(runtime.add)
        }

        runtime.pump.dispatch(runtime.add)

        XCTAssertEqual(runtime.shown, ["count 0", "count 1", "count 2"])
    }

    /// A page's phase is rendered before the handler queued after it runs.
    @MainActor
    func testAPhaseIsRenderedBeforeWhatComesAfterIt() {
        let runtime = TurnRuntime()
        runtime.pump.turn()

        runtime.pump.handlers.enqueuePhase(runtime.add)
        runtime.pump.handlers.enqueuePhase(runtime.add)
        runtime.pump.turn()

        XCTAssertEqual(runtime.shown, ["count 0", "count 1", "count 2"])
    }

    /// An act lands on the interface its handler changed: the turn renders first, then performs it.
    @MainActor
    func testAnActLandsOnTheInterfaceItsHandlerChanged() {
        let runtime = TurnRuntime()
        runtime.pump.turn()

        runtime.pump.dispatch(runtime.addAndAct)

        XCTAssertEqual(runtime.performed, ["Application.hideOnScreenKeyboard on count 1"])
    }

    /// A render about a tree the runtime no longer holds is refused and asked for whole once: the log hears why,
    /// one render brings the lost element back as the core describes it, and the complete render is claimed.
    @MainActor
    func testADriftedRenderIsAskedForWholeOnce() throws {
        let runtime = TurnRuntime()
        runtime.pump.turn()
        runtime.expectsDrift = true
        runtime.tree.root?.forgetForTesting { $0.type == .text }

        runtime.pump.dispatch(runtime.add)

        let drift = try XCTUnwrap(runtime.intake.lastDrift)
        XCTAssertEqual(runtime.drifts.count, 1)
        XCTAssertTrue(runtime.drifts.first?.hasSuffix(drift) ?? false, runtime.drifts.joined())
        XCTAssertEqual(runtime.shown, ["count 0", "count 1"], "one render shows the label back")
        XCTAssertGreaterThan(runtime.intake.baseline, 0, "the complete render is claimed")

        runtime.pump.dispatch(runtime.add)
        XCTAssertEqual(runtime.drifts.count, 1, "the next render applies as it is")
        XCTAssertEqual(runtime.shown.last, "count 2")
    }

    /// A view dealt to a layout stands where its run puts it in the turn that renders it: the cycle the render asks
    /// for runs before the turn ends, so no frame draws the new views by a run worked out for the old - the last of
    /// them in no place at all. After a silence too, when that cycle is the one that starts the clock again.
    @MainActor
    func testARunStandsWithTheViewsTheRenderDealt() throws {
        let runtime = TurnRuntime(DealingApplication())
        runtime.pump.turn()
        let layout = try XCTUnwrap(runtime.tree.root?.first(type: .motionLayout))
        // The room as a host's frame report says it: kept by the element, and told the program.
        layout.laidOutRoom = (300, 200)
        try XCTUnwrap(layout.layoutProgram).layOut(300, 200)
        runtime.frame()
        XCTAssertEqual(layout.placement?.placements.count, 2)

        runtime.time += 16
        runtime.pump.dispatch(runtime.add)

        XCTAssertEqual(layout.children.count, 3)
        XCTAssertEqual(layout.placement?.placements.count, 3, "a run of the views it places")

        // The layout comes to rest and the clock lets go, then a silence.
        for _ in 0..<100 {
            guard runtime.held else { break }
            runtime.time += 16
            runtime.frame()
        }
        XCTAssertFalse(runtime.held, "at rest")
        runtime.time += 500
        runtime.pump.dispatch(runtime.add)

        XCTAssertEqual(layout.children.count, 4)
        XCTAssertEqual(layout.placement?.placements.count, 4, "after a silence")
    }

    /// A TURN LEAVES AN ENGINE GOING ON TO THE DISPLAY'S FRAME: while an engine asks for its next frame, a turn
    /// taken for a call that wrote nothing - a hand's move gathered for the next frame - runs no cycle; the frame
    /// does.
    @MainActor
    func testATurnLeavesAnEngineGoingOnToTheFrame() throws {
        goingRuns = 0
        let runtime = TurnRuntime(GoingApplication())
        runtime.pump.turn()
        runtime.frame()
        XCTAssertTrue(runtime.core.cyclesPending, "the engine goes on")

        let before = goingRuns
        for _ in 0..<5 { runtime.pump.turnIfWanted() }
        XCTAssertEqual(goingRuns, before, "the turns left it to the frame")

        runtime.time += 16
        runtime.frame()
        XCTAssertGreaterThan(goingRuns, before, "and the frame ran it")
    }

    /// A VIEW DEALT TO A LAYOUT TRAVELS IN ON THE DISPLAY'S FRAMES, the layout's arithmetic run no more for it: the
    /// host moves the view onto its place, holds the clock while it does, and lets it go once the view stands.
    @MainActor
    func testADealtViewTravelsInOnTheFramesAlone() throws {
        let runtime = TurnRuntime(DealingApplication())
        runtime.pump.turn()
        let layout = try XCTUnwrap(runtime.tree.root?.first(type: .motionLayout))
        // The room as a host's frame report says it: kept by the element, and told the program.
        layout.laidOutRoom = (300, 200)
        try XCTUnwrap(layout.layoutProgram).layOut(300, 200)
        runtime.frame()
        runtime.time += 16
        runtime.pump.dispatch(runtime.add)
        runtime.frame()

        XCTAssertTrue(runtime.tree.layoutBodiesMove, "the dealt view is on its way in")
        XCTAssertEqual(try XCTUnwrap(layout.placement?.placements.last).opacity, 0, accuracy: 0.2, "from nothing")
        XCTAssertTrue(runtime.held, "and the clock is held for it")

        let ran = dealtRuns
        for _ in 0..<200 {
            guard runtime.tree.layoutBodiesMove else { break }
            runtime.time += 16
            runtime.frame()
        }
        XCTAssertFalse(runtime.tree.layoutBodiesMove, "at its place")
        XCTAssertEqual(try XCTUnwrap(layout.placement?.placements.last).opacity, 1, accuracy: 0.001)
        XCTAssertLessThanOrEqual(dealtRuns - ran, 1, "the arithmetic ran for the rest it came to, not for its frames")
    }
}

/// How many times the going page's engine ran.
@MainActor private var goingRuns = 0

/// A page whose engine asks for every next frame.
private struct GoingPage: View {
    @State private var turned = 0.0

    var body: some View {
        Text("going")
            .engine(tracking: $turned) { _ in
                goingRuns += 1
                return .again
            }
    }
}

private struct GoingApplication: Application {
    var body: some Scene { WindowGroup { GoingPage() } }
}

/// A page whose handlers add one, the second also calling an act.
private struct CountingPage: View {
    @Environment(\.window) private var window
    @State private var count = 0

    var body: some View {
        VStack {
            Text("count \(count)")
            Button("Add")
                .onClicked { count += 1 }
            Button("Add and hide")
                .onClicked(policy: .runConcurrently) {
                    count += 1
                    _ = try? await window.hideOnScreenKeyboard()
                }
        }
    }
}

private struct CountingApplication: Application {
    var body: some Scene { WindowGroup { CountingPage() } }
}

/// How many times the dealing page's arithmetic ran.
@MainActor private var dealtRuns = 0

/// A page whose handler deals a layout one more view.
private struct DealingPage: View {
    @State private var cards = [0, 1]

    var body: some View {
        let count = cards.count

        return VStack {
            Button("Deal")
                .onClicked { cards.append(cards.count) }
            MotionLayout(cards, parameters: State(wrappedValue: 0.0).projectedValue) { Text("\($0)") } placements: { _, _ in
                dealtRuns += 1
                return (0..<count).map { Placement(Rect(x: Double($0) * 20, y: 0, width: 10, height: 10)) }
            }
        }
    }
}

private struct DealingApplication: Application {
    var body: some Scene { WindowGroup { DealingPage() } }
}

/// A runtime over the real core with no toolkit: the mounted tree, the display cycle and the pump, recording what
/// each render showed and each act found.
@MainActor
private final class TurnRuntime: TurnPresenter, FramePresenter, FrameClock {
    let core = CoreLink()
    let intake = PatchIntake()
    /// The runtime's time, in milliseconds, as a test moves it.
    var time = 0.0
    var now: () -> Double { { [unowned self] in self.time } }
    var held = false
    var onFrame: ((Double) -> Void)?
    private(set) var tree: MountedTree!
    private(set) var pump: Pump!
    private var displayCycle: DisplayCycle!

    /// The label's words at each render.
    private(set) var shown: [String] = []

    /// Each act performed, and the label's words when it was.
    private(set) var performed: [String] = []

    /// What an element's native half does as a patch reaches it.
    var onApply: (() -> Void)?

    /// Whether a drift is what the test is after; any other test fails on one.
    var expectsDrift = false

    /// What the pump logged of each drift.
    private(set) var drifts: [String] = []

    convenience init() {
        self.init(CountingApplication())
    }

    init(_ application: some Application) {
        Renderer.shared.setApplication(application)
        let animator = Animator()
        let stateChannels = StateChannels(animator: animator)
        let describedMotion = DescribedMotion(animator: animator)
        let layoutMotion = LayoutMotion(animator: animator, now: now, reducesMotion: { false })
        displayCycle = DisplayCycle(
            core: core, clock: self, animator: animator, stateChannels: stateChannels,
            describedMotion: describedMotion, layoutMotion: layoutMotion,
            sidebarSlide: SidebarSlide(animator: animator, now: now, reducesMotion: { false }), reducesMotion: { false })
        tree = MountedTree(
            core: core, intake: intake, stateChannels: stateChannels, describedMotion: describedMotion,
            layoutMotion: layoutMotion, now: now, reducesMotion: { false },
            diagnostics: DiagnosticText(tallies: false, inspects: false) { _ in },
            makeNative: { [unowned self] in HeldNative($0, runtime: self) })
        pump = Pump(
            core: core, intake: intake, tree: tree, displayCycle: displayCycle, now: now,
            log: { [unowned self] line in
                if !self.expectsDrift { XCTFail("a drift: \(line)") }
                self.drifts.append(line)
            })
        pump.presenter = self
        displayCycle.presenter = self
        core.connectWindow()
    }

    var words: String {
        tree.root?.first(type: .text)?.value(.text)?.string ?? ""
    }

    /// One frame of the display.
    func frame() {
        displayCycle.frame(now: now())
    }

    var add: Int32 { buttons[0] }
    var addAndAct: Int32 { buttons[1] }

    private var buttons: [Int32] {
        tree.root?.first(type: .vStack)?.children.filter { $0.type == .button }.compactMap { $0.handler(.clicked) } ?? []
    }

    func presentRendered(touchedChrome: Bool) {
        shown.append(words)
    }

    var wantsFrames: Bool { false }

    func commitUserReports(now: Double) {}

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        _ = tree.present(states: states, properties: properties)
    }

    func renderIfNeeded() {
        if core.needsRender { pump.turn() }
    }

    func mount(ofLayout slot: UInt64) -> UInt64? { tree.mount(ofLayout: slot) }

    func stepLayoutBodies() -> [UInt64] { tree.stepLayoutBodies() }

    var layoutBodiesMove: Bool { tree.layoutBodiesMove }

    func perform(_ call: HostActCall) {
        performed.append("\(call.act.name) on \(words)")
        if let completion = call.completion { _ = core.fail(completion, reason: "no toolkit") }
    }

    func applied() {
        onApply?()
    }
}

/// A native half with no view, telling its runtime when a patch reaches it.
@MainActor
private final class HeldNative: NativeElement {
    func measured(width: Double?, height: Double?) -> HostChildMeasured {
        HostChildMeasured(size: .zero, firstBaseline: nil)
    }
    unowned let element: MountedElement
    unowned let runtime: TurnRuntime

    init(_ element: MountedElement, runtime: TurnRuntime) {
        self.element = element
        self.runtime = runtime
    }

    var presentsView: Bool { true }
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        if element.type == .text { runtime.applied() }
    }
    func presentFrame(_ changed: Set<Prop>) {}
    func arrangeChildren() {}
    func orderChildren() {}
    func invalidateMeasurements() {}
    func configureLayoutMotion() {}
    func deactivate() {}
}
