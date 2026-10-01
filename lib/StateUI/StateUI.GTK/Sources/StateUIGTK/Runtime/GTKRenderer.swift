// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// The GTK runtime: the mounted tree over GTK widgets, the window around it, and the turn.
/// Design: docs/design/platforms/gtk/runtime.md#the-gtk-runtime
@MainActor
final class GTKRenderer {
    /// The one runtime of the process, made when the application is activated.
    static var shared: GTKRenderer?

    /// What the host says for whoever reads its log: standard error, or wherever a test listens.
    static var log = HostLog(host: "GTK")

    let frameClock: GTKFrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    private let reducesMotion: () -> Bool

    /// The application the windows belong to.
    let application: UnsafeMutablePointer<GtkApplication>

    /// The parts every host holds alike - the core's link, the motions, the display cycle, the mounted tree and
    /// the turn - each element's GTK half a `GTKElement`.
    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in GTKElement(element, host: self) }, log: { GTKRenderer.log.error($0) })

    /// GTK's part of the acts: the clock, the dialogs, the screen reader, the focus, the kept values.
    private(set) lazy var actToolkit = GTKActToolkit(renderer: self)

    /// What performs the acts the application calls, and answers them, by the host layer's rules.
    private(set) lazy var acts = HostActPerformer(
        toolkit: actToolkit, answers: runtime.core, tree: { [unowned self] in runtime.tree },
        answered: { [unowned self] in runtime.pump.turn() })

    /// The application's ID, which the desktop knows it by.
    var applicationID: String {
        g_application_get_application_id(application.of(GApplication.self)).map { String(cString: $0) } ?? ""
    }

    /// The windows the tree holds, each with its controller, in the tree's order.
    private let roster = WindowRoster<GTKWindowController>()

    /// A controller for each window element the tree holds, in the tree's order.
    var windows: [GTKWindowController] {
        roster.controllers
    }

    /// The first window - the scene's main one; nil before there is one.
    var window: GTKWindow? {
        windows.first?.window
    }

    /// The window the user is in: the one activated last, else the first.
    var userWindow: GTKWindow? {
        let front = runtime.lifecycle.activatedLast(among: roster.windows.map(\.element))
        return front.flatMap { roster.controller(of: $0)?.window } ?? window
    }

    /// What is kept of the scenes for the next start: the desktop restores no windows.
    let scenes = SceneKeeper()

    /// Whether the screen the window stands on has been told.
    private var reportedDisplay = false

    /// A runtime whose windows belong to `application`, on GLib's monotonic clock or on `clock`, with the motion
    /// `reducesMotion` allows.
    init(
        application: UnsafeMutablePointer<GtkApplication>,
        clock: (() -> Double)? = nil,
        reducesMotion: @escaping () -> Bool = { MainActor.assumeIsolated { GTKEnvironment.reducesMotion } }
    ) {
        self.application = application
        let frameClock = clock.map { GTKFrameClock(now: $0, ticksWithGTK: false) } ?? GTKFrameClock()
        self.frameClock = frameClock
        self.reducesMotion = reducesMotion
        runtime.displayCycle.presenter = self
        runtime.pump.presenter = self
    }

    /// The application was activated on GLib's thread: the first time, the first drain makes it MainActor's and
    /// the host starts; after that, a second launch brings the window forward.
    /// Design: docs/design/platforms/gtk/runtime.md#starting
    nonisolated static func activated(_ application: UnsafeMutablePointer<GtkApplication>) {
        let core = CoreLink()
        _ = core.needsRender
        _ = core.runJobs()
        nonisolated(unsafe) let application = application

        MainActor.assumeIsolated {
            if let window = shared?.window {
                window.present()
            } else {
                start(application: application)
            }
        }
    }

    /// Starts the host: the application rendered whole, then the doorbell for everything after.
    @discardableResult
    static func start(application: UnsafeMutablePointer<GtkApplication>) -> GTKRenderer {
        shared?.runtime.tree.root?.leave()

        let renderer = GTKRenderer(application: application)
        shared = renderer
        renderer.runtime.core.setRealization(
            GTKRegistrations.registry.realization,
            unrealized: GTKRealization.unmade)
        renderer.show()
        GTKDoorbell.install()
        return renderer
    }

    /// Renders the application whole, told what the host stands on: the scenes kept for this start come back, else
    /// one new scene.
    /// Design: docs/design/host/runtime.md#kept-scenes
    func show() {
        GTKEnvironment.report(to: runtime.core, applicationID: applicationID)
        GTKKeptValues.restore(into: runtime.core, applicationID: applicationID)
        GTKEnvironment.watch { [weak self] in self?.environmentChanged() }
        scenes.restore(GTKKeptValues.readScenes(applicationID: applicationID), in: runtime)
    }

    /// The desktop's style, the power or the network changed: the core hears what stands now, the tree follows the
    /// language's direction, and a turn renders what it changed.
    func environmentChanged() {
        runtime.environmentChanged { GTKEnvironment.reportChanging(to: runtime.core) }
    }

    /// Shows every window element in a GTK window of its own, in the tree's order - a window the tree no longer
    /// holds closes - each page hearing that it shows, each window told once, in its turn, that it was made.
    /// Design: docs/design/platforms/gtk/runtime.md#the-window
    private func showWindows() {
        roster.update(
            root: runtime.tree.root, make: { [application] in GTKWindowController($0, application: application) },
            close: { $0.window.close() })
        if let window, frameClock.widget != window.widget { frameClock.widget = window.widget }
        for (element, controller) in roster.windows {
            controller.present(element, in: runtime, windowOf: { [roster] in roster.controller(of: $0)?.window })
        }
        if !reportedDisplay, let window, gtk_widget_get_realized(window.widget) != 0 {
            reportedDisplay = true
            GTKEnvironment.reportDisplay(to: runtime.core, window: window.widget)
        }
        refreshChrome()
    }

    /// Writes every window's chrome again from what it shows now.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    func refreshChrome() {
        for controller in windows { controller.refreshChrome() }
    }

    /// Goes the way back the window the user is in offers, as the user does; whether there was one.
    func goBack() -> Bool {
        let front = runtime.lifecycle.activatedLast(among: roster.windows.map(\.element))
        let controller = front.flatMap { roster.controller(of: $0) } ?? windows.first
        return controller?.goBack(in: runtime) ?? false
    }

    /// The window numbered `number` turned active or not, minimized or not: the host layer settles what that means
    /// for the application, its scenes and its windows.
    /// Design: docs/design/platforms/gtk/runtime.md#a-windows-life
    func windowStateChanged(number: Int64) {
        guard let controller = windows.first(where: { $0.window.number == number }), !controller.window.isClosed,
              let element = controller.element
        else { return }
        guard controller.window.statesChanged() else { return }
        runtime.windowStateChanged(element, minimized: controller.window.isMinimized, activated: controller.window.isActive)
    }

    /// The window numbered `number` went: one the tree closed tells nothing; one the user closed is heard by it and
    /// its scene.
    /// Design: docs/design/host/runtime.md#a-window-the-user-closes
    func windowClosed(number: Int64) {
        guard let controller = windows.first(where: { $0.window.number == number }), !controller.window.isClosed
        else { return }
        controller.window.closed()
        if let element = controller.element { runtime.userClosed(element) }
    }
}

extension GTKRenderer: TurnPresenter {
    func presentRendered() {
        showWindows()
        if let text = scenes.changed(root: runtime.tree.root) {
            GTKKeptValues.writeScenes(text, applicationID: applicationID)
        }
    }

    func perform(_ call: HostActCall) {
        acts.perform(call)
    }
}

extension GTKRenderer: FramePresenter {
    var wantsFrames: Bool {
        runtime.frames.wantsFrames
    }

    func commitUserReports(now: Double) {
        runtime.frames.commit(now: now)
    }

    /// A frame that moves what the chrome shows - a bar's colour, the window's frame - shows the window again.
    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        if runtime.tree.present(states: states, properties: properties).windowChrome { showWindows() }
    }

    func renderIfNeeded() {
        if runtime.core.needsRender { runtime.pump.turn() }
    }
}
