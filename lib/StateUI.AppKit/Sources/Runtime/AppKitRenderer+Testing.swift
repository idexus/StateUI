// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the host suite reads and drives.
extension AppKitRenderer {
    func startForTesting() { startRuntime() }

    var sceneCountForTesting: Int { scenes.count }

    var windowsForTesting: [AppKitWindowController] { orderedWindowControllers }

    var frameClockWindowForTesting: NSWindow? { frameClock.window }

    var describedMotionActiveForTesting: Bool { describedMotion.isActive }

    /// The AppKit half of the mounted root.
    var rootElementForTesting: AppKitElement? { tree.root?.appKit }

    func viewForTesting(id: ElementId) -> NSView? {
        tree.root?.first(id: id)?.appKit.view
    }

    func viewsForTesting(id: ElementId) -> [NSView] {
        tree.root?.all(id: id).compactMap(\.appKit.view) ?? []
    }

    func applyForTesting(_ patch: HostPatch) {
        intake.take(patch, generation: intake.baseline &+ 1) { tree.apply($0, complete: true) }

        synchronizeWindows()
        flushQueuedEvents()
    }

    /// What made the last refused message drift.
    var driftForTesting: String? { intake.lastDrift }

    /// The generation the host quotes on its next render.
    var baselineForTesting: Int32 { intake.baseline }

    /// Loses the element that presents `view`, as a host that dropped part of
    /// its tree would.
    func forgetForTesting(_ view: NSView) {
        tree.root?.forgetForTesting { $0.appKit.view === view }
        view.removeFromSuperview()
    }

    func advanceAnimationsForTesting() {
        displayCycle.advanceAnimations(now: frameClock.now(), reducesMotion: reducesMotion())
        displayCycle.hold()
    }

    func displayFrameForTesting() {
        displayCycle.frame(now: frameClock.now())
    }

    var frameClockRunningForTesting: Bool { frameClock.isRunning }

    var animatingForTesting: Bool { animator.isMoving }

    var channelCountForTesting: Int { stateChannels.count }

    func applyStateForTesting(_ state: Int32, value: HostStateValue) {
        let impact = tree.present(states: [state: value], properties: [:])
        if impact.windowChrome { synchronizeWindows() }
    }

    func applyStatesForTesting(_ valuesByState: [Int32: HostStateValue]) {
        let impact = valuesByState.isEmpty
            ? FrameImpact.none
            : tree.present(states: valuesByState, properties: [:])
        if impact.windowChrome { synchronizeWindows() }
    }

    func closeForTesting() {
        for scene in orderedScenes.reversed() { scene.closeFromTree() }
        scenes.removeAll()
        sceneOrder.removeAll()
        for window in restoredWindows.values { window.close() }
        restoredWindows.removeAll()
        tree.root?.leave()
        frameClock.stop()
    }
}
#endif
