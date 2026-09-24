// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
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

    let core = CoreLink()
    let intake = PatchIntake()
    let animator = Animator()
    let stateChannels: StateChannels
    let describedMotion: DescribedMotion
    let layoutMotion: LayoutMotion
    let frameClock: AndroidFrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    let reducesMotion: () -> Bool
    let displayCycle: DisplayCycle

    /// The mounted tree; each element's Android half is an `AndroidElement`.
    private(set) lazy var tree = MountedTree(
        core: core,
        intake: intake,
        stateChannels: stateChannels,
        describedMotion: describedMotion,
        layoutMotion: layoutMotion,
        now: frameClock.now,
        reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in AndroidElement(element, host: self) })

    private let context: JavaObject

    /// The view the page is shown in: the activity's root.
    let root: JavaObject
    private let density: Double

    /// Whether a turn is running; a turn asked for inside it runs once it ends.
    private var pumping = false
    private var pumpAgain = false

    /// Events raised while a patch applied, inside a user's transaction, or a page's phase, in order.
    private var queuedEvents: [QueuedEvent] = []

    /// An event waiting for its turn; a page's phase is rendered before the event after it runs.
    private struct QueuedEvent {
        let handler: Int32
        let payload: [HostValue]
        var isPhase = false
    }

    /// The arrangement of pages the root shows, held by its mounted element, which owns its Android half; and
    /// whether the activity was last told there is a way back.
    private var shownArrangementElement: MountedElement?
    private var shownArrangement: AndroidElement? { shownArrangementElement?.android }
    private var handlesBack = false

    /// What the window lays over everything it shows - the inspector docked in it - held as the arrangement is.
    private var shownOverlayElement: MountedElement?

    /// The window told it was made, and whether the activity stands stopped.
    private weak var createdWindow: MountedElement?
    private var stopped = false

    /// The title the activity was last given, as the first window says it; none before any window says.
    private(set) var windowTitle: String??

    /// How deep the user's transactions stand; their events wait for the outermost to end.
    private var transactionDepth = 0

    /// The scrollers moving or with something to say, each given the display's frames until it has said it all.
    private var scrollers: [Int64: WeakScroller] = [:]

    /// The elements whose frame the tree reads, and whether views may have moved since they last said.
    private var frameReaders: [ObjectIdentifier: WeakElement] = [:]
    private var framesMoved = false

    /// A scroller the renderer gives frames to, and an element it follows, neither kept.
    private struct WeakScroller {
        weak var view: AndroidScrollView?
    }

    private struct WeakElement {
        weak var element: AndroidElement?
    }

    /// A runtime showing its page in `root`, on the display's clock or on `clock`,
    /// with the motion the user's settings allow or as `reducesMotion` says.
    init(
        context: JavaObject, root: JavaObject, density: Double,
        clock: (() -> Double)? = nil, reducesMotion: @escaping () -> Bool = { AndroidRenderer.animationsRemoved() }
    ) {
        self.context = context
        self.root = root
        self.density = density
        let frameClock = clock.map { AndroidFrameClock(now: $0) } ?? AndroidFrameClock()
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
        previous?.tree.root?.leave()

        let renderer = AndroidRenderer(context: context, root: root, density: density)
        shared = renderer
        renderer.watchLayout()
        AndroidEnvironment.report(to: renderer.core, activity: context.reference)
        if previous == nil { AndroidPersistence.restore(into: renderer.core, context: context.reference) }
        renderer.show(connectingScene: previous == nil)
        AndroidDoorbell.install { AndroidRenderer.shared?.pump() }
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
    private lazy var acts = AndroidActPerformer(core: core, context: context, root: root)

    /// An act waiting under a ticket was answered - a dialog, a script: its caller resumes, and what that
    /// writes runs.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        acts.answered(ticket: ticket, accepted: accepted, words: words)
        pump()
    }

    /// Renders the application whole, connecting its scene first where no activity has shown it.
    func show(connectingScene: Bool = true) {
        if connectingScene { core.connectScene() }
        pump()
    }

    /// Reports the application's phase as the activity's lifecycle moves it, then the scene's and its window's,
    /// each rendered before the next.
    /// Design: docs/design/platforms/android/runtime.md#the-activitys-lifecycle
    func setPhase(_ phase: ApplicationPhase) {
        core.setApplicationPhase(phase)
        pump()

        let resumes = stopped && phase != .background
        stopped = phase == .background
        if resumes, let handler = tree.root?.first(type: .window)?.handler(.resumed) { dispatch(handler) }

        let event: Event = switch phase {
        case .active: .activated
        case .inactive: .deactivated
        default: .stopped
        }
        for element in [tree.root?.first(type: .scene), tree.root?.first(type: .window)] {
            if let handler = element?.handler(event) { dispatch(handler) }
        }
    }

    /// The activity is finishing: its window hears it is going, then its scene.
    func destroying() {
        for type in [NodeType.window, .scene] {
            if let handler = tree.root?.first(type: type)?.handler(.destroying) { dispatch(handler) }
        }
    }

    /// The activity's configuration changed - the display turned or resized: the core is told what stands now,
    /// and the window laid out again.
    /// The zone, the clock, the battery or the network changed.
    func environmentChanged() {
        AndroidEnvironment.reportChanging(to: core, context: context.reference)
        tree.followTheLanguagesDirection()
        pump()
    }

    func configured() {
        AndroidEnvironment.report(to: core, activity: context.reference)
        tree.followTheLanguagesDirection()
        Java.call(root.reference, JavaAPI.requestLayout)
        pump()
    }

    /// Reports a native event and runs its handler, then a turn; one raised while a patch applies, or inside a
    /// user's transaction, waits for it.
    func dispatch(_ handler: Int32, payload: [HostValue] = []) {
        guard !intake.isApplying, transactionDepth == 0 else {
            queuedEvents.append(QueuedEvent(handler: handler, payload: payload))
            return
        }

        _ = core.dispatch(handler, payload: payload)
        pump()
    }

    /// Runs `body` as one of the user's transactions: the events it raises run in order once it ends,
    /// and one turn then renders everything it changed.
    func performUserTransaction(_ body: () -> Void) {
        transactionDepth += 1
        body()
        transactionDepth -= 1
        guard transactionDepth == 0, !intake.isApplying else { return }

        deliverQueued()
        pump()
    }

    /// The number a gesture channel's state stands at; nil for no such state.
    func standingGestureValue(state: Int32) -> Double? {
        core.gestureValue(state: state)
    }

    /// Moves a gesture channel's state to `value`, and draws what that moves; whether it moved.
    @discardableResult
    func takeGestureValue(_ value: Double, state: Int32) -> Bool {
        guard core.moveGestureValue(value, state: state) else { return false }
        displayCycle.drain(now: frameClock.now())
        return true
    }

    /// Queues a page's phase: it runs in its turn, and is rendered before anything after it.
    /// Design: docs/design/platforms/android/pages.md#a-pages-phases
    func enqueuePhase(_ handler: Int32) {
        queuedEvents.append(QueuedEvent(handler: handler, payload: [], isPhase: true))
    }

    /// Runs the queued events in order, stopping after a phase so it is rendered first; whether any ran.
    @discardableResult
    private func deliverQueued() -> Bool {
        guard !queuedEvents.isEmpty, !intake.isApplying, transactionDepth == 0 else { return false }

        while !queuedEvents.isEmpty {
            let event = queuedEvents.removeFirst()
            _ = core.dispatch(event.handler, payload: event.payload)
            if event.isPhase { break }
        }
        return true
    }

    /// Keeps the display's frames coming for `scroller` until it stands and has said everything.
    func requestFrames(for scroller: AndroidScrollView) {
        scrollers[scroller.number] = WeakScroller(view: scroller)
        displayCycle.hold()
    }

    /// Follows where `element` stands while the tree reads it, and lets it go once nothing does.
    func follow(_ element: AndroidElement, readsFrame: Bool) {
        let key = ObjectIdentifier(element)
        guard readsFrame != (frameReaders[key] != nil) else { return }

        frameReaders[key] = readsFrame ? WeakElement(element: element) : nil
        if readsFrame { laidOut() }
    }

    /// Android laid the window's views out, or scrolled them: whoever reads a frame says it on the next frame.
    func laidOut() {
        guard !frameReaders.isEmpty else { return }

        framesMoved = true
        displayCycle.hold()
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

    /// One turn: the jobs a resumed handler left, a pending cycle, a render when the core needs one, then the acts.
    /// Design: docs/design/host/runtime.md#one-turn
    func pump() {
        guard !pumping else {
            pumpAgain = true
            return
        }

        pumping = true
        repeat {
            pumpAgain = false
            turn()
        } while pumpAgain
        pumping = false
    }

    private func turn() {
        _ = core.runJobs()

        if tree.root != nil, core.cyclesPending {
            displayCycle.drain(now: frameClock.now())
        }

        if tree.root == nil || core.needsRender {
            render()

            let created = tree.root?.takeCreatedHandlers() ?? []
            for handler in created {
                _ = core.dispatch(handler)
            }
            if !created.isEmpty {
                pumpAgain = true
                return
            }
        }

        // The acts land on the interface their handler changed, so a turn that ran handlers renders again first.
        if deliverQueued() {
            pumpAgain = true
            return
        }

        for call in core.takeActCalls() {
            acts.perform(call, in: tree)
        }
        refreshBack()
    }

    /// Applies the core's render; a drifted one is asked for whole, once.
    private func render() {
        let rendered = core.render(baseline: intake.baseline)

        if !intake.take(rendered.root, generation: rendered.generation, apply: {
            tree.apply($0, complete: rendered.complete)
        }) {
            AndroidLog.error("the interface drifted and is asked for whole: \(intake.lastDrift ?? "")")
            let complete = core.render(baseline: 0)
            intake.take(complete.root, generation: complete.generation, apply: {
                tree.apply($0, complete: complete.complete)
            })
        }

        displayCycle.presentStateChannels()
        showWindow()
        showPage()
    }

    /// Names the activity after the first window, and tells a window it was made, once, in its turn.
    private func showWindow() {
        guard let window = tree.root?.first(type: .window) else { return }

        let title = window.value(.title)?.string
        if windowTitle != .some(title) {
            windowTitle = .some(title)
            Java.frame {
                Java.callStatic(
                    JavaAPI.environment, JavaAPI.setWindowTitle, .object(context.reference),
                    .object(title.flatMap(Java.string)))
            }
        }
        if window !== createdWindow {
            createdWindow = window
            if let handler = window.handler(.created) { enqueuePhase(handler) }
        }
    }

    /// Shows the first window's arrangement of pages in the activity's root, its pages hearing that they show,
    /// the pages its modal stack presents over it, and its overlay over them all.
    /// Design: docs/design/platforms/android/pages.md#the-windows-overlay
    private func showPage() {
        let window = tree.root?.first(type: .window)
        let arrangement = window?.children.first { AndroidElement.pageTypes.contains($0.type) }
        if arrangement !== shownArrangementElement {
            shownArrangement?.setPagePresented(false, reason: .window)
            shownArrangementElement = arrangement
            shownOverlayElement = nil
            Java.call(root.reference, JavaAPI.removeAllViews)
            if let page = shownArrangement?.view {
                page.forgetPlace()
                Java.call(root.reference, JavaAPI.addView, .object(page.reference), .int(-1), .int(-1))
            }
            shownArrangement?.setPagePresented(true, reason: .window)
        }

        let rose = modals.present(
            window?.children.first { $0.type == .modalStack }?.children ?? [], over: shownArrangement)
        showOverlay(window?.children.first { $0.type == .overlay }, raised: rose)
    }

    /// Lays the window's overlay over the root's pages, lifted over a page that rose after it; it takes no touch
    /// beside what it holds, which goes on to the page under it.
    private func showOverlay(_ overlay: MountedElement?, raised: Bool) {
        guard overlay === shownOverlayElement else {
            if let leaving = shownOverlayElement?.android.view {
                Java.call(root.reference, JavaAPI.removeView, .object(leaving.reference))
            }
            shownOverlayElement = overlay
            if let view = overlay?.android.view {
                view.forgetPlace()
                Java.call(root.reference, JavaAPI.addView, .object(view.reference), .int(-1), .int(-1))
            }
            return
        }
        if raised, let view = overlay?.android.view { Java.call(view.reference, JavaAPI.bringToFront) }
    }

    /// Goes the way back the page in front offers - a presented page's own, else that page going down, else
    /// the arrangement's; whether there was one.
    /// Design: docs/design/platforms/android/pages.md#the-way-back
    func goBack() -> Bool {
        if let top = modals.top {
            if let wayBack = top.wayBack {
                wayBack()
            } else {
                modals.dismissTop(over: shownArrangement)
                let window = tree.root?.first(type: .window)
                if let handler = window?.handler(.modalPopped) {
                    dispatch(handler, payload: [.number(Double(modals.count))])
                }
            }
            return true
        }
        guard let wayBack = shownArrangement?.wayBack else { return false }

        wayBack()
        return true
    }

    /// Tells the activity whether there is a way back, so the system's own back gesture knows whose it is.
    func refreshBack() {
        let handles = modals.top != nil || shownArrangement?.wayBack != nil
        guard handles != handlesBack else { return }

        handlesBack = handles
        guard Java.jni.IsInstanceOf(Java.env, context.reference, JavaAPI.activity) != 0 else { return }
        Java.call(context.reference, JavaAPI.setHandlesBack, .bool(handles))
    }
}

extension AndroidRenderer: FramePresenter {
    var wantsFrames: Bool {
        framesMoved || scrollers.values.contains { $0.view?.wantsFrames == true }
    }

    /// Lets every moving scroller say what the frame saw it do, then whoever reads a frame say where it
    /// stands, as one user's transaction.
    func commitUserReports(now: Double) {
        guard !scrollers.isEmpty || framesMoved else { return }

        performUserTransaction {
            for (number, scroller) in scrollers {
                guard let view = scroller.view else {
                    scrollers[number] = nil
                    continue
                }
                view.frame(now: now)
                if !view.wantsFrames { scrollers[number] = nil }
            }

            if framesMoved {
                framesMoved = false
                for reader in frameReaders.values { reader.element?.reportFrame() }
            }
        }
    }

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        tree.present(states: states, properties: properties)
    }

    func renderIfNeeded() {
        if core.needsRender { pump() }
    }
}
