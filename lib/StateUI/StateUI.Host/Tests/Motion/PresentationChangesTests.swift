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

/// A presentation change on the host's side: what its render starts under the view it aims at is what it waits
/// for, and each of its two answers is said once.
@MainActor
final class PresentationChangesTests: XCTestCase {
    /// A tree of a root stack holding a panel and a line beside it, on a clock a test winds.
    @MainActor
    private final class Bench {
        let clock = WoundClock()
        let runtime: HostRuntime

        init() {
            runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in
                let view = NoView()
                view.animatesProperties = true
                return view
            }, log: { _ in })
            show(panel: 1, beside: 1, complete: true)
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

        /// Says the panel's opacity and the line's, each moving there in so many milliseconds; nil leaves one out.
        func show(
            panel: Double?, over panelTime: Int? = nil, beside: Double?, besideOver besideTime: Int? = nil,
            complete: Bool = false
        ) {
            var root = HostPatch(id: .manual("root"), type: .vStack)
            var children: [HostPatch] = []
            if let panel { children.append(Self.text("panel", panel, in: panelTime)) }
            children.append(Self.text("beside", beside, in: besideTime))
            root.children = .arranged(children)
            tree.apply(root, complete: complete)
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

    override func setUp() async throws {
        _ = Renderer.shared.takeChanges()
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

        clock.time = 250
        runtime.displayCycle.frame(now: 250)
        XCTAssertEqual(fading.answered.settled, .settled)

        let idle = try aimedPanel.presentationChange {}
        runtime.pump.turn()
        XCTAssertEqual(idle.answered.settled, .settled, "a change that wrote nothing is carried all the same")
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

        XCTAssertEqual(change.answered.settled, .interrupted([.detached]))
    }
}
