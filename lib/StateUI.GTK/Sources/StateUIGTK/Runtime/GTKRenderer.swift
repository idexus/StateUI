// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// The GTK runtime: the mounted tree over GTK widgets, the window around it, and the turn.
/// Design: docs/design/platforms/gtk/runtime.md#the-gtk-runtime
@MainActor
final class GTKRenderer {
    /// The one runtime of the process, made when the application is activated.
    static var shared: GTKRenderer?

    let core = CoreLink()
    let intake = PatchIntake()
    let animator = Animator()
    let stateChannels: StateChannels
    let describedMotion: DescribedMotion
    let layoutMotion: LayoutMotion
    let frameClock: GTKFrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    let reducesMotion: () -> Bool
    let displayCycle: DisplayCycle

    /// The application the windows belong to.
    let application: UnsafeMutablePointer<GtkApplication>

    /// The mounted tree; each element's GTK half is a `GTKElement`.
    private(set) lazy var tree = MountedTree(
        core: core,
        intake: intake,
        stateChannels: stateChannels,
        describedMotion: describedMotion,
        layoutMotion: layoutMotion,
        now: frameClock.now,
        reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in GTKElement(element, host: self) })

    /// The turn: jobs, a pending cycle, a render, the handlers, then the acts.
    private(set) lazy var pump = Pump(
        core: core, intake: intake, tree: tree, displayCycle: displayCycle, now: frameClock.now,
        log: { GTKLog.error($0) })

    /// The window the first window element shows in; nil before it says it is there.
    private(set) var window: GTKWindow?

    /// The arrangement of pages the window shows, held by its mounted element, which owns its GTK half.
    private var shownArrangementElement: MountedElement?

    /// The window told it was made.
    private weak var createdWindow: MountedElement?

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
        stateChannels = StateChannels(animator: animator)
        describedMotion = DescribedMotion(animator: animator)
        layoutMotion = LayoutMotion(animator: animator, now: frameClock.now, reducesMotion: reducesMotion)
        displayCycle = DisplayCycle(
            core: core,
            clock: frameClock,
            animator: animator,
            stateChannels: stateChannels,
            describedMotion: describedMotion,
            layoutMotion: layoutMotion,
            reducesMotion: reducesMotion)
        frameClock.onFrame = { [weak self] now in self?.displayCycle.frame(now: now) }
        layoutMotion.onStart = { [weak self] in self?.displayCycle.hold() }
        tree.onAnimation = { [weak self] in self?.displayCycle.hold() }
        displayCycle.presenter = self
        pump.presenter = self
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
        shared?.tree.root?.leave()

        let renderer = GTKRenderer(application: application)
        shared = renderer
        renderer.show()
        GTKDoorbell.install()
        return renderer
    }

    /// Renders the application whole, connecting its scene first.
    func show() {
        core.connectScene()
        pump.turn()
    }

    /// Reports a native event and runs its handler, then a turn; one raised while a patch applies, or inside a
    /// user's transaction, waits for it.
    func dispatch(_ handler: Int32, payload: [HostValue] = []) {
        pump.dispatch(handler, payload: payload)
    }

    /// Reports a value the user set through a bound state.
    @discardableResult
    func report(_ value: HostStateValue, through binding: HostStateBinding) -> Bool {
        guard core.report(value, through: binding) else { return false }

        displayCycle.drain(now: frameClock.now(), reported: [binding.state: value])
        return true
    }

    /// Takes a journey the host carries at the position the user set.
    @discardableResult
    func take(_ value: [Double], through binding: HostStateBinding) -> Bool {
        guard stateChannels.take(value, through: binding) else { return false }

        displayCycle.drain(now: frameClock.now())
        return true
    }

    /// Shows the first window's arrangement of pages in a GTK window, titled as the window says, and tells the
    /// window it was made, once, in its turn.
    /// Design: docs/design/platforms/gtk/runtime.md#the-window
    private func showWindow() {
        guard let element = tree.root?.first(type: .window) else { return }

        let window = self.window ?? GTKWindow(application: application)
        if self.window == nil {
            self.window = window
            frameClock.widget = window.widget
        }
        window.setTitle(element.value(.title)?.string)

        let arrangement = element.children.first { GTKElement.pageTypes.contains($0.type) }
        if arrangement !== shownArrangementElement {
            shownArrangementElement = arrangement
            window.show(arrangement?.gtk.view)
        }

        if element !== createdWindow {
            createdWindow = element
            if let handler = element.handler(.created) { pump.handlers.enqueuePhase(handler) }
        }
    }
}

extension GTKRenderer: TurnPresenter {
    func presentRendered() {
        showWindow()
    }

    func perform(_ call: HostActCall) {
        if let completion = call.completion {
            _ = core.fail(completion, reason: "the GTK host performs no act yet: \(call.act.name)")
        }
    }
}

extension GTKRenderer: FramePresenter {
    var wantsFrames: Bool { false }

    func commitUserReports(now: Double) {}

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        tree.present(states: states, properties: properties)
    }

    func renderIfNeeded() {
        if core.needsRender { pump.turn() }
    }
}
