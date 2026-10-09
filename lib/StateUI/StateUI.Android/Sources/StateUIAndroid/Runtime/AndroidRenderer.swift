// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// The Android Views runtime: the mounted tree over Android views, the activity's window around it, and the turn.
/// Design: docs/design/platforms/android/runtime.md#the-android-views-runtime
@MainActor
final class AndroidRenderer {
    /// What the host says for whoever reads its log: logcat, or wherever a test listens. Written from JNI's load too,
    /// before any actor runs.
    nonisolated(unsafe) static var log = HostLog(host: "Android", output: AndroidStandardStreams.log)

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
        log: { AndroidRenderer.log.error($0) }, views: { AndroidView.liveCount })

    private let context: JavaObject

    /// The view the page is shown in: the activity's root.
    let root: JavaObject
    private let density: Double

    /// What the first window shows, by the host layer's rule: its arrangement of pages, its sheets, its overlays.
    private let presentation = WindowPresentation()

    /// The application's scenes as they stand, kept for its next start - one for the process, handed from each
    /// activity to the next.
    private(set) var scenes = SceneKeeper()

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
    /// An activity after the first takes over the scene the one before showed, rendered whole; where Back ended
    /// that scene, the scenes kept come back, as for the first activity.
    /// Design: docs/design/platforms/android/runtime.md#a-later-activity
    @discardableResult
    static func start(context: JavaObject, root: JavaObject, density: Double) -> AndroidRenderer {
        let previous = shared
        let sceneStands = previous?.runtime.tree.root?.children.contains { $0.type == .scene } == true
        previous?.runtime.tree.root?.leave()

        let renderer = AndroidRenderer(context: context, root: root, density: density)
        shared = renderer
        renderer.watchLayout()
        let core = renderer.runtime.core
        core.setRealization(
            AndroidRegistrations.registry.realization,
            unrealized: AndroidRealization.unmade)
        AndroidEnvironment.report(to: core, activity: context.reference)
        if previous == nil { AndroidPersistence.restore(into: core, context: context.reference) }
        if let previous { renderer.scenes = previous.scenes }
        renderer.show(restoringScenes: !sceneStands)
        AndroidDoorbell.install()
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

    /// Android's part of the acts every host performs, and the host layer's performer of them.
    private lazy var actToolkit = AndroidActToolkit(
        core: runtime.core, context: context, root: root, tree: { [unowned self] in runtime.tree },
        keepSceneValue: { [unowned self] in keepSceneValue($0) })
    /// Android's part of the files the user opens and saves, and of what the system launches.
    private(set) lazy var fileToolkit = AndroidFileToolkit(context: context)
    private lazy var acts = HostActPerformer(
        toolkit: actToolkit, files: fileToolkit, answers: runtime.core, tree: { [unowned self] in runtime.tree })

    /// An act waiting under a ticket was answered - a dialog, a script: its caller resumes, and what that
    /// writes runs.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        actToolkit.answered(ticket: ticket, accepted: accepted, words: words)
        runtime.pump.turn()
    }

    /// The document picker under `ticket` closed: its caller resumes with the documents chosen.
    func filesChosen(ticket: Int64, addresses: [String], names: [String], failure: String?) {
        fileToolkit.chose(ticket: ticket, addresses: addresses, names: names, failure: failure)
        runtime.pump.turn()
    }

    /// The document read under `ticket`: its caller resumes with its bytes.
    func fileRead(ticket: Int64, bytes: [UInt8], failure: String?) {
        fileToolkit.read(ticket: ticket, bytes: bytes, failure: failure)
        runtime.pump.turn()
    }

    /// What was launched under `ticket` was taken, or not: its caller resumes.
    func launched(ticket: Int64, taken: Bool) {
        fileToolkit.launched(ticket: ticket, taken: taken)
        runtime.pump.turn()
    }

    /// Renders the application whole: where no activity shows a scene, the scenes kept for this start come back
    /// first, else the window launch opens.
    /// Design: docs/design/host/runtime.md#kept-scenes
    func show(restoringScenes: Bool = true) {
        if restoringScenes { scenes.restore(AndroidPersistence.readScenes(context: context.reference), in: runtime) }
        runtime.pump.turn()
    }

    /// A scene keeps a value, kept with the scenes for the next start.
    func keepSceneValue(_ call: HostActCall) {
        if scenes.keep(call.arguments), let text = scenes.changed(root: runtime.tree.root) {
            AndroidPersistence.writeScenes(text, context: context.reference)
        }
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

    /// The activity is finishing - Back, or the application finished it: the user closed its window, which hears it
    /// is going, and its scene that the window closed.
    func destroying() {
        guard let window = runtime.tree.root?.first(type: .window) else { return }
        runtime.userClosed(window)
    }

    /// The zone, the clock, the battery or the network changed.
    func environmentChanged() {
        runtime.environmentChanged { AndroidEnvironment.reportChanging(to: runtime.core, context: context.reference) }
    }

    /// The activity's configuration changed - the display turned or resized: the core is told what stands now,
    /// and the window laid out again.
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

    /// The colour the activity's window was last painted in behind its pages; nil while it keeps its own.
    private var paintedBackground: Int32?

    /// Names the activity after the first window: the title its chrome shows, the visible page's that names it first.
    /// Paints the activity's window behind its pages as the window's element says, and gives it the theme's own back
    /// once it says none - a window never painted keeps whatever it shows.
    private func showBackground(_ background: HostValue?) {
        let argb = background.flatMap { HostBrush($0).firstColor }.flatMap(AndroidView.argb)
        guard argb != paintedBackground else { return }
        paintedBackground = argb
        Java.frame {
            Java.callStatic(
                JavaAPI.environment, JavaAPI.setWindowBackground, .object(context.reference), .int(argb ?? 0),
                .bool(argb != nil))
        }
    }

    private func showTitle(of window: MountedElement) {
        let title = WindowChrome(window: window, arrangement: presentation.arrangement).title
        guard windowTitle != .some(title) else { return }

        windowTitle = .some(title)
        Java.frame {
            Java.callStatic(
                JavaAPI.environment, JavaAPI.setWindowTitle, .object(context.reference),
                .object(title.flatMap(Java.string)))
        }
    }

    /// Shows what the first window asks for: its arrangement of pages in the activity's root, the pages its modal
    /// stack presents over it, and its overlays over them all. The host layer tells the page the user sees and the
    /// window made.
    /// Design: docs/design/platforms/android/pages.md#the-windows-overlays
    private func showWindow() {
        guard let window = runtime.tree.root?.first(type: .window) else { return }
        let changes = presentation.show(window, in: runtime.lifecycle)
        showTitle(of: window)
        if let traits = changes.traits { showBackground(traits.background.painted) }
        if let (_, arrangement) = changes.arrangement {
            Java.call(root.reference, JavaAPI.removeAllViews)
            shownOverlays = []
            if let page = arrangement?.android.view {
                page.forgetPlace()
                Java.call(root.reference, JavaAPI.addView, .object(page.reference), .int(-1), .int(-1))
            }
        }
        let rose = changes.sheets.map { modals.present($0) } ?? false

        // The overlays lie over everything, the first lowest, lifted over a page that rose after them; they take no
        // touch beside what they hold, which goes on to the page under them.
        let overlays = presentation.overlays.compactMap(\.android.view)
        if !overlays.elementsEqual(shownOverlays, by: ===) {
            for leaving in shownOverlays { Java.call(root.reference, JavaAPI.removeView, .object(leaving.reference)) }
            for overlay in overlays {
                overlay.forgetPlace()
                Java.call(root.reference, JavaAPI.addView, .object(overlay.reference), .int(-1), .int(-1))
            }
            shownOverlays = overlays
        } else if rose {
            for overlay in overlays { Java.call(overlay.reference, JavaAPI.bringToFront) }
        }
    }

    /// The overlays' views the root holds now, the first lowest, let go of as the window stops showing them.
    private var shownOverlays: [AndroidView] = []

    /// Shows the first window's chrome again where a frame moved what it shows (`WindowChrome.follows`): its title,
    /// the bar and tab row of every arrangement it and its sheets show, and whether there is a way back.
    private func showChrome() {
        guard let window = runtime.tree.root?.first(type: .window) else { return }
        showTitle(of: window)
        presentation.arrangement?.android.refreshBars()
        presentation.sheets.forEach { $0.android.refreshBars() }
        refreshBack()
    }

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
              stack.children.count > 1, stack.children.last?.value(.showsBackButton)?.bool != false
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
    /// Shows what a render changed: the activity's title, the window's pages, its sheets and its overlays, and
    /// whether there is a way back.
    func presentRendered() {
        showWindow()
        refreshBack()
        if let text = scenes.changed(root: runtime.tree.root) {
            AndroidPersistence.writeScenes(text, context: context.reference)
        }
    }

    func perform(_ call: HostActCall) {
        acts.perform(call)
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
        if runtime.tree.present(states: states, properties: properties).windowChrome { showChrome() }
    }

    func renderIfNeeded() {
        if runtime.core.needsRender { runtime.pump.turn() }
    }
}
