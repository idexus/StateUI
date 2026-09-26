// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// The WinUI runtime: the mounted tree over WinUI elements, the window around it, and the turn.
/// Design: docs/design/platforms/winui/runtime.md#the-winui-runtime
@MainActor
final class WinUIRenderer {
    /// The one runtime of the process, made when WinUI stands.
    static var shared: WinUIRenderer?

    /// What the host says for whoever reads its log: standard error, or wherever a test listens.
    static var log = HostLog(host: "WinUI")

    let frameClock: WinUIFrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    private let reducesMotion: () -> Bool

    /// The parts every host holds alike - the core's link, the motions, the display cycle, the mounted tree and
    /// the turn - each element's WinUI half a `WinUIElement`.
    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in WinUIElement(element, host: self) }, log: { WinUIRenderer.log.error($0) })

    /// What performs the acts the application calls, and answers them.
    private(set) lazy var acts = WinUIActPerformer(core: runtime.core)

    /// A controller for each window element the tree holds, in the tree's order.
    private(set) var windows: [WinUIWindowController] = []

    /// The first window - the scene's main one, where the application's questions stand; nil before there is one.
    var window: WinUIWindow? {
        windows.first?.window
    }

    /// A runtime on the performance counter and WinUI's frames, or on `clock` and the frames its owner gives, with
    /// the motion `reducesMotion` allows.
    init(clock: (() -> Double)? = nil, reducesMotion: @escaping () -> Bool = { !stateui_winui_animations_enabled() }) {
        frameClock = clock.map { WinUIFrameClock(now: $0, ticksWithWinUI: false) } ?? WinUIFrameClock()
        self.reducesMotion = reducesMotion
        runtime.displayCycle.presenter = self
        runtime.pump.presenter = self
    }

    /// WinUI stands on this thread: the first drain makes it MainActor's, then the host starts.
    /// Design: docs/design/platforms/winui/runtime.md#starting
    nonisolated static func launch() {
        let core = CoreLink()
        _ = core.needsRender
        _ = core.runJobs()

        MainActor.assumeIsolated { _ = start() }
    }

    /// Starts the host: the application rendered whole, then the doorbell for everything after.
    @discardableResult
    static func start() -> WinUIRenderer {
        shared?.runtime.tree.root?.leave()

        let previous = shared
        let renderer = WinUIRenderer()
        shared = renderer
        renderer.runtime.core.setRealization(
            WinUIRegistrations.registry.realization, unrealized: WinUIRealization.unrealized)
        if previous == nil { WinUIPersistence.restore(into: renderer.runtime.core) }
        renderer.show()
        WinUIDoorbell.install()
        stateui_winui_watch_environment()
        return renderer
    }

    /// The user answered a question put under `ticket`: its caller hears the answer, and what it changes renders.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        acts.answered(ticket: ticket, accepted: accepted, words: words)
        runtime.pump.turn()
    }

    /// Windows said the theme, the power or the network changed: the core hears it, and renders what it changed.
    func environmentChanged() {
        runtime.environmentChanged { WinUIEnvironment.reportChanging(to: runtime.core) }
    }

    /// The window numbered `window` moved the application into `phase`: heard where it is this runtime's window.
    /// Design: docs/design/platforms/winui/runtime.md#the-applications-phase
    func phaseChanged(_ phase: ApplicationPhase, window number: Int64) {
        guard let window = windows.first(where: { $0.window.number == number })?.window, !window.isClosed else { return }
        runtime.enterPhase(phase)
    }

    /// The window numbered `number` closed: one the tree closed tells nothing; one the user closed is heard by it
    /// and its scene.
    /// Design: docs/design/host/runtime.md#a-window-the-user-closes
    func windowClosed(number: Int64) {
        guard let controller = windows.first(where: { $0.window.number == number }), !controller.window.isClosed
        else { return }
        controller.window.closed()
        if let element = controller.element { runtime.userClosed(element) }
    }

    /// Renders the application whole, connecting its scene first.
    func show() {
        WinUIEnvironment.report(to: runtime.core)
        runtime.tree.followTheLanguagesDirection()
        runtime.core.connectScene()
        runtime.pump.turn()
    }

    /// Shows every window element in a WinUI window of its own, in the tree's order - a window the tree no longer
    /// holds closes - and tells each, once, in its turn, that it was made.
    /// Design: docs/design/platforms/winui/runtime.md#the-window
    private func showWindows() {
        var elements: [MountedElement] = []
        Self.collectWindows(in: runtime.tree.root, into: &elements)
        for controller in windows where !elements.contains(where: { $0 === controller.element }) {
            controller.window.close()
        }

        let first = windows.isEmpty && !elements.isEmpty
        windows = elements.map { element in
            windows.first { $0.element === element } ?? WinUIWindowController(element)
        }
        if first, let window {
            // The screen is known once there is a window; what reads it renders in the turn after this one.
            WinUIEnvironment.reportDisplay(to: runtime.core, window: window)
            runtime.pump.turn()
        }
        for controller in windows {
            guard let element = controller.element else { continue }
            controller.present(element, in: runtime)
        }
    }

    /// The window elements under `element`, in order; a window holds none.
    private static func collectWindows(in element: MountedElement?, into windows: inout [MountedElement]) {
        guard let element else { return }
        if element.type == .window { return windows.append(element) }
        for child in element.children { collectWindows(in: child, into: &windows) }
    }

    /// Composes every window's chrome again from what it shows now.
    func refreshWindowChrome() {
        for controller in windows { controller.refreshChrome(in: runtime) }
    }

    /// The controller of the window `element` stands in; nil for none.
    func controller(of element: MountedElement) -> WinUIWindowController? {
        var window: MountedElement? = element
        while let each = window, each.type != .window { window = each.parent }
        return windows.first { $0.element === window }
    }

    /// The page's corner in the window `element` stands in, in DIPs: where content stands clear of its chrome.
    func safeAreaOrigin(of element: MountedElement) -> Point {
        (controller(of: element) ?? windows.first)?.safeAreaOrigin ?? Point(x: 0, y: 0)
    }
}

extension WinUIRenderer: TurnPresenter {
    func presentRendered() {
        showWindows()
        refreshWindowChrome()
    }

    func perform(_ call: HostActCall) {
        acts.perform(call, in: runtime.tree, window: window)
    }
}

extension WinUIRenderer: FramePresenter {
    var wantsFrames: Bool {
        runtime.frames.wantsFrames
    }

    func commitUserReports(now: Double) {
        runtime.frames.commit(now: now)
    }

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        runtime.tree.present(states: states, properties: properties)
    }

    func renderIfNeeded() {
        if runtime.core.needsRender { runtime.pump.turn() }
    }
}
