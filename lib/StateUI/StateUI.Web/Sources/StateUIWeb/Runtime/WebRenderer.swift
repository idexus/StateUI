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
    static let log = HostLog(host: "Web")

    let frameClock = WebFrameClock()

    /// The application's name, which the core tells the application.
    let applicationName: String

    /// The parts every host holds alike, each element's Web half a `WebElement`.
    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: { WebRelay.reducesMotion },
        makeNative: { [unowned self] element in WebElement(element, host: self) }, log: { WebRenderer.log.error($0) },
        views: { WebDOMView.liveCount })

    /// The windows the tree holds, each with its controller, in the tree's order. The browser shows the first.
    private let roster = WindowRoster<WebWindowController>()

    init(applicationName: String) {
        self.applicationName = applicationName
        runtime.displayCycle.presenter = self
        runtime.pump.presenter = self
    }

    /// Starts the host in the page: told what the page stands on, the application rendered in one new scene, and a
    /// turn after every call the page makes from then on.
    /// Design: docs/design/platforms/web/runtime.md#starting
    static func start(applicationName: String) {
        WebRelay.start()
        let renderer = WebRenderer(applicationName: applicationName)
        shared = renderer
        let core = renderer.runtime.core
        core.setRealization(WebRegistrations.registry.realization, unrealized: WebRealization.unmade)
        WebEnvironment.report(to: core, applicationName: applicationName)
        WebEnvironment.watch { [weak renderer] in
            renderer?.runtime.environmentChanged { WebEnvironment.reportChanging(to: core) }
        }
        WebRelay.afterEntry = { [weak renderer] in renderer?.entryEnded() }
        renderer.runtime.connectWindow()
        renderer.entryEnded()
    }

    /// Every call from the page ends with a turn, and asks the page to call again where work is left or a job kept
    /// for later comes due.
    /// Design: docs/design/platforms/web/runtime.md#the-relay
    func entryEnded() {
        runtime.pump.turn()
        if let wait = runtime.core.nextWake { WebRelay.wake(after: wait) }
    }

    /// Shows the first window element in the browser's window - a window the tree no longer holds closes - each told
    /// once, in its turn, that it was made.
    private func showWindows() {
        roster.update(
            root: runtime.tree.root, make: { [runtime] in WebWindowController($0, runtime: runtime) },
            close: { $0.window.close() })
        if let (element, controller) = roster.windows.first {
            controller.present(element, in: runtime)
            controller.refreshChrome()
        }
        runtime.frames.laidOut()
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

extension WebRenderer: TurnPresenter {
    func presentRendered() {
        showWindows()
    }

    /// The Web host performs no act yet: one called fails at once, so its handler goes on.
    func perform(_ call: HostActCall) {
        WebRenderer.log.error("the Web host performs no act yet: \(call.act.name)")
        if let completion = call.completion {
            _ = runtime.core.fail(completion, reason: "the Web host performs no act yet")
        }
    }
}

extension WebRenderer: FramePresenter {
    var wantsFrames: Bool {
        runtime.frames.wantsFrames
    }

    func commitUserReports(now: Double) {
        runtime.frames.commit(now: now)
    }

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        if runtime.tree.present(states: states, properties: properties).windowChrome { showWindows() }
    }

    func renderIfNeeded() {
        if runtime.core.needsRender { runtime.pump.turn() }
    }
}
