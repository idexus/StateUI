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

    let frameClock: GTKFrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    private let reducesMotion: () -> Bool

    /// The application the windows belong to.
    let application: UnsafeMutablePointer<GtkApplication>

    /// The parts every host holds alike - the core's link, the motions, the display cycle, the mounted tree and
    /// the turn - each element's GTK half a `GTKElement`.
    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in GTKElement(element, host: self) }, log: { GTKLog.error($0) })

    /// What performs the acts the application calls, and answers them.
    private(set) lazy var acts = GTKActPerformer(core: runtime.core)

    /// The application's ID, which the desktop knows it by.
    var applicationID: String {
        g_application_get_application_id(application.of(GApplication.self)).map { String(cString: $0) } ?? ""
    }

    /// The window the first window element shows in; nil before it says it is there.
    private(set) var window: GTKWindow?

    /// What the window shows, by the host layer's rule: its arrangement of pages, its overlay, and that it was made.
    private let presentation = WindowPresentation()

    /// Whether the screen the window stands on has been told.
    private var reportedDisplay = false

    /// Whether the window's split view has been opened wide, once.
    private var openedWide = false

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
        renderer.runtime.core.setRealization(GTKRegistrations.registry.realization, unrealized: GTKRealization.unrealized)
        renderer.show()
        GTKDoorbell.install()
        return renderer
    }

    /// Renders the application whole, connecting its scene first, told what the host stands on.
    func show() {
        GTKEnvironment.report(to: runtime.core, applicationID: applicationID)
        GTKKeptValues.restore(into: runtime.core, applicationID: applicationID)
        GTKEnvironment.watch { [weak self] in self?.environmentChanged() }
        runtime.core.connectScene()
        runtime.pump.turn()
    }

    /// The desktop's style turned dark or light: the core hears it, and renders what it changed.
    func environmentChanged() {
        GTKEnvironment.reportChanging(to: runtime.core)
        runtime.pump.turn()
    }

    /// Shows the first window's arrangement of pages in a GTK window - a page by itself in a frame of its own - its
    /// pages hearing that they show, and tells the window it was made, once, in its turn.
    /// Design: docs/design/platforms/gtk/runtime.md#the-window
    private func showWindow() {
        guard let element = runtime.tree.root?.first(type: .window) else { return }

        let window = self.window ?? GTKWindow(application: application)
        if self.window == nil {
            self.window = window
            frameClock.widget = window.widget
        }
        if !reportedDisplay, gtk_widget_get_realized(window.widget) != 0 {
            reportedDisplay = true
            GTKEnvironment.reportDisplay(to: runtime.core, window: window.widget)
        }
        window.setSize(width: element.value(.width)?.number, height: element.value(.height)?.number)
        window.setMinimumSize(width: element.value(.minimumWidth)?.number, height: element.value(.minimumHeight)?.number)

        let changes = presentation.show(element)
        if let (_, arrangement) = changes.arrangement {
            if let arrangement, GTKElement.framedTypes.contains(arrangement.type) {
                window.show(page: arrangement.gtk.view)
            } else {
                window.show(arrangement?.gtk.view)
            }
        }
        if let overlay = changes.overlay { window.showOverlay(overlay?.gtk.view) }
        refreshChrome()
    }

    /// Writes every shown page's chrome on its header bar, and names the window after the page the user sees.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    func refreshChrome() {
        guard let window, let element = runtime.tree.root?.first(type: .window)?.gtk else { return }

        let arrangement = presentation.arrangement?.gtk
        if let arrangement, GTKElement.framedTypes.contains(arrangement.type) {
            window.pageFrame?.show(arrangement.chrome)
        }
        arrangement?.composeChrome()
        adaptSplitViews(in: window)
        let pageTitle = presentation.arrangement?.visiblePage?.value(.title)?.string
        window.setTitle(pageTitle.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string)
    }

    /// Collapses the window's split view where the window is narrow, and opens it wide with its sidebar shown once
    /// the window first stands - said in the next turn, as the user's.
    private func adaptSplitViews(in window: GTKWindow) {
        guard let split = presentation.arrangement?.gtk, split.type == .splitView, let view = split.view as? GTKSplitView
        else { return }

        view.adapt(in: window.widget)
        guard !openedWide else { return }
        openedWide = true
        GTKDoorbell.afterLayout { [weak split] in
            guard let split, let view = split.view as? GTKSplitView, view.openWide() else { return }
            split.sidebarChanged(to: true)
        }
    }

    /// Goes the way back the arrangement the window shows offers, as the user does - a stack's top page going;
    /// whether there was one.
    func goBack() -> Bool {
        presentation.arrangement?.gtk.goBack() ?? false
    }
}

extension GTKRenderer: TurnPresenter {
    func presentRendered() {
        showWindow()
    }

    func perform(_ call: HostActCall) {
        acts.perform(call, in: runtime.tree, window: window, applicationID: applicationID)
    }
}

extension GTKRenderer: FramePresenter {
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
