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

    /// The arrangement of pages the root shows, and whether the activity was last told there is a way back.
    private weak var shownArrangement: AndroidElement?
    private var handlesBack = false

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

        let event: Event = switch phase {
        case .active: .activated
        case .inactive: .deactivated
        default: .stopped
        }
        for element in [tree.root?.first(type: .scene), tree.root?.first(type: .window)] {
            if let handler = element?.handler(event) { dispatch(handler) }
        }
    }

    /// The activity's configuration changed - the display turned or resized: the core is told what stands now,
    /// and the window laid out again.
    func configured() {
        AndroidEnvironment.report(to: core, activity: context.reference)
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
            if let completion = call.completion {
                core.fail(completion, reason: "the Android Views host performs no act yet")
            }
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
        showPage()
    }

    /// Shows the first window's arrangement of pages in the activity's root, its pages hearing that they show.
    private func showPage() {
        let arrangement = tree.root?.first(type: .window)?.children
            .first { AndroidElement.pageTypes.contains($0.type) }?.android
        guard arrangement !== shownArrangement else { return }

        shownArrangement?.setPagePresented(false, reason: .window)
        shownArrangement = arrangement
        Java.call(root.reference, JavaAPI.removeAllViews)
        if let page = arrangement?.view {
            page.forgetPlace()
            Java.call(root.reference, JavaAPI.addView, .object(page.reference), .int(-1), .int(-1))
        }
        arrangement?.setPagePresented(true, reason: .window)
    }

    /// Goes the way back the arrangement shown offers; whether there was one.
    /// Design: docs/design/platforms/android/pages.md#the-way-back
    func goBack() -> Bool {
        guard let wayBack = shownArrangement?.wayBack else { return false }

        wayBack()
        return true
    }

    /// Tells the activity whether there is a way back, so the system's own back gesture knows whose it is.
    func refreshBack() {
        let handles = shownArrangement?.wayBack != nil
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
