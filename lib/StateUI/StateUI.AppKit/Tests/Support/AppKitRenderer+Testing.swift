// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit

/// What the host suite reads and drives.
extension AppKitRenderer {
    /// Starts the runtime as a launch does, its theme reported and followed - the one fact of its machine a test
    /// host tells the core.
    func startForTesting() {
        environment.startTheme(reportingChanges: { [weak self] report in self?.runtime.environmentChanged(report) })
        startRuntime()
    }

    var sceneCountForTesting: Int { SceneValues.scenes(of: runtime.tree.root).count }

    var windowsForTesting: [AppKitWindowController] { windowControllers }

    var frameClockWindowForTesting: NSWindow? { frameClock.window }

    var describedMotionActiveForTesting: Bool { runtime.describedMotion.isActive }

    /// The AppKit half of the mounted root.
    var rootElementForTesting: AppKitElement? { (runtime.tree.root?.native as? AppKitElement) }

    func viewForTesting(id: ElementID) -> NSView? {
        (runtime.tree.root?.first(id: id)?.native as? AppKitElement)?.view
    }

    func viewsForTesting(id: ElementID) -> [NSView] {
        runtime.tree.root?.all(id: id).compactMap { ($0.native as? AppKitElement)?.view } ?? []
    }

    /// Applies `patch` as one whole message, as a render does, and shows what it changed - then raises what the
    /// handlers it named were told, in their turn. The core's own render is taken and set aside first, so no turn
    /// renders the core's tree over the test's.
    func applyForTesting(_ patch: HostPatch) {
        if runtime.intake.baseline == 0 { _ = runtime.core.render(baseline: 0) }
        runtime.intake.take(patch, generation: runtime.intake.baseline &+ 1) {
            runtime.tree.apply($0, complete: true)
        }
        presentRendered()
        runtime.pump.turn()
    }

    /// What made the last refused message drift.
    var driftForTesting: String? { runtime.intake.lastDrift }

    /// The generation the host quotes on its next render.
    var baselineForTesting: Int32 { runtime.intake.baseline }

    /// Loses the element that presents `view`, as a host that dropped part of
    /// its tree would.
    func forgetForTesting(_ view: NSView) {
        runtime.tree.root?.forgetForTesting { ($0.native as? AppKitElement)?.view === view }
        view.removeFromSuperview()
    }

    func advanceAnimationsForTesting() {
        runtime.displayCycle.advanceAnimations(now: frameClock.now(), reducesMotion: reducesMotion())
        runtime.displayCycle.hold()
    }

    func displayFrameForTesting() {
        runtime.displayCycle.frame(now: frameClock.now())
    }

    var frameClockRunningForTesting: Bool { frameClock.isRunning }

    var animatingForTesting: Bool { runtime.animator.isMoving }

    func applyStateForTesting(_ state: Int32, value: HostStateValue) {
        present(states: [state: value], properties: [:])
    }

    func applyStatesForTesting(_ valuesByState: [Int32: HostStateValue]) {
        guard !valuesByState.isEmpty else { return }
        present(states: valuesByState, properties: [:])
    }

    func closeForTesting() {
        roster.update(root: nil, make: { _ in fatalError("no window comes while closing") }, close: { $0.closeFromTree() })
        runtime.tree.root?.leave()
        frameClock.stop()
        turns?.stop()
        turns = nil
    }
}
#endif
