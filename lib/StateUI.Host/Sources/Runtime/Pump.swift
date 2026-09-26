// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a turn shows and performs through: the toolkit's windows and its acts.
@_spi(Host) @MainActor public protocol TurnPresenter: AnyObject {
    /// Shows what a render changed around the mounted tree: the windows, their pages and their chrome.
    func presentRendered()

    /// Performs an act the application called, on the interface its handler changed.
    func perform(_ call: HostActCall)
}

/// One turn of a runtime, in the order every runtime keeps: the jobs a resumed handler left, a pending cycle, a
/// render when the core needs one, the handlers it raised, then the acts.
/// Design: docs/design/host/runtime.md#one-turn
@_spi(Host) @MainActor public final class Pump {
    /// What a turn shows and performs through.
    public weak var presenter: (any TurnPresenter)?

    /// The handlers a turn raises, in their order.
    public let handlers: HandlerDispatch

    private let core: CoreLink
    private let intake: PatchIntake
    private let tree: MountedTree
    private let displayCycle: DisplayCycle
    private let now: () -> Double
    private let log: (String) -> Void

    /// Whether a turn runs, and whether one was asked for while it ran.
    private var turning = false
    private var again = false

    /// Turns over `tree`, with `log` hearing a drift the intake refused.
    public init(
        core: CoreLink,
        intake: PatchIntake,
        tree: MountedTree,
        displayCycle: DisplayCycle,
        now: @escaping () -> Double,
        log: @escaping (String) -> Void
    ) {
        self.core = core
        self.intake = intake
        self.tree = tree
        self.displayCycle = displayCycle
        self.now = now
        self.log = log
        handlers = HandlerDispatch(core: core, intake: intake)
    }

    /// Runs a turn, and another while one asks for it. A turn asked for inside the user's transaction runs once
    /// the transaction is over.
    /// Design: docs/design/host/runtime.md#the-handlers-order
    public func turn() {
        guard !handlers.inTransaction else { return }
        guard !turning else {
            again = true
            return
        }

        turning = true
        repeat {
            again = false
            step()
        } while again
        turning = false
    }

    /// Raises a native event's handler, then a turn; one raised while a patch applies, or inside the user's
    /// transaction, waits for it.
    public func dispatch(_ handler: Int32, payload: [HostValue] = []) {
        if handlers.raise(handler, payload: payload) { turn() }
    }

    /// Runs `body` as the user's transaction: the handlers it raises run in order once it is over, and one turn
    /// then renders everything it changed.
    public func performUserTransaction(_ body: () -> Void) {
        guard handlers.transaction(body), !intake.isApplying else { return }

        turn()
    }

    private func step() {
        _ = core.runJobs()

        if tree.root != nil, core.cyclesPending {
            displayCycle.drain(now: now())
        }

        if tree.root == nil || core.needsRender {
            render()

            let created = tree.root?.takeCreatedHandlers() ?? []
            for handler in created {
                _ = core.dispatch(handler)
            }
            if !created.isEmpty {
                again = true
                return
            }
        }

        // The acts land on the interface their handler changed: a turn that raised handlers renders again first.
        if handlers.raiseQueued() {
            again = true
            return
        }

        for call in core.takeActCalls() {
            presenter?.perform(call)
        }
    }

    /// Applies the core's render; a drifted one is asked for whole, once.
    private func render() {
        let rendered = core.render(baseline: intake.baseline)

        if !intake.take(rendered.root, generation: rendered.generation, apply: {
            tree.apply($0, complete: rendered.complete)
        }) {
            log("the interface drifted and is asked for whole: \(intake.lastDrift ?? "")")
            let complete = core.render(baseline: 0)
            intake.take(complete.root, generation: complete.generation, apply: {
                tree.apply($0, complete: complete.complete)
            })
        }

        displayCycle.presentStateChannels()
        presenter?.presentRendered()
    }
}
