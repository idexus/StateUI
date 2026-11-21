// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One element of the mounted tree: the runtime's live instance of a described node.
/// Design: docs/design/host/tree.md#the-mounted-tree
@_spi(Host) @MainActor public final class MountedElement {
    /// The element's key.
    public let id: ElementID

    /// The element's node type.
    public let type: NodeType

    /// The element's instance number, which its animations are filed under.
    public let mount: UInt64

    /// The element that holds this one.
    public private(set) weak var parent: MountedElement?

    /// The elements this one holds, in order - a grid's, a ZStack's and a motion layout's in the order they are
    /// drawn, by `zIndex`, ties in the order written.
    public private(set) var children: [MountedElement] = []

    /// What an arrangement of pages declares beside its pages - its actions, its menus, its title view - kept
    /// apart, so its children are its pages alone; nothing for any other element.
    /// Design: docs/design/host/tree.md#an-arrangements-slots
    public private(set) var slots: [MountedElement] = []

    /// Each child's place in the order the last arrangement wrote them - known before the children are made.
    private(set) var writingOrder: [ElementID: Int] = [:]

    /// The properties the patches described.
    public private(set) var properties: [Prop: HostValue] = [:]

    /// The semantic key a menu or entry composes by across page levels, separate from its scoped element id.
    public private(set) var menuKey: HostMenuKey?

    /// The properties bound to states, by property.
    public private(set) var driven: [Prop: HostStateBinding] = [:]

    /// The states whose journey this element follows with no property showing them: each a consumer of its channel.
    /// Design: docs/design/host/motion.md#state-channels
    public private(set) var followed: [HostStateBinding] = []

    /// The layout program the element runs: the host says it the room, and reads where its children stand.
    /// Design: docs/design/host/layout.md#a-layout-program
    public private(set) var layoutProgram: HostLayoutProgram?

    /// What the user's hand moves on the element: the numbers of states it holds, moves and lets go.
    /// Design: docs/design/host/interaction.md#the-hold
    public private(set) var interactionProgram: HostInteractionProgram?

    /// The handlers of the events the tree listens to, by event.
    public private(set) var events: [Event: Int32] = [:]

    /// How this element's children animate, as its patches said; nil while it says nothing.
    public private(set) var motion: HostLayoutMotion?

    /// Whether this page tree is shown, as its phases last told.
    public internal(set) var isPagePresented = false

    /// Whether a message making again what the tree showed made the element - a complete one after a drift, another
    /// root: it enters by no transition.
    public let isRemade: Bool

    /// Whether the element fades out on its way to being hidden, which it still stands shown for.
    public internal(set) var isFadingOut = false

    /// Whether this element was last told the focus stands in it.
    var reportedFocus = false

    /// Whether the pointer stands over the element's view, as its toolkit last told it.
    var pointerIsOver = false

    /// The frame report this element last said, which a report the same says again to nobody - but to a reader
    /// come since, which hears where the element stands once (`frameReportDue`).
    var reportedFrame: [Double] = []
    var reportedPresentation: [Double] = []
    /// Whether the corner of the layout's frame last said was worked out while a place traveled.
    var saidACornerWorkedOut = false
    var frameReportDue = false

    /// The room the toolkit last laid the element out in, and where it put it in what holds it; nil before it
    /// said.
    var laidOutRoom: (width: Double, height: Double)?
    var laidOutCorner: Point?

    /// Where the layout program last put the children, as the element presents them.
    private(set) var programPlaces: [HostPlacement] = []

    /// How the layout program's children are measured: the child the arithmetic names by its place among the views
    /// as written, measured by its native half - nought for a place no child stands at.
    private lazy var childMeasure: HostChildMeasure = { [weak self] place, width, height in
        guard let self, let child = children.first(where: { self.writingOrder[$0.id] == place }) else {
            return HostChildMeasured(size: .zero, firstBaseline: nil)
        }
        return child.native.measured(width: width, height: height)
    }

    /// Tells the layout program how its children are measured - and, told again, that one may measure otherwise.
    /// Design: docs/design/host/layout.md#a-layout-program
    func saysItsMeasure() {
        layoutProgram?.measuredBy(childMeasure)
    }

    /// The nearest element from this one up that runs a layout program hears its views may measure otherwise.
    func measuredAgainForItsLayout() {
        var each: MountedElement? = self
        while let element = each {
            if element.layoutProgram != nil { return element.saysItsMeasure() }
            each = element.parent
        }
    }

    /// What the element shows of its program's answers: the children's bodies on their way.
    private var programPresentation = ProgramPresentation()

    /// What the element keeps to ask its layout program in its own frame, and whether the layout stood at rest
    /// when it was last asked.
    var programAsking = ProgramAsking()
    var programRested = true

    /// What the user's hand does to the element's own presentation, and whether a child's changed since the
    /// element last stepped its program's places.
    /// Design: docs/design/host/interaction.md#a-views-own-press-and-drag
    var local = LocalPresentation()
    var childrenMovedLocally = false

    /// The view's own press as its effect is handed it, and where the hand took the view it holds by itself.
    var pressReading = PressReading()
    var localFollow = LocalFollow()
    var dragFrom = Point.zero
    var dragOrigin = Rect.zero

    /// The view's way out once the user threw it away, what its handlers are told when it is out, and how many
    /// of the runs they started have not ended yet.
    /// Design: docs/design/host/interaction.md#a-view-thrown-away
    var flight: PresentationOperation?
    var flownFrom: Rect?
    var dismissing: (way: SwipeDirection, speed: Point)?
    var awaitedDismissals = 0

    /// How far from its place a press caught the view on its way out; nil once a hand moved it or let it go.
    var caught: Point?

    /// Where the element stands in its life: active until it leaves the tree.
    /// Design: docs/design/host/tree.md#leaving
    public private(set) var lifecycle = ElementLifecycle.active

    /// The children kept as they leave, each drawn until its exit ends, and the order the element's views stand in
    /// with them - nil while it keeps none. Design: docs/design/host/tree.md#a-view-kept-as-it-leaves
    var keptExits: [MountedElement] = []
    var presentedOrder: [MountedElement]?

    /// How many of the numbers its exit moves are still on their way; whether an element leaving above it took
    /// its exit over.
    var exitsRunning = 0
    var isAbsorbed = false

    /// Where its layout had placed it as it left, and - for a view come back as the one of its id was leaving -
    /// how that one was drawn then. Design: docs/design/host/tree.md#the-same-view-coming-back
    var exitPlace: Rect?
    var returned: Returned?

    /// The id a view of the element's authored identity is known by as it comes back: the one its render said it
    /// returns as, else its own - a name is the same in every life.
    let returnID: ElementID

    /// Whether a view standing in the element may be thrown out of it: the room it leaves is this element's.
    private(set) var holdsDismissing = false

    /// A view standing in the element says a dismissal it did not, or says one no more. Kept out of the mount's
    /// own frame, which every level of the tree stacks.
    @inline(never)
    func dismissingChanged() {
        holdsDismissing = children.contains { $0.interactionProgram?.drag?.dismissal != nil }
    }

    /// The element's program came after `before`: where it says a dismissal it did not, or says one no more, what
    /// holds the element is told.
    @inline(never)
    private func dismissalDeclared(after before: HostInteractionProgram?) {
        if (before?.drag?.dismissal != nil) != (interactionProgram?.drag?.dismissal != nil) {
            parent?.dismissingChanged()
        }
    }

    /// Where the element last showed the child at `place` of its program's places; nil where it shows none there.
    func programPlace(at place: Int) -> HostPlacement? {
        programPlaces.indices.contains(place) ? programPlaces[place] : nil
    }

    /// Whether a child is still on its way to the place the program gave it.
    var programBodiesMove: Bool { programPresentation.moves }

    /// Takes what the layout program answers now, at `now`; whether that changed what the element presents.
    /// Design: docs/design/host/layout.md#bodies
    func takeProgramPlaces(at now: Double, reducesMotion: Bool) -> Bool {
        guard let program = layoutProgram else { return false }

        // A view is the body it says itself, else the layout's for every child - a spring answering a change where
        // the layout says none.
        let bodies = value(LayoutContract.layoutBodies.token).flatMap(LayoutBody.init(propValue:)) ?? .onChange()
        childrenMovedLocally = false
        let answer = askProgram(program) ?? program.answered()
        let placed = programPresentation.take(
            answer, change: programAsking.change, layoutBodies: bodies, locals: children.map(\.placedLocal),
            at: now, reducesMotion: reducesMotion)
        return presents(placed)
    }

    /// Steps the children on their way to `now`; whether that changed what the element presents.
    func stepProgramPlaces(to now: Double) -> Bool {
        guard layoutProgram != nil, programPresentation.moves || childrenMovedLocally else { return false }

        childrenMovedLocally = false
        let placed = programPresentation.step(to: now, locals: children.map(\.placedLocal))
        return presents(placed)
    }

    /// Where `child`, one of the views the program places, is shown and where the program puts it, while the two
    /// differ.
    func programTravel(of child: MountedElement) -> (standing: Rect, destination: Rect)? {
        guard layoutProgram != nil, let place = writingOrder[child.id] else { return nil }
        return programPresentation.travel(at: place)
    }

    private func presents(_ placed: [HostPlacement]) -> Bool {
        guard placed != programPlaces else { return false }
        programPlaces = placed
        return true
    }

    /// The width the program's own size was last asked in, and what it said; nil before any ask.
    private var saidSize: (width: Double?, size: LayoutSize?)?

    /// The size the layout program says for the layout itself in the width offered, for the host's view to answer
    /// when it is measured; nil where the program says none and the layout takes the room it is given.
    /// Design: docs/design/host/layout.md#a-motion-layout
    public private(set) lazy var programSize: @MainActor (_ width: Double?) -> LayoutSize? = { [weak self] width in
        guard let self else { return nil }
        let said = layoutProgram?.measure?(width, nil)
        saidSize = (width, said)
        return said
    }

    /// Has the toolkit measure the layout again where its program now says another size than it last answered.
    func measuredAgainWhereItsSizeMoved() {
        guard let asked = saidSize, layoutProgram?.measure?(asked.width, nil) != asked.size else { return }
        saidSize = nil
        native.invalidateMeasurements()
    }

    /// Where a split view last said its sidebar stands, and onto which state; nil before it said.
    var reportedOverlays: (binding: HostStateBinding, over: Bool)?

    /// A drag between views over the element's view, as the element tells it.
    var dropTarget = DropTarget()

    /// The hand over the element, where it is a layout a hand moves.
    var handReading = HandReading()

    /// What the hand said since the last frame, the moves between two frames as one, waiting for the next.
    var handOutbox: [HandReading.Report] = []

    /// Two fingers over the element, where it is a layout they move, and what they said since the last frame.
    var pinchReading = PinchReading()
    var pinchOutbox: [PinchReading.Report] = []

    /// A wheel turned as a pinch over the element, while one is under way.
    var wheelPinch = WheelPinch()

    /// A press on the view as a button takes it, while the view hears taps.
    var buttonPress = ButtonPress()

    /// Whether the hand over the layout took the presses in it, in the touch under way.
    var handTookPresses = false

    /// A press dragged with ⌥/Alt over the element, read as two fingers, while one is under way.
    var mirroredFingers = MirroredFingers()

    /// How far the pinch heard on the element has spread since it began - what it tells, as a pan tells its totals;
    /// nil while none is under way.
    var pinchFromStart: Double?

    /// How far the two fingers heard on the element have turned since they began, in degrees; nil while they are not.
    var rotationFromStart: Double?

    /// How far the pan heard on the element has come since it began, as it last told.
    var panFromStart = Point(x: 0, y: 0)

    /// Whether a pan heard on the element is under way: begun, and not yet ended or cancelled.
    var panUnderWay = false

    /// The runs of input taken away from the element while their platform's goes on: heard no more until each ends.
    /// Design: docs/design/host/interaction.md#a-hand-taken-away
    var takenAway: Set<HeardStream> = []

    /// How fast the pan, the pinch and the rotation heard on the element go (`SpeedReading`).
    var panSpeed = SpeedReading()
    var pinchSpeed = SpeedReading()
    var rotationSpeed = SpeedReading()

    /// The toolkit's half of the element.
    public private(set) var native: (any NativeElement)!

    /// Whether the last patch changed the element's children - one added, moved, taken away or changed.
    public private(set) var childrenChanged = false

    /// Whether the patch last applied asks the element to arrange its children again: a new arrangement, a child made
    /// anew or drawn by the element, a page's own values - its title on a tab - a child's place, size or drawing
    /// order changed; not a change inside a child that stands where it stood.
    /// Design: docs/design/host/tree.md#a-patch-arranges-what-moved
    public private(set) var childrenNeedArranging = false

    /// The one the host keeps for this element as a child another's view draws, once one was asked for.
    var keptChild: HostChild?

    private(set) weak var tree: MountedTree?
    private var wornStates: [Int32] = []
    private var presentedStates: [Int32] = []
    private var drivenValues: [Prop: HostStateValue] = [:]
    private var created = false
    private var described = false

    /// Whether this popover is on its way to a view made anew (`showsAnew`).
    var isMoving = false

    /// How many elements are alive: those the tree holds, and any a host still holds after the tree dropped it.
    /// Design: docs/design/host/conformance.md#nothing-left-behind
    public private(set) static var liveCount = 0

    init(_ patch: HostPatch, tree: MountedTree, parent: MountedElement?) {
        Self.liveCount += 1
        id = patch.id
        returnID = tree.returnsAs[patch.id] ?? patch.id
        type = patch.type
        menuKey = patch.menuKey
        self.tree = tree
        self.parent = parent
        isRemade = tree.remakes
        mount = tree.allocateMount()
        native = nil
        tree.mounted(self)
        madeOrLeftByRender()
        made = patch
        native = tree.makeNative(self)
        made = nil
        tree.tally?.made += 1
        apply(patch)
    }

    isolated deinit {
        Self.liveCount -= 1
    }

    /// The patch the element is made from while its native half is made - what a toolkit making another control of
    /// what the element holds reads (`ControlReports.made`); nil after.
    public private(set) var made: HostPatch?

    /// Applies a patch of this element. The tree is made and applied by recursion - an element, then its children -
    /// through this frame, kept small: the element's own work is done in steps that return before its children are.
    /// Design: docs/design/host/runtime.md#the-mounts-stack
    public func apply(_ patch: HostPatch) {
        guard let tree else { return }

        let applying = received(patch, tree: tree)
        if case .unchanged = patch.children {} else { willShowAnew() }
        childrenApplied(patch.children, tree: tree)
        settled(patch, applying, tree: tree)
        if childrenChanged { showsAnew() }
    }

    /// `patch`, of a complete message, as this element takes it: a property, a handler or a tie it does not name is
    /// one the element no longer has.
    /// Design: docs/design/host/patches.md#a-complete-message
    private func completed(_ patch: HostPatch) -> HostPatch {
        var whole = patch
        whole.clearedProperties = Set(patch.clearedProperties)
            .union(properties.keys.filter { patch.properties[$0] == nil }).sorted()
        if patch.events == nil, !events.isEmpty { whole.events = .replace([:]) }
        if patch.driven == nil, !driven.isEmpty { whole.driven = .replace([:]) }
        if patch.followed == nil, !followed.isEmpty { whole.followed = .replace([]) }
        if patch.layout == nil, layoutProgram != nil { whole.layout = .clear }
        if patch.interaction == nil, interactionProgram != nil { whole.interaction = .clear }
        return whole
    }

    /// What applying a patch carries from before the children to after them: when a scene began, the pages shown,
    /// the properties that changed and the values they stood at.
    private final class Applying {
        let sceneBegan: ContinuousClock.Instant?
        let previouslyShown: [MountedElement]
        let changed: Set<Prop>
        let received: Set<Prop>
        let standing: [Prop: HostValue]
        let untouched: Bool

        init(
            sceneBegan: ContinuousClock.Instant?, previouslyShown: [MountedElement], changed: Set<Prop>,
            received: Set<Prop>, standing: [Prop: HostValue], untouched: Bool
        ) {
            self.sceneBegan = sceneBegan
            self.previouslyShown = previouslyShown
            self.changed = changed
            self.received = received
            self.standing = standing
            self.untouched = untouched
        }
    }

    /// The patch's own values taken: its properties, events, driven states and motion, before its children.
    @inline(never)
    private func received(_ patch: HostPatch, tree: MountedTree) -> Applying {
        // Design: docs/design/host/runtime.md#the-mounts-stack
        let patch = tree.appliesCompleteMessage ? completed(patch) : patch
        if let key = patch.menuKey { menuKey = key }
        let sceneBegan: ContinuousClock.Instant? = tree.tally != nil && patch.type == .scene ? .now : nil
        tree.tally?.nodes += 1

        let previouslyShown = isPagePresented ? shownChildren : []
        let heardPull = hearsPull
        let readFrameBefore = frameReaders
        // A complete message names what stands as well as what changed: only what it names otherwise is a change.
        // Design: docs/design/host/patches.md#a-complete-message
        let complete = tree.appliesCompleteMessage
        var changed = Set(patch.clearedProperties)
        changed.formUnion(patch.properties.keys.filter { !complete || properties[$0] != patch.properties[$0] })
        if case .replace(let replacement) = patch.driven {
            let named = Set(driven.keys).union(replacement.keys)
            changed.formUnion(named.filter { !complete || driven[$0] != replacement[$0] })
        }

        // Nothing of an element being made runs to be cut short: it receives what it animates and what a state drives,
        // whose channel its first reading opens.
        var bound: Set<Prop> = []
        if case .replace(let driven) = patch.driven { bound = Set(driven.keys) }
        let received = described ? changed : changed.filter { patch.transitions[$0] != nil || bound.contains($0) }
        let standing = Dictionary(uniqueKeysWithValues: received.compactMap { property in
            standingValue(property, target: patch.properties[property]).map { (property, $0) }
        })

        for property in patch.clearedProperties {
            properties[property] = nil
        }

        for (property, value) in patch.properties {
            properties[property] = value
        }

        var eventsReplaced = false
        if case .replace(let events) = patch.events {
            self.events = events
            eventsReplaced = true
        }

        if case .replace(let driven) = patch.driven {
            self.driven = driven
            drivenValues = drivenValues.filter { driven[$0.key] != nil }
            let presented = driven.values.filter { $0.mode != .in }.map(\.state).sorted()
            if presented != presentedStates {
                tree.presents(self, presented, before: presentedStates)
                presentedStates = presented
            }
        }
        if case .replace(let followed) = patch.followed { self.followed = followed }
        switch patch.layout {
        case .replace(let program)?:
            let stood = layoutProgram?.slot == program.slot
            if !stood {
                if let before = layoutProgram { tree.layoutLeft(before.slot) }
                tree.layoutStands(program.slot, on: self)
            }
            layoutProgram = program
            // The room the toolkit laid it out in stands: a program that came since is told it; a layout come
            // since, how its children are measured; and its own size, said otherwise, is measured again.
            if !stood { saysItsMeasure() }
            if let room = laidOutRoom { program.layOut(room.width, room.height) }
            measuredAgainWhereItsSizeMoved()
        case .clear?:
            if let before = layoutProgram { tree.layoutLeft(before.slot) }
            layoutProgram = nil
            programPlaces = []
            programPresentation = ProgramPresentation()
        case nil:
            break
        }
        if let update = patch.interaction {
            let before = interactionProgram
            if case .replace(let program) = update { interactionProgram = program } else { interactionProgram = nil }
            tree.interactionChanged(self, before)
            localInteractionChanged(in: tree)
            dismissalDeclared(after: before)
        }
        wear(driven)
        // A journey followed with no property has no view to read it: its channel opens here.
        if patch.followed != nil {
            for binding in followed {
                if let carried = tree.core.value(for: binding) { _ = tree.presentedValue(for: binding, from: carried) }
            }
        }
        // A reader of where the element stands come since hears the standing report (MountedElement+Frames.swift).
        if frameReaders != readFrameBefore { frameReportDue = frameReaders != nil }

        for (property, binding) in driven where binding.mode != .in {
            drivenValues[property] = tree.core.value(for: binding)
        }
        // What hears the pull changed: the offer its view is given follows (`offeredRefresh`).
        if hearsPull != heardPull { changed.insert(.isRefreshEnabled) }

        if let motion = patch.motion {
            self.motion = motion
            // The application says its motion once; every layout that says none animates under it.
            if type == .application { tree.layoutMotion.applicationMotion = motion.motion }
        } else if tree.appliesCompleteMessage {
            // A complete message that says no motion says the inherited one.
            self.motion = nil
        }

        if case .unchanged = patch.children { childrenChanged = false } else { childrenChanged = true }
        if described, !changed.isEmpty || eventsReplaced { changedByRender(changed) }

        // A child a new arrangement names for its order alone: nothing of it changed.
        let untouched = described && changed.isEmpty && !eventsReplaced && patch.motion == nil && !childrenChanged
        return Applying(
            sceneBegan: sceneBegan, previouslyShown: previouslyShown, changed: changed, received: received,
            standing: standing, untouched: untouched)
    }

    /// The children the patch arranges or changes, made or applied.
    private func childrenApplied(_ children: HostChildrenUpdate, tree: MountedTree) {
        switch children {
        case .unchanged:
            childrenNeedArranging = false

        case .arranged(let childPatches):
            writingOrder = Dictionary(childPatches.enumerated().map { ($1.id, $0) }) { first, _ in first }
            arrange(childPatches, tree: tree)
            childrenNeedArranging = true
            // Other children stand at the places a layout program measures by.
            measuredAgainForItsLayout()

        case .changed(let childPatches):
            for childPatch in childPatches {
                applied(childPatch, tree: tree)
            }
            childrenNeedArranging = childPatches.contains(where: asksArranging)
            // A child that may measure otherwise is measured again by the layout program placing it.
            if childrenNeedArranging { measuredAgainForItsLayout() }
        }
    }

    /// Whether `childPatch` asks this element to arrange its children again (`childrenNeedArranging`).
    private func asksArranging(_ childPatch: HostPatch) -> Bool {
        let ownValues = !childPatch.properties.isEmpty || !childPatch.clearedProperties.isEmpty
        if childPatch.replace || childPatch.driven != nil || childPatch.motion != nil
            || NodeType.pageTypes.contains(childPatch.type) && ownValues {
            return true
        }
        let child = children.first { $0.id == childPatch.id } ?? slots.first { $0.id == childPatch.id }
        guard let child, child.native.presentsView else { return true }
        // What its measure reads may size it anew - its words - as its place, size and drawing order move it.
        return childPatch.properties.keys.contains { !Self.unmeasuredProperties.contains($0) }
            || childPatch.clearedProperties.contains { !Self.unmeasuredProperties.contains($0) }
    }

    /// A child the patch names among those it has, applied - or made again where it is replaced.
    private func applied(_ childPatch: HostPatch, tree: MountedTree) {
        // A new child arrives only in an arranged list; a sparse list naming a stranger drifted.
        let isSlot = holdsSlotsApart && NodeType.slotTypes.contains(childPatch.type)
        guard let index = (isSlot ? slots : children).firstIndex(where: { $0.id == childPatch.id }) else {
            tree.intake.drifted("a patch names child '\(childPatch.id)' that '\(id)' does not have")
            return
        }
        let child = isSlot ? slots[index] : children[index]

        if child.type == childPatch.type, !childPatch.replace {
            child.apply(childPatch)
        } else if childPatch.replace {
            let presented = presentedChildren
            child.leave()
            let anew = MountedElement(childPatch, tree: tree, parent: self)
            if isSlot { slots[index] = anew } else { children[index] = anew }
            orderPresented(after: presented)
            changedByRender([])
        } else {
            tree.intake.drifted(
                "a patch describes '\(childPatch.id)' as \(childPatch.type) where '\(id)' holds \(child.type)")
        }
    }

    /// The patch's changes told to the native half, its children in place: each property, the stacking, the
    /// enablement and the direction, the frames read and the pages presented.
    @inline(never)
    private func settled(_ patch: HostPatch, _ applying: Applying, tree: MountedTree) {
        let changed = applying.changed
        for property in applying.received.sorted() {
            let hasDrivenPresentation = driven[property].map { $0.mode != .in } ?? false
            tree.receiveProperty(
                mount: mount,
                property: property,
                standing: applying.standing[property],
                target: resolvedValue(property) ?? identity(of: property),
                motion: hasDrivenPresentation || !native.animates(property)
                    ? nil
                    : patch.transitions[property]?.motion)
        }

        if restack(), described { reorderedByRender() }
        if changed.contains(.isEnabled), described { enablementTurned() }
        if changed.contains(.layoutDirection) {
            directionTurned(arrangingItself: false)
        } else if !described {
            native.directionChanged()
        }
        // Made in a disabled branch, it presents an `isEnabled` it never wrote; a page made under an arrangement's
        // ground, a `background` it never wrote; untouched, it presents nothing.
        var presenting = changed
        if !described, parent?.isEffectivelyEnabled == false { presenting.insert(.isEnabled) }
        if presenting.contains(.isEnabled) { presenting.formUnion(followingEnablement) }
        if !described, type == .page, value(.background) == nil, pageBackground != nil { presenting.insert(.background) }
        if !applying.untouched { native.applied(changed: presenting, wasDescribed: described) }
        described = true
        reconcilePresentation(from: applying.previouslyShown)

        if let sceneBegan = applying.sceneBegan {
            tree.tally?.scenes[patch.id, default: .zero] += ContinuousClock.now - sceneBegan
        }
    }

    /// Tells the element's handler of `event` as a phase, rendered in its turn before what comes after it.
    func tellPhase(_ event: Event) {
        guard let handler = handler(event) else { return }
        tree?.tellPhase(handler)
    }

    /// Reconciles a complete child arrangement by key - an arrangement of pages keeping its slots apart.
    private func arrange(_ patches: [HostPatch], tree: MountedTree) {
        let before = held
        let presented = presentedChildren
        let previous = Self.byId(before)
        var children: [MountedElement] = []
        var slots: [MountedElement] = []

        // The children first, then the pages kept apart, each in its order.
        for patch in patches where !isSlot(patch) {
            children.append(mounted(patch, continuing: previous[patch.id], tree: tree))
        }
        for patch in patches where isSlot(patch) {
            slots.append(mounted(patch, continuing: previous[patch.id], tree: tree))
        }
        self.children = children
        self.slots = slots
        dismissingChanged()
        takeBack(children, heldBefore: before)
        leave(before, presented: presented)
        if described { arrangedByRender(from: before) }
    }

    /// `elements` by their identity, the first of two that share one.
    @inline(never)
    private static func byId(_ elements: [MountedElement]) -> [ElementID: MountedElement] {
        Dictionary(elements.map { ($0.id, $0) }) { first, _ in first }
    }

    /// Whether `patch` describes a page this arrangement keeps apart.
    private func isSlot(_ patch: HostPatch) -> Bool {
        holdsSlotsApart && NodeType.slotTypes.contains(patch.type)
    }

    /// The child `patch` describes: `standing` applied where it is the same kind of element, made anew otherwise.
    private func mounted(_ patch: HostPatch, continuing standing: MountedElement?, tree: MountedTree) -> MountedElement {
        if let child = standing, child.type == patch.type, !patch.replace {
            child.parent = self
            child.apply(patch)
            return child
        }

        return MountedElement(patch, tree: tree, parent: self)
    }

    /// Whether this element is an arrangement of pages, whose children are its pages alone.
    private var holdsSlotsApart: Bool { Self.arrangements.contains(type) }

    /// Everything this element holds: its children, then its slots.
    var held: [MountedElement] { children + slots }

    /// The arrangements of pages, which keep their slots apart from their pages.
    private static let arrangements: Set<NodeType> = [.navigationStack, .tabView, .splitView]

    /// Puts a grid's or a ZStack's children in the order they are drawn: by `zIndex`, ties in the order
    /// written. Answers whether the order moved.
    /// Design: docs/design/host/layout.md#drawing-order
    @discardableResult
    private func restack() -> Bool {
        guard Self.layered.contains(type), children.count > 1 else { return false }

        let drawnBefore = { (lhs: MountedElement, rhs: MountedElement) -> Bool in
            let (lower, upper) = (lhs.zIndex, rhs.zIndex)
            if lower != upper { return lower < upper }
            return (self.writingOrder[lhs.id] ?? .max) < (self.writingOrder[rhs.id] ?? .max)
        }
        guard zip(children, children.dropFirst()).contains(where: { drawnBefore($1, $0) }) else { return false }
        children.sort(by: drawnBefore)
        return true
    }

    /// The direction this element lays out in turned: it and every element under it that inherits the direction
    /// hear it, and every layout among them arranges its children again, the element itself when its patch will not.
    /// Design: docs/design/host/layout.md#right-to-left
    func directionTurned(arrangingItself: Bool) {
        native.directionChanged()
        // A motion layout's run stands in its direction: presented again, it turns with it.
        if !ownPlacementRun.isEmpty { native.presentFrame(ownPlacementRun) }
        if arrangingItself, !children.isEmpty { native.arrangeChildren() }
        for child in children where child.inheritsDirection {
            child.directionTurned(arrangingItself: true)
        }
    }

    /// Whether this element says no direction of its own.
    private var inheritsDirection: Bool {
        LayoutDirection(rawValue: value(.layoutDirection)?.enumeration ?? 0).map { $0 == .inherited } ?? true
    }

    /// Where this element is drawn among its overlapping siblings, higher nearer the front.
    private var zIndex: Double { number(.zIndex) ?? 0 }

    /// The layouts whose children can overlap, drawn in `zIndex` order.
    private static let layered: Set<NodeType> = [.grid, .zStack, .motionLayout]

    /// Every one of `previous` that is no longer a child leaves: kept as it goes where it exits by a transition
    /// and this element's view keeps one, else gone at once. `presented` is how the views stood before.
    private func leave(_ previous: [MountedElement], presented: [MountedElement]) {
        let staying = Set(held.map(ObjectIdentifier.init))
        for child in previous where !staying.contains(ObjectIdentifier(child)) {
            if !child.exit(from: self) { child.leave() }
        }
        orderPresented(after: presented)
    }

    /// Ties this element to the channels of the states its properties wear and of those whose journey it follows.
    private func wear(_ driven: [Prop: HostStateBinding]) {
        let worn = (driven.values.filter { $0.kind == .property } + followed).map(\.state).sorted()
        guard worn != wornStates, let tree else { return }

        for state in wornStates { tree.stateChannels.detach(state) }
        for state in worn { tree.stateChannels.attach(state) }
        wornStates = worn
    }

    /// This element and everything under it leave the tree for good: deactivated, then released, at once.
    /// Design: docs/design/host/tree.md#leaving
    public func leave() {
        deactivate()
        release()
    }

    /// This element and everything under it stop being the application's: the whole subtree is exiting before
    /// anything of it is let go, then each lets go of its states, motions, programs and what its native half
    /// attached. Said again, it does nothing.
    /// Design: docs/design/host/tree.md#leaving
    public func deactivate() {
        deactivate(kept: false)
    }

    /// Deactivates the element, `kept` where its view goes on being drawn as it leaves: found by its mount, its
    /// properties' motions running, until it is released.
    func deactivate(kept: Bool) {
        guard lifecycle == .active else { return }

        exits()
        detach(kept: kept)
        tree?.consumersChanged()
    }

    /// The presentation of this element and everything under it ends: deactivated first where it was not, then
    /// nothing of the host holds its view - nor the views kept under it as they left. Said again, it does nothing.
    public func release() {
        guard lifecycle != .released else { return }

        deactivate()
        lifecycle = .released
        for child in held + keptExits { child.release() }
        keptExits = []
        presentedOrder = nil
        tree?.released(self)
        tree?.exits.ended(self, as: .cancelled)
    }

    /// Marks the subtree exiting, before any of it is detached: nothing a detaching tells finds part of it active.
    private func exits() {
        lifecycle = .exiting
        for child in held { child.exits() }
    }

    /// Lets go of what ties the element and everything under it to the runtime; the element itself `kept` where
    /// its view goes on being drawn. A view kept under it as it left is its own leaving's part from here on.
    private func detach(kept: Bool) {
        madeOrLeftByRender()
        if let tree {
            for state in wornStates { tree.stateChannels.detach(state) }
            tree.deactivated(self, presenting: presentedStates, kept: kept)
            if let program = layoutProgram { tree.layoutLeft(program.slot) }
        }
        layoutProgram = nil
        interactionProgram = nil
        flight = nil
        wornStates = []
        presentedStates = []
        isFadingOut = false
        native.deactivate()
        for child in held { child.detach(kept: false) }
        for exit in keptExits { exit.absorbed() }
    }

    /// The first element of `type` in this subtree, this one first.
    public func first(type sought: NodeType) -> MountedElement? {
        if type == sought { return self }

        for child in held {
            if let found = child.first(type: sought) { return found }
        }

        return nil
    }

    /// The nearest element of `type` holding this one, this one first.
    public func enclosing(type sought: NodeType) -> MountedElement? {
        var element: MountedElement? = self
        while let each = element, each.type != sought { element = each.parent }
        return element
    }

    /// The window elements in this subtree, in the tree's order; a window holds none.
    public var windows: [MountedElement] {
        type == .window ? [self] : children.flatMap(\.windows)
    }

    /// The pages in this subtree, in the tree's order, this one first.
    public var pages: [MountedElement] {
        (type == .page ? [self] : []) + held.flatMap(\.pages)
    }

    /// The first element with key `sought` in this subtree, this one first.
    public func first(id sought: ElementID) -> MountedElement? {
        if id == sought { return self }

        for child in held {
            if let found = child.first(id: sought) { return found }
        }

        return nil
    }

    /// The element standing at `place` - the keys from this one down, this one's first, each the next's among
    /// those it holds; nil where none stands so.
    public func element(at place: [ElementID]) -> MountedElement? {
        guard place.first == id else { return nil }
        var element = self
        for key in place.dropFirst() {
            guard let next = element.held.first(where: { $0.id == key }) else { return nil }
            element = next
        }
        return element
    }

    /// The element numbered `sought` in this subtree, this one first; nil where none is.
    public func first(mount sought: UInt64) -> MountedElement? {
        if mount == sought { return self }

        for child in held {
            if let found = child.first(mount: sought) { return found }
        }

        return nil
    }

    /// Every element with key `sought` in this subtree.
    public func all(id sought: ElementID) -> [MountedElement] {
        var found = id == sought ? [self] : []
        for child in held {
            found.append(contentsOf: child.all(id: sought))
        }
        return found
    }

    /// The handlers of `created` raised by no render yet, in tree order; a window raises its own.
    public func takeCreatedHandlers() -> [Int32] {
        var handlers: [Int32] = []

        if !created {
            created = true
            if type != .window, let handler = events[.created] {
                handlers.append(handler)
            }
        }

        for child in held {
            handlers.append(contentsOf: child.takeCreatedHandlers())
        }

        return handlers
    }

    /// Drops the first element in this subtree that `matches`, as a runtime that lost part of its tree would.
    public func forgetForTesting(where matches: (MountedElement) -> Bool) {
        if let index = children.firstIndex(where: matches) {
            children[index].leave()
            children.remove(at: index)
            return
        }
        for child in held { child.forgetForTesting(where: matches) }
    }

    /// Presents one frame on the elements it touches - those presenting a state that moved or holding a property
    /// that moved - and what that asks of the elements around them, deepest first: each parent arranges once,
    /// after its children; one showing no view of its own passes its children's moves on to its own parent; one
    /// whose child's order moved draws its children in order again. No other element is visited.
    /// Design: docs/design/host/runtime.md#one-frame
    static func presentFrame(
        _ touched: [MountedElement],
        states valuesByState: [Int32: HostStateValue],
        properties propertiesByMount: [UInt64: Set<Prop>]
    ) -> FrameImpact {
        struct Waiting {
            let element: MountedElement
            var descendants = FrameImpact.none
            var restacks = false
        }
        func depth(of element: MountedElement) -> Int {
            var depth = 0
            var above = element.parent
            while let each = above {
                depth += 1
                above = each.parent
            }
            return depth
        }

        var waiting: [UInt64: Waiting] = [:]
        var byDepth: [Int: [UInt64]] = [:]
        for element in touched {
            waiting[element.mount] = Waiting(element: element)
            byDepth[depth(of: element), default: []].append(element.mount)
        }
        guard let deepest = byDepth.keys.max() else { return .none }

        var impact = FrameImpact.none
        for level in stride(from: deepest, through: 0, by: -1) {
            for mount in (byDepth[level] ?? []).sorted() {
                guard let entry = waiting[mount] else { continue }
                let element = entry.element
                element.tree?.frameVisits += 1

                var changed = propertiesByMount[mount] ?? []
                for (property, binding) in element.driven where binding.mode != .in {
                    guard let value = valuesByState[binding.state] else { continue }
                    element.drivenValues[property] = value
                    changed.insert(property)
                }

                let own = changed.isEmpty ? FrameImpact.none : element.presentFrame(changed)
                // An element sized anew on a frame measures otherwise for the layout program placing it.
                if own.arrangement { element.parent?.measuredAgainForItsLayout() }
                // A child's place is its parent's business; an element with no view passes it up.
                let restacked = entry.restacks && element.restack()
                if own.arrangesChildren || entry.descendants.arrangement || restacked {
                    element.native.arrangeChildren()
                }
                var passed = entry.descendants
                if element.native.presentsView { passed.arrangement = false }
                let said = own.union(passed)
                impact.arrangesChildren = impact.arrangesChildren || said.arrangesChildren
                impact.windowChrome = impact.windowChrome || said.windowChrome

                guard let parent = element.parent else {
                    impact.arrangement = said.arrangement
                    continue
                }
                let ordered = changed.contains(.zIndex)
                guard said.arrangement || ordered else { continue }

                if waiting[parent.mount] == nil {
                    waiting[parent.mount] = Waiting(element: parent)
                    byDepth[level - 1, default: []].append(parent.mount)
                }
                if said.arrangement { waiting[parent.mount]?.descendants.arrangement = true }
                if ordered { waiting[parent.mount]?.restacks = true }
            }
        }
        return impact
    }

    /// Presents `changed` on a frame and says what that asks around the element, the same on every host: its own
    /// presentation; its parent's arrangement where it moved in its slot or shows no view of its own, being drawn
    /// by its parent's; the window's chrome where the chrome shows what moved. A motion layout's phase moves its
    /// children through its run's places alone.
    /// Design: docs/design/host/tree.md#a-frame-arranges-what-moved
    private func presentFrame(_ changed: Set<Prop>) -> FrameImpact {
        native.presentFrame(changed)
        let moved = changed.subtracting(ownPlacementRun).subtracting([.parameters])
        return FrameImpact(
            arrangesChildren: !moved.subtracting(Self.drawnOverProperties).isEmpty,
            arrangement: !native.presentsView || !moved.isDisjoint(with: Self.arrangedProperties),
            windowChrome: WindowChrome.follows(type, changed: changed))
    }

    /// The value `property` presents: a running animation's, else the described or bound one - none where it is a
    /// number that is none.
    /// Design: docs/design/core/contracts.md#a-number-that-is-none
    public func value(_ property: Prop) -> HostValue? {
        let shown: HostValue?
        if driven[property].map({ $0.mode != .in }) == true {
            shown = resolvedValue(property)
        } else {
            shown = tree?.presentedPropertyValue(mount: mount, property: property) ?? resolvedValue(property)
        }
        guard let value = GeometryArithmetic.value(shown, for: property), !value.holdsNonFiniteNumber else { return nil }
        return value
    }

    /// The text value of `property`.
    public func string(_ property: Prop) -> String? { value(property)?.string }

    /// The name value of `property`.
    public func name(_ property: Prop) -> String? { value(property)?.name }

    /// The number value of `property`.
    public func number(_ property: Prop) -> Double? { value(property)?.number }

    /// The whole number a property presents, rounded as its contract says; nil for another kind or a number outside Int.
    public func whole(_ property: Prop) -> Int? { value(property).flatMap(Int.init(propValue:)) }

    /// The Boolean value of `property`.
    public func bool(_ property: Prop) -> Bool? { value(property)?.bool }

    /// The four sides `property` gives - leading, top, trailing, bottom - or nothing all round where it gives none.
    public func insets(_ property: Prop) -> Insets {
        guard let sides = value(property)?.numbers, sides.count >= 4 else { return Insets(0) }
        return Insets(start: sides[0], top: sides[1], end: sides[2], bottom: sides[3])
    }

    /// The handler of `event`, when the tree listens to it.
    public func handler(_ event: Event) -> Int32? { events[event] }

    /// The direction this element lays out in: its own, or where it inherits, its parent's - the
    /// language's at the root, as the host reported the locale.
    /// Design: docs/design/host/layout.md#right-to-left
    public var layoutDirection: LayoutDirection {
        switch value(.layoutDirection)?.enumeration.flatMap(LayoutDirection.init(rawValue:)) {
        case .leftToRight?: return .leftToRight
        case .rightToLeft?: return .rightToLeft
        default: return parent?.layoutDirection ?? tree?.core.languageDirection ?? .leftToRight
        }
    }

    /// What a layout reads of this element as its child.
    /// Design: docs/design/host/layout.md#the-layout-arithmetic
    public var layoutValues: LayoutValues {
        var values = LayoutValues()
        if let sides = value(.margin)?.numbers, sides.count >= 4 {
            values.margin = insets(.margin)
        }
        values.horizontal = value(.horizontalAlignment)?.enumeration ?? NodeType.unsaidHorizontal[type] ?? 3
        values.vertical = value(.verticalAlignment)?.enumeration ?? 3
        values.width = stated(VisualElementContract.width.token)
        values.height = stated(VisualElementContract.height.token)
        values.minimumWidth = stated(VisualElementContract.minimumWidth.token)
        values.minimumHeight = stated(VisualElementContract.minimumHeight.token)
        values.maximumWidth = stated(VisualElementContract.maximumWidth.token)
        values.maximumHeight = stated(VisualElementContract.maximumHeight.token)
        values.row = whole(.gridRow) ?? 0
        values.column = whole(.gridColumn) ?? 0
        values.rowSpan = max(whole(.gridRowSpan) ?? 1, 1)
        values.columnSpan = max(whole(.gridColumnSpan) ?? 1, 1)
        values.area = value(.area).flatMap(Area.init(propValue:))
        values.grows = type == .space
        values.words = NodeType.laidOutWords[type] ?? .none
        // Its own body wins; else what its layout says for every child. A motion layout's view is a body of that
        // layout, whose program places its holder: in the holder it stands as the holder does.
        if parent?.parent?.type != .motionLayout {
            values.body = value(ViewContract.layoutBody.token).flatMap(LayoutBody.init(propValue:))
                ?? parent?.value(LayoutContract.layoutBodies.token).flatMap(LayoutBody.init(propValue:))
        }
        return values
    }

    /// A size the element states for itself; a negative one asks to be measured.
    private func stated(_ property: Prop) -> Double? {
        guard let value = number(property), value.isFinite, value >= 0 else { return nil }
        return value
    }

    /// The bound state's value for `property`, as the last frame carried it or the core holds it.
    public func carriedValue(_ property: Prop) -> HostStateValue? {
        guard let binding = driven[property] else { return nil }
        return drivenValues[property] ?? tree?.core.value(for: binding)
    }

    /// Where `property` is headed: the destination of the journey its state carries it on; nil where no state does.
    public func destination(_ property: Prop) -> HostValue? {
        guard let binding = driven[property], binding.mode != .in, binding.kind == .property,
              let carried = carriedValue(property),
              let journey = HostBoundary.journey(from: tree?.presentedValue(for: binding, from: carried) ?? carried)
        else { return nil }
        return Self.value(of: journey.destination, as: binding.laneKind)
    }

    /// The value `property` settles at: the bound state's, else the described one.
    public func resolvedValue(_ property: Prop) -> HostValue? {
        guard let binding = driven[property], binding.mode != .in else {
            return properties[property]
        }

        guard let state = drivenValues[property] ?? tree?.core.value(for: binding) else {
            return properties[property]
        }

        switch (binding.kind, state) {
        case (.text, .string(let text)):
            return .string(text)

        case (.plain, .lanes(let lanes)):
            return Self.value(of: lanes, as: binding.laneKind)

        case (.property, let carried):
            let presented = tree?.presentedValue(for: binding, from: carried) ?? carried
            guard let journey = HostBoundary.journey(from: presented) else {
                return properties[property]
            }
            return Self.value(of: journey.value, as: binding.laneKind)

        default:
            return properties[property]
        }
    }

    /// Where `property` stands before a change animates it.
    /// Design: docs/design/host/tree.md#standing-values
    private func standingValue(_ property: Prop, target: HostValue?) -> HostValue? {
        if let presented = tree?.presentedPropertyValue(mount: mount, property: property) {
            return presented
        }
        if let native = native.standingValue(property) { return native }
        if let value = resolvedValue(property) { return value }
        guard native.animates(property) else { return nil }

        switch property {
        case .margin, .padding:
            return .numbers([0, 0, 0, 0])
        case StackContract.spacing.token, ToolbarGroupContract.spacing.token, GridContract.rowSpacing.token,
             HStackContract.rowSpacing.token, .columnSpacing:
            return .number(0)
        case ShapeContract.lineWidth.token, BorderElementContract.lineWidth.token:
            return .number(1)
        case .dashPhase:
            return .number(0)
        case .from, .to:
            return .numbers([0, 0])
        case .miterLimit:
            return .number(10)
        case .cornerRadius:
            if target?.number != nil {
                return .number(0)
            }
            if let radii = target?.numbers, radii.count == 4 {
                return .numbers(Array(repeating: 0, count: radii.count))
            }
            return nil
        default:
            return identity(of: property)
        }
    }

    /// What a transform the tree states none of stands at, on every host: no turn, no shift, a scale of one. A
    /// transform taken away travels back there, as it traveled out from there.
    /// Design: docs/design/host/tree.md#standing-values
    private func identity(of property: Prop) -> HostValue? {
        switch property {
        case .rotation, .translationX, .translationY:
            .number(0)
        case .scale:
            .number(1)
        case .scaleX, .scaleY:
            .number(resolvedValue(.scale)?.number ?? 1)
        case .geometryTransform:
            .values([
                .number(1), .number(0), .number(0),
                .number(1), .number(0), .number(0),
            ])
        default:
            nil
        }
    }

    /// A bound state's lanes as the value its type says they are, each type reading them as it laid them;
    /// nothing for text, which has no lanes.
    static func value(of lanes: [Double], as kind: HostLaneKind?) -> HostValue? {
        guard !lanes.isEmpty, let kind else { return nil }

        switch kind {
        case .number:
            return lanes.count == 1 ? .number(lanes[0]) : .numbers(lanes)
        case .bool:
            return Bool(carried: .lanes(lanes))?.propValue
        case .choice:
            return Int32(exactly: lanes[0].rounded()).map(HostValue.enumeration)
        case .color:
            return Color(carried: .lanes(lanes))?.propValue
        case .material:
            return Material.propValue(lanes: lanes)
        }
    }
}
