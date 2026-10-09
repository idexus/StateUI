// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The Web runtime: the mounted tree over DOM elements, the browser's window around it, and the turn.
/// Design: docs/design/platforms/web/runtime.md#the-web-runtime
@MainActor
final class WebRenderer {
    /// The one runtime of the page.
    static var shared: WebRenderer?

    /// What the host says for whoever reads its log: the browser's console.
    static var log = HostLog(host: "Web")

    let frameClock: WebFrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    private let reducesMotion: () -> Bool

    /// Where the children of the page's travelling layouts stand, read around each call's changes.
    let placements = WebPlacements()

    /// The application's name, which the core tells the application.
    let applicationName: String

    /// The parts every host holds alike, each element's Web half a `WebElement`.
    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in WebElement(element, host: self) }, log: { WebRenderer.log.error($0) },
        views: { WebDOMView.liveCount })

    /// The Web's part of the acts and of the files, and what performs them and answers them by the host layer's rules.
    private(set) lazy var actToolkit = WebActToolkit(renderer: self)
    private(set) lazy var acts = HostActPerformer(
        toolkit: actToolkit, files: WebFileToolkit(), answers: runtime.core, tree: { [unowned self] in runtime.tree })

    /// Whether the call ending reports what it laid out: a call the browser makes inside it reports nothing.
    private var ending = false

    /// The windows the tree holds, each with its controller, in the tree's order. The browser shows the first.
    let roster = WindowRoster<WebWindowController>()

    /// What is kept of the scenes for the page's next start.
    let scenes = SceneKeeper()

    /// A runtime of the application `applicationName`, on the page's clock or on `clock`, with the motion
    /// `reducesMotion` allows.
    init(
        applicationName: String, clock: (() -> Double)? = nil,
        reducesMotion: @escaping () -> Bool = { MainActor.assumeIsolated { WebRelay.reducesMotion } }
    ) {
        self.applicationName = applicationName
        frameClock = clock.map { WebFrameClock(now: $0, ticksWithBrowser: false) } ?? WebFrameClock()
        self.reducesMotion = reducesMotion
        runtime.presenter = self
    }

    /// Starts the host in the page: told what the page stands on, the application rendered in one new scene, and a
    /// turn after every call the page makes from then on.
    /// Design: docs/design/platforms/web/runtime.md#starting
    static func start(applicationName: String) {
        WebRenderer(applicationName: applicationName).run()
    }

    /// Runs this host in the page, in place of any before it, on the page's thread claimed as the UI thread.
    func run() {
        runtime.core.claimUIThread()
        WebRelay.start()
        Self.shared = self
        let core = runtime.core
        core.setRealization(WebRegistrations.registry.realization, unrealized: WebRealization.unmade)
        WebEnvironment.report(to: core, applicationName: applicationName)
        WebKeptValues.restore(into: core, application: applicationName)
        WebEnvironment.watch { [weak self] in
            self?.runtime.environmentChanged { WebEnvironment.reportChanging(to: core) }
        }
        WebRelay.afterEntry = { [weak self] in self?.entryEnded() }
        WebRelay.listenToPage(
            changed: WebRelay.listener { [weak self] in self?.pageChanged(WebRelay.pageState) },
            leaving: WebRelay.listener { [weak self] in self?.runtime.ending() })
        // The scenes kept when the page was left come back; else the window launch opens.
        scenes.restore(WebKeptValues.readScenes(applicationName), in: runtime)
        entryEnded()
    }

    /// Every call from the page ends with a turn, and asks the page to call again where work is left or a job kept
    /// for later comes due.
    /// Design: docs/design/platforms/web/runtime.md#the-relay
    func entryEnded() {
        runtime.pump.turn()
        placements.settle()
        // What the call laid out says where it stands before the browser draws, so a size read from a frame is
        // drawn with the page it measures - once, as the outermost call ends: an event the browser raises inside
        // the turn ends a call of its own there.
        if !ending {
            ending = true
            defer { ending = false }
            if runtime.frames.reportLaidOut() {
                runtime.pump.turn()
                placements.settle()
            }
        }
        if let wait = runtime.core.nextWake { WebRelay.wake(after: wait) }
    }

    /// Shows the first window element in the browser's window - a window the tree no longer holds closes - each told
    /// once, in its turn, that it was made.
    private func showWindows() {
        roster.update(
            root: runtime.tree.root, make: { [runtime] in WebWindowController($0, runtime: runtime) },
            close: { $0.close() })
        if let (element, controller) = roster.windows.first {
            controller.present(element, in: runtime)
            controller.refreshChrome()
        }
        runtime.frames.laidOut()
    }

    /// The page's tab shows or not, and the page holds the keyboard or not: the window it shows is put away while
    /// its tab hides - it stops - and is the one in front while the page holds the keyboard.
    /// Design: docs/design/platforms/web/runtime.md#the-window
    func pageChanged(_ state: (shown: Bool, focused: Bool)) {
        guard let window = roster.windows.first?.element else { return }
        runtime.windowStateChanged(window, minimized: !state.shown, activated: state.shown && state.focused)
    }

    /// Writes the window's chrome again from what it shows now.
    func refreshChrome() {
        roster.controllers.first?.refreshChrome()
    }

    /// Where the window's room - its content, clear of its bar - stands on the page.
    var contentBox: Rect {
        roster.controllers.first.map { WebRelay.box(of: $0.window.room.node) } ?? Rect(x: 0, y: 0, width: 0, height: 0)
    }
}

extension WebRenderer: HostPresenter {
    func presentRendered() {
        showWindows()
        if let text = scenes.changed(root: runtime.tree.root) { WebKeptValues.writeScenes(text, application: applicationName) }
    }

    func presentFrame(movedChrome: Bool) {
        if movedChrome { showWindows() }
        // What a frame wrote may move a view without resizing it, which no observer of the page tells.
        runtime.frames.laidOut()
    }

    func perform(_ call: HostActCall) {
        acts.perform(call)
    }
}
