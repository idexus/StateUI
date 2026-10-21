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

    /// The direction the element lays out in, `MountedElement.layoutDirection`, was given or turned: the toolkit's
    /// view takes it.
    func directionChanged()

    /// The element leaves the tree: everything it attached outside the tree lets go of it.
    func leave()

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
    private var patchTime: Double?
    private(set) var languageDirection: LayoutDirection?
    private var patchReducesMotion: Bool?

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
        // The first take starts the recording, so the log holds every pass from here on.
        if diagnostics.inspects { _ = core.takeInspectionLog() }
    }

    /// Applies a message's root `patch`, at one time for the whole message; a new root when `complete`.
    /// While an inspector records, it is told what the apply cost; the diagnostic text hears of it too.
    /// Design: docs/design/host/patches.md#what-a-message-costs
    public func apply(_ patch: HostPatch, complete: Bool) {
        let previousPatchTime = patchTime
        let previousPatchReducesMotion = patchReducesMotion
        let previousTally = tally
        if patchTime == nil { patchTime = now() }
        if patchReducesMotion == nil { patchReducesMotion = reducesMotion() }
        let inspecting = core.inspecting
        tally = inspecting || diagnostics.tallies ? RenderTally() : nil
        defer {
            if let tally {
                if inspecting, let generation = intake.generationBeingApplied {
                    core.inspected(tally, generation: generation)
                }
                diagnostics.applied(tally, began: patchTime ?? 0, core: core)
            }
            patchTime = previousPatchTime
            patchReducesMotion = previousPatchReducesMotion
            tally = previousTally
        }

        if let root, root.id == patch.id, root.type == patch.type, !patch.replace {
            root.apply(patch)
        } else if root == nil || complete || patch.replace {
            root?.leave()
            root = MountedElement(patch, tree: self, parent: nil)
        } else {
            intake.drifted("a sparse message describes a root '\(patch.id)' the tree does not hold")
        }
        if let root { KeyboardShortcuts.complainOfRepeats(in: root, after: patch) }
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
        ProgramWrite.perform {
            var touched = Set(properties.keys)
            for state in states.keys { touched.formUnion(presenters[state] ?? []) }
            return MountedElement.presentFrame(
                touched.sorted().compactMap { byMount[$0]?.element }, states: states, properties: properties)
        }
    }

    /// `element` is mounted: a frame finds it by its mount.
    func mounted(_ element: MountedElement) {
        byMount[element.mount] = Held(element: element)
    }

    /// `element` presents `states` now rather than `before`, the states its bound properties take a frame's values
    /// from.
    func presents(_ element: MountedElement, _ states: [Int32], before: [Int32]) {
        for state in before {
            presenters[state]?.remove(element.mount)
            if presenters[state]?.isEmpty == true { presenters[state] = nil }
        }
        for state in states { presenters[state, default: []].insert(element.mount) }
    }

    /// `element` leaves, with the states it presented: no frame finds it again.
    func unmounted(_ element: MountedElement, presenting states: [Int32]) {
        byMount[element.mount] = nil
        presents(element, [], before: states)
        left(element.mount)
    }

    /// Starts, retargets or cuts short the animation of `property` on the element `mount`.
    @discardableResult
    public func receiveProperty(
        mount: UInt64,
        property: Prop,
        standing: HostValue?,
        target: HostValue?,
        motion: Motion?,
        landed: (() -> Void)? = nil
    ) -> Bool {
        let started = describedMotion.receive(
            key: DescribedKey(mount: mount, property: property),
            standing: standing,
            target: target,
            motion: motion,
            landed: landed,
            now: patchTime ?? now(),
            reducesMotion: patchReducesMotion ?? reducesMotion())
        onAnimation()
        return started
    }

    /// The value a running animation draws for `property` on the element `mount`.
    public func presentedPropertyValue(mount: UInt64, property: Prop) -> HostValue? {
        describedMotion.presentedValue(for: DescribedKey(mount: mount, property: property))
    }

    func presentedValue(for binding: HostStateBinding, from carried: HostStateValue) -> HostStateValue {
        stateChannels.presentedValue(
            for: binding, from: carried, now: patchTime ?? now(), reducesMotion: patchReducesMotion ?? reducesMotion())
    }

    func allocateMount() -> UInt64 {
        precondition(nextMount < .max, "the mounted tree ran out of numbers")
        nextMount += 1
        return nextMount
    }

    /// Drops the animations of an element that leaves: its properties' and its place's.
    func removeMotions(mount: UInt64) {
        describedMotion.remove(mount: mount)
        layoutMotion.remove(mount: mount)
    }
}
