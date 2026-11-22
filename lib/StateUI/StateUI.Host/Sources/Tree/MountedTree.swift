// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What presenting an element on a frame asks of the elements around it.
@_spi(Host) public struct FrameImpact: Equatable, Sendable {
    /// The element arranges its children again: a value moved that is more than its own run of places, which its
    /// presentation puts.
    /// Design: docs/design/host/tree.md#a-frame-arranges-what-moved
    public var arrangesChildren: Bool

    /// The element's place in its parent changed, so the parent arranges again.
    public var arrangement: Bool

    /// The window's chrome shows what moved: a window's frame, a bar's colors, a page's words on its bar
    /// (`WindowChrome.follows`).
    public var windowChrome: Bool

    /// An impact of the parts named.
    public init(arrangesChildren: Bool = false, arrangement: Bool = false, windowChrome: Bool = false) {
        self.arrangesChildren = arrangesChildren
        self.arrangement = arrangement
        self.windowChrome = windowChrome
    }

    /// No impact at all.
    public static let none = FrameImpact()

    /// What either impact asks.
    public func union(_ other: FrameImpact) -> FrameImpact {
        FrameImpact(
            arrangesChildren: arrangesChildren || other.arrangesChildren,
            arrangement: arrangement || other.arrangement,
            windowChrome: windowChrome || other.windowChrome)
    }
}

/// The toolkit's half of a mounted element: its native view and everything hung on it.
/// Design: docs/design/host/tree.md#the-native-half
@_spi(Host) @MainActor public protocol NativeElement: AnyObject {
    /// Whether the element shows a view of its own; one without is drawn by its parent's.
    var presentsView: Bool { get }

    /// The value `property` stands at natively before a change animates it; nil where the tree's stands.
    func standingValue(_ property: Prop) -> HostValue?

    /// Whether the toolkit animates `property` on this element.
    func animates(_ property: Prop) -> Bool

    /// The patch is in: presents the `changed` properties and arranges; `wasDescribed` is false the first time.
    func applied(changed: Set<Prop>, wasDescribed: Bool)

    /// Presents one frame's `changed` properties; what that asks of the elements around it is the host layer's.
    func presentFrame(_ changed: Set<Prop>)

    /// Places the element's children again.
    func arrangeChildren()

    /// Draws the element's children again in the order its layout draws them, at once - a child a shared entry
    /// carries in front of the others, with nothing placed again.
    /// Design: docs/design/host/layout.md#drawing-order
    func orderChildren()

    /// The element's size may change outside a patch - a child faded out and its layout closes over it: this
    /// layout and every one around it forget what they measured and lay out again.
    func invalidateMeasurements()

    /// The element's own size in the room offered - a width, a height, either or neither - its margin left out and
    /// its stated sizes and bounds applied, and how far below its top its first line of words rests: what a layout's
    /// program asks of a child. An element with no view of its own answers nought.
    /// Design: docs/design/host/layout.md#a-layout-program
    func measured(width: Double?, height: Double?) -> HostChildMeasured

    /// Hands the element's layout what its children travel under, and tells it a change reached it: its next
    /// arrangement moves them as a patch's does.
    func configureLayoutMotion()

    /// The direction the element lays out in, `MountedElement.layoutDirection`, was given or turned: the toolkit's
    /// view takes it.
    func directionChanged()

    /// The element stops being the application's: everything it attached outside the tree lets go of it - its
    /// observers, recognizers, focus and what it tells - while its view stands as it was drawn.
    /// Design: docs/design/host/tree.md#leaving
    func deactivate()

    /// Nothing of the element is drawn any more: a host whose view could not go as the element was deactivated -
    /// it `staysDrawn` - lets it go now. Told once, to such an element alone.
    /// Design: docs/design/host/tree.md#a-view-kept-as-it-leaves
    func releasePresentation()

    /// Where the view stands now, as a frame report says it - its place in what holds it, its corner in its window
    /// and from the window's content; nil in no window, or before a layout placed it.
    /// Design: docs/design/host/runtime.md#where-a-view-stands
    func frameNumbers() -> [Double]?

    /// Whether the element's view keeps a child that left - drawn where it stood, out of its layout - until that
    /// child's presentation is released.
    /// Design: docs/design/host/tree.md#a-view-kept-as-it-leaves
    var keepsExits: Bool { get }

    /// The tab the user chose on a tabbed view, which the tree may not say yet; nil where none.
    var chosenTab: Int? { get }

    /// Whether a split view shows its sidebar on screen; nil where the tree's word stands.
    var showsSidebar: Bool? { get }
}

@_spi(Host) extension NativeElement {
    /// No tab chosen apart from the tree.
    public var chosenTab: Int? { nil }

    /// The sidebar as the tree says.
    public var showsSidebar: Bool? { nil }

    /// A view that lays nothing out by direction takes none.
    public func directionChanged() {}

    /// A view keeps no child that left: what it drops is gone at once.
    public var keepsExits: Bool { false }

    /// A view its holder's arrangement takes out has nothing more to let go.
    public func releasePresentation() {}

    /// A native half with no view on a page stands nowhere.
    public func frameNumbers() -> [Double]? { nil }
}

/// The runtime's mounted tree: its root, its elements' numbers, and the animations its patches start.
/// Design: docs/design/host/tree.md#the-mounted-tree
@_spi(Host) @MainActor public final class MountedTree {
    /// The mounted root; nil before the first message.
    public private(set) var root: MountedElement?

    /// Where a page's or a window's phase goes: the runtime's handlers, each rendered in its turn.
    var tellPhase: (Int32) -> Void = { _ in }

    /// Who hears that the element of a mount left: the runtime's frame readers, which follow it no more, and a split's
    /// sidebar slide, which stops where it stands.
    var left: (UInt64) -> Void = { _ in }

    /// What an element whose interaction program changed tells, with the program it had.
    var interactionChanged: (MountedElement, HostInteractionProgram?) -> Void = { _, _ in }

    /// The runtime's line to the core.
    public let core: CoreLink

    /// The intake whose messages the tree applies; it hears of a drift.
    public let intake: PatchIntake

    /// The channels of the bound states the elements wear.
    public let stateChannels: StateChannels

    /// The animations the patches describe.
    public let describedMotion: DescribedMotion

    /// The animations of the layouts' places.
    public let layoutMotion: LayoutMotion

    /// The views kept as they leave, and the budget of them.
    public let exits = KeptExits()

    /// The elements that came back where one of their authored identity left, each with the id that one is known
    /// by: the render's table, set before its patch is applied and read as an element is made.
    /// Design: docs/design/host/tree.md#the-same-view-coming-back
    public var returnsAs: [ElementID: ElementID] = [:]

    /// The presentation changes the renders carry, and what each waits for.
    public let changes: PresentationChanges

    /// The views a patch dropped and made under one key of a shared transition.
    public let shared = SharedTransitions()

    /// Called when a property animation starts, so the frame clock is held while it runs.
    public var onAnimation: () -> Void = {}

    /// What the runtime writes out for its log: the running tally and the inspected passes.
    public private(set) var diagnostics: DiagnosticText

    private let now: () -> Double
    private let reducesMotion: () -> Bool
    let makeNative: (MountedElement) -> any NativeElement
    private var nextMount: UInt64 = 0

    /// Every element mounted, by its mount, and the elements presenting each state a frame carries, by its number:
    /// what a frame presents, with no walk of the tree.
    /// Design: docs/design/host/runtime.md#one-frame
    private var byMount: [UInt64: Held] = [:]
    private var presenters: [Int32: Set<UInt64>] = [:]

    /// The elements running a layout program, by the program's slot: what a cycle's worked-out slots name.
    /// Design: docs/design/host/layout.md#a-layout-program
    private var layouts: [UInt64: UInt64] = [:]

    /// The element running the layout program `slot` names, by its mount, where the program put its children
    /// somewhere new since the element last presented them; nil where none runs it or nothing moved.
    public func mount(ofLayout slot: UInt64) -> UInt64? {
        guard let mount = layouts[slot], let element = byMount[mount]?.element else { return nil }
        // A layout worked out again may say another size of its own, which its toolkit measures again.
        element.measuredAgainWhereItsSizeMoved()
        let moved = element.takeProgramPlaces(at: now(), reducesMotion: reducesMotion())
        if element.programBodiesMove { movingLayouts.insert(mount) } else { movingLayouts.remove(mount) }
        return moved ? mount : nil
    }

    /// `element`, laid out by its toolkit, takes its program's places now, in that layout pass - the children on
    /// their way from them stepped in the display's frames.
    /// Design: docs/design/host/layout.md#placed-from-the-first-pass
    func takePlaces(of element: MountedElement) {
        _ = element.takeProgramPlaces(at: now(), reducesMotion: reducesMotion())
        if element.programBodiesMove { movingLayouts.insert(element.mount) }
    }

    /// The layouts whose parameters one of `states` moved this frame, asked where they stand now: those whose
    /// children stand somewhere new, by mount, in order.
    /// Design: docs/design/host/layout.md#asked-in-the-hosts-frame
    public func layouts(movedBy states: Set<Int32>) -> [UInt64] {
        guard !states.isEmpty else { return [] }

        var moved: [UInt64] = []
        for mount in layouts.values.sorted() {
            guard let element = byMount[mount]?.element, element.layoutProgram?.place != nil,
                  let state = element.driven[.parameters]?.state, states.contains(state)
            else { continue }

            if element.takeProgramPlaces(at: now(), reducesMotion: reducesMotion()) { moved.append(mount) }
            if element.programBodiesMove { movingLayouts.insert(mount) } else { movingLayouts.remove(mount) }
        }
        return moved
    }

    /// The layouts that came to rest since they were last asked - no hand on their parameters, the parameters
    /// where they are going, every child at its place: what hears each, and where its parameters stand.
    /// Design: docs/design/host/layout.md#at-rest
    public func takeRestedLayouts() -> [(handler: Int32, parameters: [Double])] {
        var rested: [(handler: Int32, parameters: [Double])] = []
        for mount in layouts.values.sorted() {
            guard let element = byMount[mount]?.element, let samples = element.cameToRest() else { continue }
            changes.rested(mount)
            if let handler = element.handler(.settled) { rested.append((handler, samples)) }
        }
        return rested
    }

    /// The elements whose children are on their way to the places a layout program gave them, by mount.
    private var movingLayouts: Set<UInt64> = []

    /// Whether a layout program's child is still on its way to its place: the display's frames go on for it.
    public var layoutBodiesMove: Bool { !movingLayouts.isEmpty }

    /// Steps every such child to the tree's time, and answers the elements whose children stand somewhere new, by
    /// mount, in order.
    /// Design: docs/design/host/layout.md#bodies
    public func stepLayoutBodies() -> [UInt64] {
        var moved: [UInt64] = []
        for mount in movingLayouts.sorted() {
            guard let element = byMount[mount]?.element else {
                movingLayouts.remove(mount)
                continue
            }
            if element.stepProgramPlaces(to: now()) { moved.append(mount) }
            if !element.programBodiesMove { movingLayouts.remove(mount) }
        }
        return moved
    }

    /// The elements the hand moved by themselves since the last frame, where no layout program places them, by
    /// mount.
    private var movedLocally: Set<UInt64> = []

    /// What the hand does to `element`'s own presentation changed: the layout program placing it steps its
    /// places at the next frame, and an element no program places is drawn again by its own transform.
    /// Design: docs/design/host/interaction.md#a-views-own-press-and-drag
    func movedLocally(_ element: MountedElement) {
        if let layout = element.programPlacing?.layout {
            layout.childrenMovedLocally = true
            movingLayouts.insert(layout.mount)
        } else {
            movedLocally.insert(element.mount)
        }
    }

    /// The elements the hand moved by themselves since this was last asked, by mount, in order.
    public func takeLocalMoves() -> [UInt64] {
        defer { movedLocally = [] }
        return movedLocally.sorted()
    }

    /// `element` runs the layout program `slot` names.
    func layoutStands(_ slot: UInt64, on element: MountedElement) { layouts[slot] = element.mount }

    /// No element runs the layout program `slot` names any more.
    func layoutLeft(_ slot: UInt64) {
        if let mount = layouts[slot] { movingLayouts.remove(mount) }
        layouts[slot] = nil
    }

    /// How many elements frames have visited, an element a visit: what says a frame costs what it touches, however
    /// large the tree.
    var frameVisits = 0

    /// Whether the patches applied since the last take changed what the windows' chrome is made of.
    /// Design: docs/design/host/pages.md#a-render-that-touches-the-chrome
    var chromeTouched = false

    /// An element held weakly: an index never keeps one the tree let go.
    private struct Held {
        weak var element: MountedElement?
    }

    /// The popovers their hosts could not show for want of their window, by mount.
    private var waitingPopovers: [UInt64: Held] = [:]

    /// The sheets the views declare, by mount: a window's presentation looks among them.
    private var sheets: [UInt64: Held] = [:]

    /// How many entries the tree's own indexes hold.
    var entries: Int {
        byMount.count + presenters.values.reduce(0) { $0 + $1.count } + layouts.count + movingLayouts.count
            + movedLocally.count + waitingPopovers.count + sheets.count
    }
    private var patchTime: Double?
    private(set) var languageDirection: LayoutDirection?
    private var patchReducesMotion: Bool?

    /// Whether the message being applied is complete: an element it keeps holds only what it names.
    /// Design: docs/design/host/patches.md#a-complete-message
    private(set) var appliesCompleteMessage = false

    /// Whether the message being applied makes again what the tree showed - a complete one over a root, or
    /// another root in its place. Design: docs/design/host/motion.md#a-view-that-enters
    private(set) var remakes = false

    /// What the message being applied costs, while an inspector records or the tally is written; nil otherwise.
    var tally: RenderTally?

    /// A tree whose elements' native halves `makeNative` makes, on `now`'s time.
    public init(
        core: CoreLink,
        intake: PatchIntake,
        stateChannels: StateChannels,
        describedMotion: DescribedMotion,
        layoutMotion: LayoutMotion,
        now: @escaping () -> Double,
        reducesMotion: @escaping () -> Bool,
        diagnostics: DiagnosticText = .environment,
        makeNative: @escaping (MountedElement) -> any NativeElement
    ) {
        self.core = core
        self.intake = intake
        self.stateChannels = stateChannels
        self.describedMotion = describedMotion
        self.layoutMotion = layoutMotion
        self.now = now
        self.reducesMotion = reducesMotion
        self.makeNative = makeNative
        self.diagnostics = diagnostics
        changes = PresentationChanges(core: core)
        describedMotion.born = { [weak self] key in
            guard let self, let element = byMount[key.mount]?.element else { return }
            changes.born(.described(key), on: element, inLayoutPass: patchTime == nil)
        }
        describedMotion.ended = { [weak self] key, end in self?.changes.ended(.described(key), as: end) }
        layoutMotion.placing = { [weak self] mount in
            guard let self, let element = byMount[mount]?.element else { return }
            changes.placing(element)
        }
        layoutMotion.born = { [weak self] mount in
            guard let self, let element = byMount[mount]?.element else { return }
            changes.born(.placed(mount), on: element, inLayoutPass: patchTime == nil)
        }
        layoutMotion.ended = { [weak self] mount, end in self?.changes.ended(.placed(mount), as: end) }
        stateChannels.watching = { [weak self] state, run, ended in
            if let ended { self?.changes.runEnded(state, run, as: ended) } else { self?.changes.runBorn(state, run) }
        }
        changes.layouts = { [weak self] state, root in self?.layouts(runBy: state, under: root) ?? [] }
        shared.refused = { [weak self] element in self?.changes.refused(element, .unsupported) }
        // The first take starts the recording, so the log holds every pass from here on.
        if diagnostics.inspects { _ = core.takeInspectionLog() }
    }

    /// Applies a message's root `patch`, at one time for the whole message. A `complete` message makes a new root
    /// where it names another, and every element it keeps holds only what it names. While an inspector records, it is
    /// told what the apply cost; the diagnostic text hears of it too.
    /// Design: docs/design/host/patches.md#what-a-message-costs
    public func apply(_ patch: HostPatch, complete: Bool) {
        let previousPatchTime = patchTime
        let previousPatchReducesMotion = patchReducesMotion
        let previousTally = tally
        let previousComplete = appliesCompleteMessage
        let previousRemakes = remakes
        appliesCompleteMessage = complete
        remakes = root != nil && (complete || patch.replace)
        if remakes { exits.endAll(.detached) }
        if patchTime == nil {
            patchTime = now()
            shared.patchBegins()
        }
        if patchReducesMotion == nil { patchReducesMotion = reducesMotion() }
        let inspecting = core.inspecting
        tally = inspecting || diagnostics.tallies ? RenderTally() : nil
        defer {
            if previousPatchTime == nil { shared.patchApplied() }
            if let tally {
                if inspecting, let generation = intake.generationBeingApplied {
                    core.inspected(tally, generation: generation)
                }
                diagnostics.applied(tally, began: patchTime ?? 0, core: core)
            }
            patchTime = previousPatchTime
            patchReducesMotion = previousPatchReducesMotion
            tally = previousTally
            appliesCompleteMessage = previousComplete
            remakes = previousRemakes
            consumersChanged()
        }

        if let root, holdsRoot(of: patch), !patch.replace {
            root.apply(patch)
        } else if root == nil || complete || patch.replace {
            root?.leave()
            root = MountedElement(patch, tree: self, parent: nil)
        } else {
            intake.drifted("a sparse message describes a root '\(patch.id)' the tree does not hold")
        }
        if let root { KeyboardShortcuts.complainOfRepeats(in: root, after: patch) }
    }

    /// Whether the root standing is the element `patch` describes, which a message can change; a message describing
    /// another can only be complete.
    public func holdsRoot(of patch: HostPatch) -> Bool {
        root.map { $0.id == patch.id && $0.type == patch.type } ?? false
    }

    /// `popover` waits for its window, which its host makes once the render stands.
    func wait(_ popover: MountedElement) {
        waitingPopovers[popover.mount] = Held(element: popover)
    }

    /// The popovers waiting for their window, in the order they were made, forgotten as they are taken: a host
    /// tries each again once its windows stand after a render.
    /// Design: docs/design/host/pages.md#a-popover
    public func takeWaitingPopovers() -> [MountedElement] {
        defer { waitingPopovers = [:] }
        let taken = waitingPopovers.sorted { $0.key < $1.key }.compactMap(\.value.element)
        for popover in taken { popover.isMoving = false }
        return taken
    }

    /// Whether the patches applied since the last take changed what the windows' chrome is made of; forgotten as
    /// it is taken.
    public func takeChromeTouched() -> Bool {
        defer { chromeTouched = false }
        return chromeTouched
    }

    /// Lays the whole tree out again where the language's direction turned since the tree last followed it.
    /// Design: docs/design/host/layout.md#right-to-left
    public func followTheLanguagesDirection() {
        let direction = core.languageDirection
        guard direction != languageDirection else { return }
        languageDirection = direction
        root?.directionTurned(arrangingItself: true)
    }

    /// Presents one frame's batch to the elements it touched - found by their mount and by the states they present -
    /// deepest first, every write in it the program's.
    /// Design: docs/design/host/patches.md#program-write
    @discardableResult
    public func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) -> FrameImpact {
        var properties = properties
        // A view traveling a shared transition's way draws, with its numbers, what the way works out of them: its
        // own corner, and the opacity of the view whose way it is.
        for (mount, changed) in properties.sorted(by: { $0.key < $1.key }) where !changed.isDisjoint(with: SharedWay.moved) {
            guard let traveler = byMount[mount]?.element, let holder = traveler.travelsFor ?? Optional(traveler),
                  let way = holder.way, way.traveler === traveler
            else { continue }
            if way.comes != nil { properties[holder.mount, default: []].insert(.opacity) }
            if way.corner != nil, let rounding = traveler.roundingProperty { properties[mount, default: []].insert(rounding) }
        }
        return ProgramWrite.perform {
            var touched = Set(properties.keys)
            for state in states.keys { touched.formUnion(presenters[state] ?? []) }
            return MountedElement.presentFrame(
                touched.sorted().compactMap { byMount[$0]?.element }, states: states, properties: properties)
        }
    }

    /// `element` is mounted: a frame finds it by its mount.
    func mounted(_ element: MountedElement) {
        byMount[element.mount] = Held(element: element)
        if element.type == .sheet { sheets[element.mount] = Held(element: element) }
    }

    /// The pages `window`'s sheets present, in the order they showed: a sheet's page is made as it shows - the
    /// arrangement an anchor there holds standing in its place.
    /// Design: docs/design/host/tree.md#a-window-shown
    public func presentedSheets(in window: MountedElement) -> [MountedElement] {
        sheets.values.compactMap(\.element)
            .compactMap { $0.enclosing(type: .window) === window ? $0.children.first : nil }
            .sorted { $0.mount < $1.mount }
            .compactMap(\.placed)
    }

    /// `element` presents `states` now rather than `before`, the states its bound properties take a frame's values
    /// from.
    /// The layouts at `root` or under it whose program `state` runs, by mount, in order.
    func layouts(runBy state: Int32, under root: UInt64) -> [UInt64] {
        layouts.values.sorted().filter { mount in
            guard let element = byMount[mount]?.element, element.layoutProgram?.place != nil,
                  element.driven[.parameters]?.state == state
            else { return false }
            var each: MountedElement? = element
            while let next = each {
                if next.mount == root { return true }
                each = next.parent
            }
            return false
        }
    }

    /// Whether an element standing at `mount` or under it shows `state`.
    func shows(_ state: Int32, under mount: UInt64) -> Bool {
        for presenter in (presenters[state] ?? []).sorted() {
            var each = byMount[presenter]?.element
            while let element = each {
                if element.mount == mount { return true }
                each = element.parent
            }
        }
        return false
    }

    func presents(_ element: MountedElement, _ states: [Int32], before: [Int32]) {
        for state in before {
            presenters[state]?.remove(element.mount)
            if presenters[state]?.isEmpty == true { presenters[state] = nil }
        }
        for state in states { presenters[state, default: []].insert(element.mount) }
    }

    /// `element` is the application's no more, with the states it presented: nothing awaits it, follows it or
    /// places it. One `kept` as it leaves is still found by its mount, its properties' motions running on, until
    /// it is `released`.
    /// Design: docs/design/host/tree.md#a-view-kept-as-it-leaves
    func deactivated(_ element: MountedElement, presenting states: [Int32], kept: Bool) {
        waitingPopovers[element.mount] = nil
        sheets[element.mount] = nil
        presents(element, [], before: states)
        left(element.mount)
        changes.left(element.mount)
        layoutMotion.remove(mount: element.mount)
        if !kept { released(element) }
    }

    /// Nothing of `element` is drawn any more: no frame finds it again.
    func released(_ element: MountedElement) {
        byMount[element.mount] = nil
        describedMotion.remove(mount: element.mount)
    }

    /// The time the message being applied stands at, else now.
    var time: Double { patchTime ?? now() }

    /// Starts, retargets or cuts short the animation of `property` on the element `mount`.
    @discardableResult
    public func receiveProperty(
        mount: UInt64,
        property: Prop,
        standing: HostValue?,
        target: HostValue?,
        motion: Motion?,
        landed: (() -> Void)? = nil,
        velocity: [Double] = []
    ) -> Bool {
        let started = describedMotion.receive(
            key: DescribedKey(mount: mount, property: property),
            standing: standing,
            target: target,
            motion: motion,
            landed: landed,
            velocity: velocity,
            now: patchTime ?? now(),
            reducesMotion: patchReducesMotion ?? reducesMotion())
        onAnimation()
        return started
    }

    /// Where a running animation of `property` on the element `mount` stands now, and how fast; nil where none runs.
    func standingProperty(mount: UInt64, property: Prop) -> (value: HostValue, velocity: [Double])? {
        describedMotion.standing(of: DescribedKey(mount: mount, property: property), now: time)
    }

    /// The value a running animation draws for `property` on the element `mount`.
    public func presentedPropertyValue(mount: UInt64, property: Prop) -> HostValue? {
        describedMotion.presentedValue(for: DescribedKey(mount: mount, property: property))
    }

    func presentedValue(for binding: HostStateBinding, from carried: HostStateValue) -> HostStateValue {
        stateChannels.presentedValue(
            for: binding, from: carried, now: patchTime ?? now(), reducesMotion: patchReducesMotion ?? reducesMotion())
    }

    /// Consumers of state channels came or went: settled once the message being applied is whole, at once outside
    /// one, so a consumer that leaves one element for another in one message keeps its channel.
    /// Design: docs/design/host/motion.md#state-channels
    func consumersChanged() {
        if patchTime == nil { stateChannels.settle() }
    }

    func allocateMount() -> UInt64 {
        precondition(nextMount < .max, "the mounted tree ran out of numbers")
        nextMount += 1
        return nextMount
    }

}
