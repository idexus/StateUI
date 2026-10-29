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

    /// The window element the activity shows - a question and a file dialog stand over it - else the tree's root.
    static var window: MountedElement? {
        shared?.runtime.tree.root.flatMap { $0.first(type: .window) ?? $0 }
    }

    /// The window a window's act asks in: the one the activity shows, where the act names it or none; nil for
    /// another.
    static func window(asked element: MountedElement?) -> MountedElement? {
        guard let window, element == nil || element?.enclosing(type: .window) === window else { return nil }
        return window
    }

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
    private(set) var density: Double

    /// What the first window shows, by the host layer's rule: its arrangement of pages, its sheets, its overlays.
    private let presentation = WindowPresentation()

    /// The words the status bar shows over the window's top: those of the bar the window's visible stack paints
    /// under it - light on a dark band - else the theme's.
    /// Design: docs/design/platforms/android/pages.md#the-bar
    private(set) var statusWords = AndroidBarView.Words.platform

    /// Gives the status bar the words of the bar under it - the window's visible stack's, where it shows one - as
    /// the window shows and as a bar is shown again.
    func showStatusWords() {
        let words = presentation.arrangement?.visibleNavigationStack.map { stack -> AndroidBarView.Words in
            guard stack.arrangedChildren.last?.showsTheStacksBar ?? true else { return .platform }
            return AndroidBarView.Words(on: (stack.visiblePage?.barColors ?? stack.barColors).background)
        } ?? .platform
        guard words != statusWords else { return }
        statusWords = words
        Java.callStatic(JavaAPI.views, JavaAPI.statusWords, .object(context.reference), .int(words.rawValue))
    }

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
        runtime.presenter = self
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
        // The same root - a new density - is watched already.
        if previous.map({ Java.jni.IsSameObject(Java.env, $0.root.reference, root.reference) == 0 }) ?? true {
            renderer.watchLayout()
        }
        if let previous { renderer.scenes = previous.scenes }
        renderer.start(restoringKept: previous == nil, restoringScenes: !sceneStands, turns: AndroidDoorbell.install)
        AndroidMainQueue.watch()
        if previous != nil {
            // The activity before left its dialogs unanswered: the question showing is asked again in this one.
            actToolkit.forgetDialogs()
            acts.askAgain()
        }
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
        followDrawing()
    }

    /// Follows the drawing of the root's window: before each frame is drawn, what reads a frame says where it stands,
    /// and what that changes is laid out again in the same pass (`StateUIDrawing`).
    /// Design: docs/design/host/runtime.md#where-a-view-stands
    func followDrawing() {
        Java.callStatic(JavaAPI.drawing, JavaAPI.followDrawing, .object(root.reference))
    }

    /// The pages the window presents over its page.
    private lazy var modals = AndroidModals(root: root, reducesMotion: reducesMotion)
    var modalsForTesting: AndroidModals { modals }

    /// Android's part of the acts every host performs, the files the user opens and saves and what the system
    /// launches, and the host layer's performer of them - the process's: a question, a document chosen or a script
    /// outlives the activity it began in, which Android may make again meanwhile, and acts in the one standing now.
    /// Design: docs/design/platforms/android/runtime.md#acts
    private static let actToolkit = AndroidActToolkit(core: CoreLink())
    private static let files = AndroidFileToolkit()
    private static let network = AndroidNetwork()
    private static let acts = HostActPerformer(
        toolkit: actToolkit, files: files, network: network, answers: CoreLink(),
        tree: { AndroidRenderer.shared?.runtime.tree })
    var actToolkit: AndroidActToolkit { Self.actToolkit }
    var fileToolkit: AndroidFileToolkit { Self.files }
    private var acts: HostActPerformer { Self.acts }

    /// An act waiting under a ticket was answered - a dialog, a script: its caller resumes in a job of its own.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        actToolkit.answered(ticket: ticket, accepted: accepted, words: words)
    }

    /// The choice of actions waiting under a ticket was answered by the action at `place`.
    func actionChosen(ticket: Int64, place: Int) {
        actToolkit.actionChosen(ticket: ticket, place: place)
    }

    /// The tickets of the scripts waiting for their answer, oldest first.
    var waitingScripts: [Int64] {
        actToolkit.waitingScripts
    }

    /// The document picker under `ticket` closed: its caller resumes with the documents chosen.
    func filesChosen(ticket: Int64, addresses: [String], names: [String], failure: String?) {
        fileToolkit.chose(ticket: ticket, addresses: addresses, names: names, failure: failure)
    }

    /// The document read under `ticket`: its caller resumes with its bytes.
    func fileRead(ticket: Int64, bytes: [UInt8], failure: String?) {
        fileToolkit.read(ticket: ticket, bytes: bytes, failure: failure)
    }

    /// The request under `ticket` was answered, or failed: its caller resumes.
    func requestAnswered(ticket: Int64, status: Int, headers: [String], body: [UInt8], failure: String?) {
        Self.network.answered(ticket: ticket, status: status, headers: headers, body: body, failure: failure)
    }

    /// What was launched under `ticket` was taken, or not: its caller resumes.
    func launched(ticket: Int64, taken: Bool) {
        fileToolkit.launched(ticket: ticket, taken: taken)
    }

    /// Starts the runtime in the host layer's order, told what the host stands on and, `restoringKept`, what it
    /// kept; the application renders whole - where no activity shows a scene, the scenes kept for this start come
    /// back first, else the window launch opens - and `turns` posts the turns after it.
    /// Design: docs/design/host/runtime.md#starting
    func start(restoringKept: Bool = false, restoringScenes: Bool = true, turns: () -> Void = {}) {
        runtime.start(
            realizing: AndroidRegistrations.registry.realization, unrealized: AndroidRealization.unmade,
            register: AndroidRealization.register,
            complainingTo: AndroidRenderer.log,
            environment: { AndroidEnvironment.report(to: runtime.core, activity: context.reference) },
            kept: { if restoringKept { AndroidPersistence.readKept(into: runtime.core, context: context.reference) } },
            windows: {
                if restoringScenes { scenes.restore(AndroidPersistence.readScenes(context: context.reference), in: runtime) }
                runtime.pump.turn()
            },
            turns: turns)
    }

    /// A scene keeps a value, kept with the scenes for the next start.
    func keepSceneValue(_ call: HostActCall) {
        if scenes.keep(call.arguments), let text = scenes.changed(root: runtime.tree.root) {
            AndroidPersistence.writeScenes(text, context: context.reference)
        }
    }

    /// The activity's lifecycle moved: its one window stands activated in front of the user (onResume), off the
    /// screen once stopped (onStop), and neither between; the host layer settles what that means for the
    /// application, its scene and its window, each rendered before the next. An activity paused and stopped only
    /// to be made again for a new configuration moves nothing: the next resumes at once.
    /// Design: docs/design/platforms/android/runtime.md#the-activitys-lifecycle
    func setPhase(_ phase: ApplicationPhase, beingMadeAgain: Bool = false) {
        guard !beingMadeAgain else { return }
        actToolkit.phaseTurned(phase)
        guard let window = runtime.tree.root?.first(type: .window) else {
            runtime.core.setApplicationPhase(phase)
            return runtime.pump.turn()
        }
        runtime.windowStateChanged(window, minimized: phase == .background, activated: phase == .active)
    }

    /// The activity is finishing - Back, or the application finished it: the user closed its window, which hears it
    /// is going, and its scene that the window closed; then what waited over it is answered as dismissed, once the
    /// window went, as every host answers what stood over a window gone.
    /// Design: docs/design/host/runtime.md#questions-for-the-user
    func destroying() {
        if let window = runtime.tree.root?.first(type: .window) { runtime.userClosed(window) }
        Self.endActs()
    }

    /// Answers every question and picker still waiting as dismissed: the activity they were asked over finished,
    /// and the next activity of the process asks afresh.
    static func endActs() {
        acts.dismissAll()
        actToolkit.forgetDialogs()
        files.forgetDialogs()
    }

    /// The zone, the clock, the battery, the network or an accessibility setting changed.
    func environmentChanged() {
        runtime.environmentChanged { AndroidEnvironment.reportChanging(to: runtime.core, context: context.reference) }
    }

    /// The activity's configuration changed - the display turned or resized: the core is told what stands now,
    /// and the window laid out again. Pixels a point changing - the display's size, another screen - make the window
    /// again at the new density, as an activity Android makes again does.
    /// Design: docs/design/platforms/android/runtime.md#a-later-activity
    func configured() {
        let density = AndroidEnvironment.density(of: context.reference)
        guard density == self.density else {
            AndroidRenderer.start(context: context, root: root, density: density)
            return
        }
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

    /// The color the activity's window was last painted in behind its pages; nil while it keeps its own.
    private var paintedBackground: Int32?

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

    /// Names the activity after the first window: the title its chrome shows, the visible page's that names it first.
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
        if let traits = changes.traits {
            showBackground(traits.background.painted)
            for page in window.pages { (page.native as? AndroidElement)?.paintBackground() }
            // The surfaces over the page stand on it too: the sheets, and the sidebars over the detail.
            modals.ground()
            for split in window.splitViews { (split.native as? AndroidElement)?.groundSidebar() }
        }
        if let (_, arrangement) = changes.arrangement {
            Java.call(root.reference, JavaAPI.removeAllViews)
            shownOverlays = []
            if let page = arrangement?.android.view {
                page.forgetPlace()
                Java.call(root.reference, JavaAPI.addView, .object(page.reference), .int(-1), .int(-1))
            }
        }
        let rose = changes.sheets.map { modals.present($0) } ?? false
        modals.standAtTheirSizes()
        standUnderTheWindowsInsets()
        showStatusWords()
        for page in window.pages { (page.native as? AndroidElement)?.showBottomBar() }

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

    /// What stands over the activity's root on each edge, in points: the system's bars and a cutout, and the keyboard
    /// at the bottom - Android draws the root edge to edge.
    /// Design: docs/design/platforms/android/pages.md#the-safe-area
    private(set) var windowInsets = Clearance.none

    /// Android told what stands over the root now, in pixels: every arrangement it shows stands under it again.
    func insetsChanged(left: Int32, top: Int32, right: Int32, bottom: Int32, keyboard: Int32) {
        let insets = Clearance(
            top: Double(top) / density, left: Double(left) / density,
            bottom: SafeAreaArithmetic.bottom(system: Double(bottom), keyboard: Double(keyboard)) / density,
            right: Double(right) / density)
        guard insets != windowInsets else { return }
        windowInsets = insets
        standUnderTheWindowsInsets()
    }

    /// Hands what stands over the root to every arrangement standing in it - the window's, a full sheet's page - and
    /// to the overlays.
    private func standUnderTheWindowsInsets() {
        (presentation.arrangement?.android.view as? AndroidLayoutView)?.roomInsets = windowInsets
        for overlay in presentation.overlays { (overlay.android.view as? AndroidLayoutView)?.roomInsets = windowInsets }
        modals.standUnder(windowInsets)
    }

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
              stack.children.count > 1, stack.arrangedChildren.last?.value(.showsBackButton)?.bool != false
        else { return nil }
        return .pop(stack)
    }

    /// A key going down or up before any view has it: down, sent to a view taking it (`KeyPresses`) - out from the
    /// view holding the keyboard, else from the page in front - and kept, so its going up is taken too. Whether one
    /// took it.
    func taken(down: Bool, code: Int32, character: Int32, meta: Int32) -> Bool {
        guard down else { return takenKeys.remove(code) != nil }
        guard let pressed = AndroidKeys.shortcut(code: code, character: character, meta: meta),
              let window = runtime.tree.root?.first(type: .window)
        else { return false }
        let holder = KeyPresses.holder(under: window) { held in
            (held.native as? AndroidElement)?.view.map { Java.callBool($0.reference, JavaAPI.hasFocus) } ?? false
        }
        guard KeyPresses.press(
            pressed.key, modifiers: pressed.modifiers, focused: holder, front: presentation.frontPage, in: runtime)
        else { return false }
        takenKeys.insert(code)
        return true
    }

    /// The keys a view took as they went down, whose going up is taken with them.
    private var takenKeys: Set<Int32> = []

    /// A key pressed that no view took, reaching the element of the window stating it as a shortcut; whether one
    /// took it.
    func pressed(code: Int32, character: Int32, meta: Int32) -> Bool {
        guard let shortcut = AndroidKeys.shortcut(code: code, character: character, meta: meta),
              let window = runtime.tree.root?.first(type: .window)
        else { return false }
        return KeyboardShortcuts.press(shortcut, under: window, in: runtime)
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

extension AndroidRenderer: HostPresenter {
    /// Shows what a render changed: the activity's title, the window's pages, its sheets and its overlays, and
    /// whether there is a way back - where it changed what they are made of; the scenes it keeps, always.
    func presentRendered(touchedChrome: Bool) {
        if touchedChrome {
            showWindow()
            refreshBack()
        }
        for popover in runtime.tree.takeWaitingPopovers() { popover.android.configurePopover() }
        if let text = scenes.changed(root: runtime.tree.root) {
            AndroidPersistence.writeScenes(text, context: context.reference)
        }
    }

    func presentFrame(movedChrome: Bool) {
        if movedChrome { showChrome() }
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
