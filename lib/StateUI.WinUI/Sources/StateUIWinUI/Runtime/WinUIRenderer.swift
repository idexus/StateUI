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

    /// What the host says for whoever reads its log.
    static let log = HostLog(host: "WinUI")

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

    /// The window the first window element shows in; nil before it says it is there.
    private(set) var window: WinUIWindow?

    /// What the window shows, by the host layer's rule: its arrangement of pages, its overlay, and that it was made.
    private let presentation = WindowPresentation()

    /// The sheets the window shows, one for each page its modal stack presents, the last on top.
    private var sheets: [(element: MountedElement, sheet: WinUISheetView)] = []

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
        guard let window, window.number == number, !window.isClosed else { return }
        runtime.enterPhase(phase)
    }

    /// Renders the application whole, connecting its scene first.
    func show() {
        WinUIEnvironment.report(to: runtime.core)
        runtime.tree.followTheLanguagesDirection()
        runtime.core.connectScene()
        runtime.pump.turn()
    }

    /// Shows the first window's arrangement of pages, its sheets and its overlay in a WinUI window, its pages hearing
    /// that they show, and tells the window it was made, once, in its turn.
    /// Design: docs/design/platforms/winui/runtime.md#the-window
    private func showWindow() {
        guard let element = runtime.tree.root?.first(type: .window) else { return }

        if self.window == nil {
            let window = WinUIWindow()
            self.window = window
            // The screen is known once there is a window; what reads it renders in the turn after this one.
            WinUIEnvironment.reportDisplay(to: runtime.core, window: window)
            runtime.pump.turn()
        }
        guard let window = self.window else { return }

        // What the user sees is the top sheet, else the window's arrangement: the one that stops showing hears it,
        // then the one that starts - by the window's own coming and going, or by a sheet's, as a move.
        let previousVisible = sheets.last?.element ?? presentation.arrangement
        let hadSheets = !sheets.isEmpty
        let changes = presentation.show(element)
        if let (_, arrangement) = changes.arrangement { window.show(arrangement?.winUI.view) }
        showSheets(of: element, in: window)
        if let overlay = changes.overlay { window.showOverlay(overlay?.winUI.view) }
        let visible = sheets.last?.element ?? presentation.arrangement
        if visible !== previousVisible {
            let reason: WinUIPagePresentationReason = hadSheets || !sheets.isEmpty ? .navigation : .window
            previousVisible?.winUI.setPagePresented(false, reason: reason)
            visible?.winUI.setPagePresented(true, reason: reason)
        }

        if let handler = changes.created { runtime.pump.handlers.enqueuePhase(handler) }
    }
}

extension WinUIRenderer {
    /// Keeps a sheet for each page the window's modal stack presents, in its order, each under its page's title.
    /// Design: docs/design/platforms/winui/pages.md#the-modal-stack
    private func showSheets(of window: MountedElement, in native: WinUIWindow) {
        let pages = window.children.first { $0.type == .modalStack }?.children
            .filter { NodeType.pageTypes.contains($0.type) } ?? []
        guard !pages.isEmpty || !sheets.isEmpty else { return }

        sheets = pages.map { page in
            let sheet = sheets.first { $0.element === page }?.sheet ?? WinUISheetView()
            sheet.show(title: page.winUI.visiblePage?.value(.title)?.string ?? "", page: page.winUI.view)
            return (page, sheet)
        }
        native.showSheets(sheets.map(\.sheet))
    }

    /// The user took the top sheet away - Escape, the way back of a sheet with none of its own: the window is told
    /// how many remain.
    func dismissTopSheet() {
        guard !sheets.isEmpty, let window = runtime.tree.root?.first(type: .window),
              let handler = window.handler(.modalPopped)
        else { return }

        runtime.dispatch(handler, payload: [.number(Double(sheets.count - 1))])
    }

    /// Composes the window's one chrome again from what it shows now: the top page names the window, the stack's
    /// way back and the page's actions stand on the chrome, a split view adds the sidebar's toggle, the page's menus
    /// and the tabs of a tabbed view on the page path stand beneath it, and an authored title bar adds its slots.
    /// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
    func refreshWindowChrome() {
        guard let window, let element = runtime.tree.root?.first(type: .window)?.winUI else { return }

        let arrangement = presentation.arrangement?.winUI
        arrangement?.markTabsShownByWindow()
        let titleBar = element.children.first { $0.type == .titleBar }
        let actions = arrangement?.visibleToolbarActions ?? (primary: [], overflow: [])

        var chrome = WinUIWindowChrome()
        chrome.title = arrangement?.visiblePage?.value(.title)?.string ?? element.value(.title)?.string ?? ""
        chrome.back = arrangement?.visibleBackAction
        chrome.sidebarToggle = arrangement?.visibleSidebarToggle
        chrome.leading = titleBar?.firstView(in: .leadingContent)
        chrome.center = titleBar?.firstView(in: .content) ?? arrangement?.visibleTitleView
        chrome.trailing = titleBar?.firstView(in: .trailingContent)
        chrome.actions = actions.primary
        chrome.overflow = actions.overflow
        chrome.background = arrangement?.visibleBarBackground ?? titleBar?.value(.background)
        chrome.foreground = arrangement?.visibleBarForeground ?? titleBar?.value(.barForegroundColor)
        chrome.menuBar = WinUIMenu(bar: arrangement?.visiblePage?.children.first { $0.type == .menuBar })
        if let top = sheets.last?.element.winUI {
            chrome.sheet = (
                back: { [weak self, weak top] in
                    if let wayBack = top?.wayBack { wayBack() } else { self?.dismissTopSheet() }
                },
                dismiss: { [weak self] in self?.dismissTopSheet() })
        }
        window.apply(chrome, tabs: arrangement?.visibleWindowTabs)
    }

    /// Goes the way back the arrangement the window shows offers - a stack's top page going; whether there was one.
    /// Design: docs/design/platforms/winui/pages.md#the-way-back
    func goBack() -> Bool {
        guard let wayBack = presentation.arrangement?.winUI.wayBack else { return false }

        wayBack()
        return true
    }

    /// The page's corner in the window, in DIPs: where content stands clear of the window's chrome.
    var safeAreaOrigin: Point {
        guard let content = window?.content else { return Point(x: 0, y: 0) }
        return content.origin
    }
}

extension WinUIRenderer: TurnPresenter {
    func presentRendered() {
        showWindow()
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
