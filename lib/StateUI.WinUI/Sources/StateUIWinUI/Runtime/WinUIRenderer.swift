// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
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

    /// What is kept of the scenes for the next start: Windows restores no windows.
    let scenes = SceneKeeper()

    /// What performs the acts the application calls, and answers them.
    private(set) lazy var acts = WinUIActPerformer(core: runtime.core, scenes: scenes)

    /// The windows the tree holds, each with its controller, in the tree's order.
    private let roster = WindowRoster<WinUIWindowController>()

    /// A controller for each window element the tree holds, in the tree's order.
    var windows: [WinUIWindowController] {
        roster.controllers
    }

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

    /// The window numbered `number` was activated, deactivated or minimized: the host layer settles what that means
    /// for the application, its scenes and its windows, where it is one of this runtime's windows.
    /// Design: docs/design/platforms/winui/runtime.md#the-applications-phase
    func windowStateChanged(number: Int64, minimized: Bool, activated: Bool) {
        guard let controller = windows.first(where: { $0.window.number == number }), !controller.window.isClosed,
              let element = controller.element
        else { return }
        runtime.windowStateChanged(element, minimized: minimized, activated: activated)
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

    /// Renders the application whole: the scenes kept for this start come back, else one new scene.
    /// Design: docs/design/host/runtime.md#kept-scenes
    func show() {
        WinUIEnvironment.report(to: runtime.core)
        runtime.tree.followTheLanguagesDirection()
        scenes.restore(WinUIPersistence.readScenes(), in: runtime)
    }

    /// Shows every window element in a WinUI window of its own, in the tree's order - a window the tree no longer
    /// holds closes - and tells each, once, in its turn, that it was made.
    /// Design: docs/design/platforms/winui/runtime.md#the-window
    private func showWindows() {
        let first = roster.update(
            root: runtime.tree.root, make: { WinUIWindowController($0) }, close: { $0.window.close() })
        if first, let window {
            // The screen is known once there is a window; what reads it renders in the turn after this one.
            WinUIEnvironment.reportDisplay(to: runtime.core, window: window)
            runtime.pump.turn()
        }
        for (element, controller) in roster.windows {
            controller.present(element, in: runtime, windowOf: { [roster] in roster.controller(of: $0)?.window })
        }
    }

    /// Composes every window's chrome again from what it shows now.
    func refreshWindowChrome() {
        for controller in windows { controller.refreshChrome(in: runtime) }
    }

    /// The controller of the window `element` stands in; nil for none.
    func controller(of element: MountedElement) -> WinUIWindowController? {
        roster.controller(of: element)
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
        if let text = scenes.changed(root: runtime.tree.root) { WinUIPersistence.writeScenes(text) }
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
