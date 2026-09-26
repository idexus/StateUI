// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// One turn of a runtime, and the order the application's handlers run in, over a real application.
final class PumpTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = HostBoundary.takeActCalls()
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

        XCTAssertEqual(runtime.performed, ["hideOnScreenKeyboard on count 1"])
    }
}

/// A page whose handlers add one, the second also calling an act.
private struct CountingPage: ContentView {
    @State private var count = 0

    var content: any View {
        VStack {
            Label("count \(count)")
            Button("Add")
                .onClicked { count += 1 }
            Button("Add and hide")
                .onClicked {
                    count += 1
                    _ = try? await OnScreenKeyboard.hide()
                }
        }
    }
}

private struct CountingApplication: Application {
    var scene: any Scene { CountingWindow() }
}

private struct CountingWindow: Window {
    var page: any Page { CountingPage() }
}

/// A runtime over the real core with no toolkit: the mounted tree, the display cycle and the pump, recording what
/// each render showed and each act found.
@MainActor
private final class TurnRuntime: TurnPresenter, FrameClock {
    let core = CoreLink()
    let intake = PatchIntake()
    let now: () -> Double = { 0 }
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

    init() {
        stateUIUseApp(CountingApplication())
        let animator = Animator()
        let stateChannels = StateChannels(animator: animator)
        let describedMotion = DescribedMotion(animator: animator)
        let layoutMotion = LayoutMotion(animator: animator, now: now, reducesMotion: { false })
        displayCycle = DisplayCycle(
            core: core, clock: self, animator: animator, stateChannels: stateChannels,
            describedMotion: describedMotion, layoutMotion: layoutMotion, reducesMotion: { false })
        tree = MountedTree(
            core: core, intake: intake, stateChannels: stateChannels, describedMotion: describedMotion,
            layoutMotion: layoutMotion, now: now, reducesMotion: { false },
            diagnostics: DiagnosticText(tallies: false, inspects: false) { _ in },
            makeNative: { [unowned self] in HeldNative($0, runtime: self) })
        pump = Pump(
            core: core, intake: intake, tree: tree, displayCycle: displayCycle, now: now,
            log: { XCTFail("a drift: \($0)") })
        pump.presenter = self
        core.connectScene()
    }

    var words: String {
        tree.root?.first(type: .label)?.value(.text)?.string ?? ""
    }

    var add: Int32 { buttons[0] }
    var addAndAct: Int32 { buttons[1] }

    private var buttons: [Int32] {
        tree.root?.first(type: .vStack)?.children.filter { $0.type == .button }.compactMap { $0.handler(.clicked) } ?? []
    }

    func presentRendered() {
        shown.append(words)
    }

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
    unowned let element: MountedElement
    unowned let runtime: TurnRuntime

    init(_ element: MountedElement, runtime: TurnRuntime) {
        self.element = element
        self.runtime = runtime
    }

    var presentsView: Bool { true }
    func willApply() {}
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        if element.type == .label { runtime.applied() }
    }
    func presentFrame(_ changed: Set<Prop>) -> FrameImpact { FrameImpact(content: true) }
    func arrangeChildren() {}
    func leave() {}
}
