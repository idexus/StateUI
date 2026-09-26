// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// The Android Views runtime: the mounted tree over Android views, the activity's window around it, and the turn.
/// Design: docs/design/platforms/android/runtime.md#the-android-views-runtime
@MainActor
final class AndroidRenderer {
    /// The one runtime of the process, made when the activity starts it.
    static var shared: AndroidRenderer?

    /// The context every view is made in: the activity.
    static var context: jobject { shared!.context.reference }

    /// Pixels per point, the display's density.
    static var density: Double { shared?.density ?? 1 }

    let frameClock: AndroidFrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    let reducesMotion: () -> Bool

    /// The parts every host holds alike - the core's link, the motions, the display cycle, the mounted tree and
    /// the turn - each element's Android half an `AndroidElement`.
    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in AndroidElement(element, host: self) },
        log: { AndroidLog.error($0) })

    private let context: JavaObject

    /// The view the page is shown in: the activity's root.
    let root: JavaObject
    private let density: Double

    /// What the first window shows, by the host layer's rule: its arrangement of pages, its sheets, its overlay.
    private let presentation = WindowPresentation()

    /// Whether the activity was last told there is a way back.
    private var handlesBack = false

    /// The title the activity was last given, as the first window says it; none before any window says.
    private(set) var windowTitle: String??

    /// A runtime showing its page in `root`, on the display's clock or on `clock`,
    /// with the motion the user's settings allow or as `reducesMotion` says.
    init(
        context: JavaObject, root: JavaObject, density: Double,
        clock: (() -> Double)? = nil, reducesMotion: @escaping () -> Bool = { AndroidRenderer.animationsRemoved() }
    ) {
        self.context = context
        self.root = root
        self.density = density
        frameClock = clock.map { AndroidFrameClock(now: $0, ticksWithTheDisplay: false) } ?? AndroidFrameClock()
        self.reducesMotion = reducesMotion
        runtime.displayCycle.presenter = self
        runtime.pump.presenter = self
    }

    /// Whether the user turned the system's animations off, which StateUI reads as asking for less motion.
    /// Design: docs/design/platforms/android/motion.md#less-motion
    static func animationsRemoved() -> Bool {
        !Java.callStaticBool(JavaAPI.valueAnimator, JavaAPI.areAnimatorsEnabled)
    }

    /// Starts the host in an activity's root, then rings the doorbell for everything after its first render.
    /// An activity after the first takes over the scene the one before showed, rendered whole.
    /// Design: docs/design/platforms/android/runtime.md#a-later-activity
    @discardableResult
    static func start(context: JavaObject, root: JavaObject, density: Double) -> AndroidRenderer {
        let previous = shared
        previous?.runtime.tree.root?.leave()

        let renderer = AndroidRenderer(context: context, root: root, density: density)
        shared = renderer
        renderer.watchLayout()
        let core = renderer.runtime.core
        core.setRealization(AndroidRegistrations.registry.realization, unrealized: AndroidRealization.unrealized)
        AndroidEnvironment.report(to: core, activity: context.reference)
        if previous == nil { AndroidPersistence.restore(into: core, context: context.reference) }
        renderer.show(connectingScene: previous == nil)
        AndroidDoorbell.install { AndroidRenderer.shared?.runtime.pump.turn() }
        return renderer
    }

    /// Hears every layout pass and scroll of the root's window: where a view stands may have moved.
    /// Design: docs/design/platforms/android/layout.md#where-a-view-stands
    private func watchLayout() {
        let listener = Java.new(JavaAPI.listener, JavaAPI.newListener, .long(0))
        let observer = Java.callObject(root.reference, JavaAPI.getViewTreeObserver)!
        withExtendedLifetime(listener) {
            Java.call(observer, JavaAPI.addOnGlobalLayoutListener, .object(listener.reference))
            Java.call(observer, JavaAPI.addOnScrollChangedListener, .object(listener.reference))
        }
        Java.release(local: observer)
    }

    /// The pages the window presents over its page.
    private lazy var modals = AndroidModals(root: root, reducesMotion: reducesMotion)

    /// The acts the application calls, performed and answered.
    private lazy var acts = AndroidActPerformer(core: runtime.core, context: context, root: root)

    /// An act waiting under a ticket was answered - a dialog, a script: its caller resumes, and what that
    /// writes runs.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        acts.answered(ticket: ticket, accepted: accepted, words: words)
        runtime.pump.turn()
    }

    /// Renders the application whole, connecting its scene first where no activity has shown it.
    func show(connectingScene: Bool = true) {
        if connectingScene { runtime.core.connectScene() }
        runtime.pump.turn()
    }

    /// The activity's lifecycle moved: its one window stands activated in front of the user (onResume), off the
    /// screen once stopped (onStop), and neither between; the host layer settles what that means for the
    /// application, its scene and its window, each rendered before the next.
    /// Design: docs/design/platforms/android/runtime.md#the-activitys-lifecycle
    func setPhase(_ phase: ApplicationPhase) {
        guard let window = runtime.tree.root?.first(type: .window) else {
            runtime.core.setApplicationPhase(phase)
            return runtime.pump.turn()
        }
        runtime.windowStateChanged(window, minimized: phase == .background, activated: phase == .active)
    }

    /// The activity is finishing: its window hears it is going, then its scene.
    func destroying() {
        runtime.ending()
    }

    /// The activity's configuration changed - the display turned or resized: the core is told what stands now,
    /// and the window laid out again.
    /// The zone, the clock, the battery or the network changed.
    func environmentChanged() {
        runtime.environmentChanged { AndroidEnvironment.reportChanging(to: runtime.core, context: context.reference) }
    }

    func configured() {
        runtime.environmentChanged {
            AndroidEnvironment.report(to: runtime.core, activity: context.reference)
            Java.call(root.reference, JavaAPI.requestLayout)
        }
    }

    /// The safe area's top left in the window, in points: where the page's root stands.
    var safeAreaOrigin: Point {
        let window = Java.ints([0, 0])
        Java.call(root.reference, JavaAPI.getLocationInWindow, .object(window))
        var pixels: [Int32] = [0, 0]
        pixels.withUnsafeMutableBufferPointer { Java.jni.GetIntArrayRegion(Java.env, window, 0, 2, $0.baseAddress) }
        Java.release(local: window)
        return Point(x: Double(pixels[0]) / density, y: Double(pixels[1]) / density)
    }

    /// Names the activity after the first window.
    private func showTitle(of window: MountedElement) {
        let title = window.value(.title)?.string
        guard windowTitle != .some(title) else { return }

        windowTitle = .some(title)
        Java.frame {
            Java.callStatic(
                JavaAPI.environment, JavaAPI.setWindowTitle, .object(context.reference),
                .object(title.flatMap(Java.string)))
        }
    }

    /// Shows what the first window asks for: its arrangement of pages in the activity's root, the pages its modal
    /// stack presents over it, and its overlay over them all. The host layer tells the page the user sees and the
    /// window made.
    /// Design: docs/design/platforms/android/pages.md#the-windows-overlay
    private func showWindow() {
        guard let window = runtime.tree.root?.first(type: .window) else { return }
        showTitle(of: window)

        let changes = presentation.show(window, in: runtime.lifecycle)
        if let (_, arrangement) = changes.arrangement {
            Java.call(root.reference, JavaAPI.removeAllViews)
            shownOverlay = nil
            if let page = arrangement?.android.view {
                page.forgetPlace()
                Java.call(root.reference, JavaAPI.addView, .object(page.reference), .int(-1), .int(-1))
            }
        }
        let rose = changes.sheets.map { modals.present($0) } ?? false

        // The overlay lies over everything, lifted over a page that rose after it; it takes no touch beside what it
        // holds, which goes on to the page under it.
        let overlay = presentation.overlay?.android.view
        if overlay !== shownOverlay {
            if let leaving = shownOverlay { Java.call(root.reference, JavaAPI.removeView, .object(leaving.reference)) }
            if let overlay {
                overlay.forgetPlace()
                Java.call(root.reference, JavaAPI.addView, .object(overlay.reference), .int(-1), .int(-1))
            }
            shownOverlay = overlay
        } else if rose, let overlay {
            Java.call(overlay.reference, JavaAPI.bringToFront)
        }
    }

    /// The overlay's view the root holds now, let go of as the window stops showing it.
    private var shownOverlay: AndroidView?

    /// Goes the way back the window offers the user - a sidebar sliding over the page closing first, then the host
    /// layer's (`WindowPresentation.wayBack`); whether there was one.
    /// Design: docs/design/host/pages.md#the-way-back
    func goBack() -> Bool {
        if let close = (presentation.sheets.last ?? presentation.arrangement)?.android.drawerBack {
            close()
            return true
        }
        guard let way = systemWayBack else { return false }
        goBack(way)
        return true
    }

    /// The way back the system's back takes: the host layer's, and a stack's top page going where the page hides its
    /// bar but keeps its way back - Android's back is the system's, not the bar's.
    private var systemWayBack: WayBack? {
        if let way = presentation.wayBack { return way }
        guard let stack = (presentation.sheets.last ?? presentation.arrangement)?.visibleNavigationStack,
              stack.children.count > 1, stack.children.last?.value(.hasBackButton)?.bool != false
        else { return nil }
        return .pop(stack)
    }

    /// Goes `way` back in the first window.
    func goBack(_ way: WayBack) {
        guard let window = runtime.tree.root?.first(type: .window) else { return }
        runtime.goBack(way, in: window)
    }

    /// Tells the activity whether there is a way back, so the system's own back gesture knows whose it is.
    func refreshBack() {
        let handles = systemWayBack != nil
            || (presentation.sheets.last ?? presentation.arrangement)?.android.drawerBack != nil
        guard handles != handlesBack else { return }

        handlesBack = handles
        guard Java.jni.IsInstanceOf(Java.env, context.reference, JavaAPI.activity) != 0 else { return }
        Java.call(context.reference, JavaAPI.setHandlesBack, .bool(handles))
    }
}

extension AndroidRenderer: TurnPresenter {
    /// Shows what a render changed: the activity's title, the window's pages, its sheets and its overlay, and
    /// whether there is a way back.
    func presentRendered() {
        showWindow()
        refreshBack()
    }

    func perform(_ call: HostActCall) {
        acts.perform(call, in: runtime.tree)
    }
}

extension AndroidRenderer: FramePresenter {
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
