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

    /// Where the children of the page's traveling layouts stand, read around each call's changes.
    let placements = WebPlacements()

    /// The application's name, which the core tells the application.
    let applicationName: String

    /// What the host hears the page by - its focus and visibility, its leaving, the user's appearance - for as
    /// long as it runs the page.
    private(set) var pageListeners: [Int32] = []

    /// The parts every host holds alike, each element's Web half a `WebElement`.
    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in WebElement(element, host: self) }, log: { WebRenderer.log.error($0) },
        views: { WebDOMView.liveCount })

    /// The Web's part of the acts and of the files, and what performs them and answers them by the host layer's rules.
    private(set) lazy var actToolkit = WebActToolkit(renderer: self)
    private(set) lazy var acts = HostActPerformer(
        toolkit: actToolkit, files: WebFileToolkit(renderer: self), network: WebNetwork(), answers: runtime.core,
        tree: { [unowned self] in runtime.tree })

    /// Whether the call ending reports what it laid out: a call the browser makes inside it reports nothing.
    private var ending = false

    /// The windows the tree holds, each with its controller, in the tree's order. The browser shows the first.
    let roster = WindowRoster<WebWindowController>()

    /// The window element the browser shows, which a question and a file dialog stand over.
    var shownWindow: MountedElement? { roster.windows.first?.element }

    /// The window a window's act asks in: the one the browser shows, where the act names it or none; nil for
    /// another.
    func window(asked element: MountedElement?) -> MountedElement? {
        guard let shownWindow, element == nil || element?.enclosing(type: .window) === shownWindow else { return nil }
        return shownWindow
    }

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
        WebRelay.afterEntry = { [weak self] in self?.entryEnded() }
        pageListeners = [
            WebRelay.listener { [weak self] in self?.pageChanged(WebRelay.pageState) },
            WebRelay.listener { [weak self] in self?.runtime.ending() },
        ]
        WebRelay.listenToPage(changed: pageListeners[0], leaving: pageListeners[1])
        let shortcuts = WebRelay.listener { [weak self] in self?.pressedShortcut() }
        let keys = WebRelay.listener { [weak self] in self?.pressedKey() }
        pageListeners += [shortcuts, keys]
        WebRelay.hear(WebRelay.body, .shortcut, shortcuts)
        WebRelay.hear(WebRelay.body, .key, keys)
        // A link into the application is the page's address with a fragment, as it starts and as the fragment moves.
        // Design: docs/design/platforms/web/runtime.md#a-link-opened
        let links = WebRelay.listener { [weak self] in
            let address = WebRelay.pageLink
            if !address.isEmpty { self?.runtime.openLink(address) }
        }
        pageListeners.append(links)
        WebRelay.listenForLinks(links)
        runtime.start(
            realizing: WebRegistrations.registry.realization, unrealized: WebRealization.unmade,
            register: WebRealization.register,
            complainingTo: WebRenderer.log,
            environment: {
                WebEnvironment.report(to: core, applicationName: applicationName)
                pageListeners.append(WebEnvironment.watch { [weak self] in
                    self?.runtime.environmentChanged { WebEnvironment.reportChanging(to: core) }
                })
            },
            kept: { WebKeptValues.readKept(into: core, application: applicationName) },
            // The scenes kept when the page was left come back; else the window launch opens.
            windows: { scenes.restore(WebKeptValues.readScenes(applicationName), in: runtime) },
            turns: entryEnded)
    }

    /// A key going down before the element holding the keyboard has it, sent to a view taking it (`KeyPresses`) -
    /// out from the element holding the focus, else from the page in front; where one takes it, nothing else hears
    /// the key.
    private func pressedKey() {
        let told = (0...3).map { Int32(WebRelay.eventNumber($0)) }
        guard let pressed = WebKeys.shortcut(named: told[0], written: told[1], physical: told[3], held: told[2]),
              let window = runtime.tree.root?.first(type: .window),
              let controller = roster.windows.first(where: { $0.0 === window })?.1
        else { return }
        let holder = KeyPresses.holder(under: window) { held in
            (held.native as? WebElement)?.view.map { WebRelay.holdsFocus($0.node) } ?? false
        }
        guard KeyPresses.press(
            pressed.key, modifiers: pressed.modifiers, focused: holder, front: controller.presentation.frontPage,
            in: runtime)
        else { return }
        WebRelay.takeEvent()
    }

    /// A key pressed in the page reaching the element of the window stating it as a shortcut; where one takes it,
    /// the browser does nothing more with the key.
    private func pressedShortcut() {
        let told = (0...4).map { Int32(WebRelay.eventNumber($0)) }
        guard let shortcut = WebKeys.shortcut(named: told[0], written: told[1], physical: told[4], held: told[2]),
              let window = runtime.tree.root?.first(type: .window),
              KeyboardShortcuts.press(shortcut, under: window, in: runtime, typing: told[3] != 0)
        else { return }
        WebRelay.takeEvent()
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

    /// Shows the first window element in the browser's window - a window the tree no longer holds closes, what was
    /// asked over it answered as dismissed - each told once, in its turn, that it was made.
    private func showWindows() {
        let shown = roster.windows.first?.controller
        roster.update(
            root: runtime.tree.root, make: { [runtime] in WebWindowController($0, runtime: runtime) },
            close: { [actToolkit] closing in
                if closing === shown { actToolkit.windowWent() }
                closing.close()
            })
        acts.windowsOpen(roster.windows.map(\.element))
        if let (element, controller) = roster.windows.first {
            controller.present(element, in: runtime)
            controller.refreshChrome()
        }
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

    /// Where a page's content may stand on the page: the window's room below its bar, which stands over the room's
    /// top - as deep as the room keeps its content clear of it - or the whole room where no bar shows.
    /// Design: docs/design/platforms/web/pages.md#the-safe-area
    var contentBox: Rect {
        guard let window = roster.controllers.first?.window else { return Rect(x: 0, y: 0, width: 0, height: 0) }
        let room = WebRelay.box(of: window.room.node)
        let bar = WebRelay.box(of: window.bar.node)
        let top = max(room.y, bar.height > 0 ? bar.y + bar.height : room.y)
        return Rect(x: room.x, y: top, width: room.width, height: max(0, room.y + room.height - top))
    }
}

extension WebRenderer: HostPresenter {
    func presentRendered(touchedChrome: Bool) {
        if touchedChrome { showWindows() } else { roster.controllers.first?.adaptSidebar() }
        // What a render wrote may move a view without resizing it, which no observer of the page tells.
        runtime.frames.laidOut()
        for popover in runtime.tree.takeWaitingPopovers() { popover.web.configurePopover() }
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

    func open(link address: String) {
        acts.open(link: address)
    }

    func focus(_ element: MountedElement) {
        acts.focus(element)
    }
}
