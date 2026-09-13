// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a host is holding, and what it is about to be told.
//
// A Node is what an author wrote this render and is thrown away after it. These
// two types are the ones that persist:
//
//   RenderedNode  one element as it now stands on the host - its identity,
//                 its properties, the handler ids it quotes back, its children
//   HostPatch     the difference between that and the tree just written, which
//                 a native host reads directly and Wire serializes for MAUI
//
// Keeping the first is what makes the second possible. Without it, "what
// changed" has no answer and the only correct message is the whole tree.

/// Identity of an element, stable for as long as the element lives.
///
/// The two cases are two namespaces that cannot collide, which is the point:
///
///   .auto     assigned by the differ, written as a NUMBER
///   .manual   whatever the author passed to `.id()`, written as TEXT
///
/// An automatic identity survives a render as long as the element is written in
/// the same place in the source - its builder path - or, put in by hand, stands
/// at the same position. A manual one survives anywhere, which is what a
/// collection needs.
public enum ElementId: Hashable, Sendable {
    /// Assigned by the differ, from a counter, never reused. Written as a
    /// number.
    case auto(Int)

    /// Written by the author with `.id()`. Written as text, which is what
    /// keeps the two namespaces from ever colliding.
    case manual(String)

    /// Whether the author named this one.
    ///
    /// Read where an element is about to be matched by its builder PATH: an
    /// element the author named is his to move, and adopting it for a path
    /// would take the name off it.
    var isManual: Bool {
        if case .manual = self { return true }

        return false
    }
}

/// One element as it currently stands on the C# side.
///
/// A class, not a struct: the differ carries the unchanged parts of the previous
/// tree straight into the next one, and shares them rather than copying.
final class RenderedNode {
    /// Who this element is. Fixed for as long as it stays in the tree.
    let id: ElementId

    /// The MAUI class C# made for it. A change here cannot be patched, so it
    /// forces a replace.
    var type: NodeType

    /// Every property C# has been told about, as it was told.
    var props: [Prop: PropValue]

    /// MAUI event name -> the handler id C# quotes back when it fires.
    ///
    /// Assigned once, when the element first handles that event, and kept for as
    /// long as it does. An element that is not part of a render's message keeps
    /// the ids C# already has - which is exactly why they cannot be per-render
    /// numbers.
    var events: [Event: Int]

    /// The path the builder took to write it - see `Node.key`, and `Differ.match`,
    /// which matches a child against the one that stood in the same PLACE IN THE
    /// SOURCE rather than at the same index.
    var key: String?

    /// The composed views this element was built by, outermost first: each
    /// one's type, the state boxes it owned under the paths they were found
    /// at, and what it was BUILT WITH.
    ///
    /// The boxes are what let a `@State` survive the view being rebuilt: next
    /// render, a view of the same type at the same identity hands its fresh
    /// boxes this render's storage, box by box under the same path. The
    /// inputs are what let the view NOT be rebuilt: the outermost one's are
    /// compared against the fresh view's, and a view built with the same
    /// inputs that read nothing that moved is carried whole. See
    /// Core/Stateful.swift.
    var views: [(
        type: String,
        boxes: [(path: String, box: StateBox)],
        inputs: [(path: String, input: Input)])]

    /// What stood in for this element's subtree - the node as its parent wrote
    /// it, build closure and all - kept so the clean walk can build the
    /// subtree again WITHOUT the parent having written it again.
    ///
    /// The closure captures the view value the parent built last time, whose
    /// inputs are therefore exactly what the parent last computed - and the
    /// clean walk only ever runs it while the parent is being left alone, so
    /// those inputs are current by construction. Nil for a plain element: its
    /// properties were written by whoever built it, and a change to them
    /// starts at that ancestor's own placeholder.
    var placeholder: Node?

    /// The composed view whose body wrote this element - what a bare
    /// container's content runs under when the clean walk builds it again,
    /// so `debugInfo()` in its braces still names the view. Nil for an
    /// element under no view.
    var view: String?

    /// The state this element's builds read, by storage identity - what
    /// decides, against the changes a render carries, whether the subtree is
    /// built again or carried over. See Core/Invalidation.swift.
    ///
    /// FIXED FOR THE LIFE OF THE ELEMENT, because the renderer counts this
    /// element as a READER of each of these for exactly as long as it lives -
    /// said as it is made, taken back in `deinit` - and a set that moved in
    /// between would leave that count wrong. A build that read something
    /// else is a new element, which is what `element()` makes.
    let reads: Set<ObjectIdentifier>

    /// How many times this element has been described since it entered the
    /// tree - what `debugInfo()` answers with, and the one thing that says
    /// whether a view is being rebuilt by a scroll it has no part in. Carried
    /// along the element, so a render that leaves it alone leaves it standing.
    /// See Core/Builds.swift.
    var builds: Int

    /// What this element PROVIDED to its subtree - the objects `.environment()`
    /// put on its node and on the content it unwrapped to. The clean walk
    /// pushes these as it descends, so a view rebuilt deep under clean
    /// ancestors resolves exactly what a full build would hand it.
    var provided: [(key: ObjectIdentifier, object: AnyObject)]

    /// The environments VISIBLE when the composed view here was built - per
    /// type, the nearest object's identity. A view's inputs say what it was
    /// built with; they say nothing about a provider above replacing its
    /// object, so the carry compares this too. See Core/Environment.swift.
    var seen: [ObjectIdentifier: ObjectIdentifier]

    /// What this element's `.onChanged` values were last time it was built, in
    /// the order they were written.
    ///
    /// The values themselves rather than the watches: the closures belong to
    /// the render that wrote them, and what has to outlive a render is only
    /// what the next one compares against. See Core/Changes.swift.
    var watched: [Any]

    /// What this element's `.onDestroying` runs as it leaves the tree - the
    /// closures its last build wrote, so the ones that run are the newest.
    /// See Core/Lifetime.swift.
    var destroying: [EventHandler] = []

    /// What the element holds for its life - its session, where it asked for
    /// one - handed back to every build after the first. See
    /// Core/ElementSession.swift.
    var session: AnyObject?

    /// The numbers this element's engines are registered under, in the order
    /// they were written.
    ///
    /// The ids rather than the arithmetic: what a cycle runs lives on the
    /// BOARD, and what has to outlive a render is only the number that names
    /// it - so a render rewrites the closure it already has a number for, and
    /// an element leaving the tree hands the numbers back. A different COUNT
    /// is a different set of engines and starts over. See Core/Cycle.swift.
    var engines: [Int] = []

    /// The properties this element has driven to a state, as the host was told
    /// them - which is what a render is compared against, so a registration
    /// that did not change costs nothing. See Core/StateValue.swift.
    var driven: [Prop: StateEntry] = [:]

    /// The readings `.samples(_:into:_:)` asked for HERE, held - which is the
    /// whole of how long one lives.
    ///
    /// The value being read knows them weakly, so a reading ends exactly when
    /// this element does: the view leaves the tree, the element is released,
    /// and the reading with it - the same sentence `engines` makes, where the
    /// numbers go back at `Diff.forget(_:)`. An element that takes one over
    /// holds the same object, so a rebuild hands it on rather than starting
    /// its window again. See Core/Sampling.swift.
    let readings: [Sampling]

    /// The elements under it, in the order C# has them.
    var children: [RenderedNode]

    /// What this element's subtree LOOKS like, values left out - filled in
    /// only for the children of a layout that recycles, and zero everywhere
    /// else. Kept so the next render can tell whether the shape MOVED, a row
    /// that starts writing a conditional property being a row the pool must
    /// stop offering to the rows that do not. See Core/Recycling.swift.
    var shape: UInt64 = 0

    /// Whether this element's children are recycled - `Node.recycles`, kept
    /// so the flag is sent when it changes rather than on every patch.
    var recycles = false

    /// How this element's children were last told to travel when it places
    /// them - what a change is compared against, so an unchanged one is not
    /// said again. Nil until it has ever been said.
    var motion: Motion?

    /// And which parts of a child's place travelled, for the same reason.
    var lanes: MotionLanes = .all

    /// One element as C# currently has it. Built by the differ, never by hand.
    init(
        id: ElementId,
        type: NodeType,
        props: [Prop: PropValue],
        events: [Event: Int],
        recycles: Bool = false,
        motion: Motion? = nil,
        lanes: MotionLanes = .all,
        key: String? = nil,
        views: [(
            type: String,
            boxes: [(path: String, box: StateBox)],
            inputs: [(path: String, input: Input)])] = [],
        placeholder: Node? = nil,
        view: String? = nil,
        reads: Set<ObjectIdentifier> = [],
        builds: Int = 1,
        provided: [(key: ObjectIdentifier, object: AnyObject)] = [],
        seen: [ObjectIdentifier: ObjectIdentifier] = [:],
        watched: [Any] = [],
        engines: [Int] = [],
        driven: [Prop: StateEntry] = [:],
        readings: [Sampling] = [],
        children: [RenderedNode]
    ) {
        self.recycles = recycles
        self.motion = motion
        self.lanes = lanes
        self.views = views
        self.placeholder = placeholder
        self.view = view
        self.reads = reads
        self.builds = builds
        self.provided = provided
        self.seen = seen
        self.watched = watched
        self.engines = engines
        self.driven = driven
        self.readings = readings
        self.id = id
        self.type = type
        self.props = props
        self.events = events
        self.key = key
        self.children = children

        // A reader of what it read, for as long as it lives - see `reads`.
        // Only an element that read anything is counted, which spares every
        // bare container the trip through the renderer's lock.
        if !reads.isEmpty {
            Renderer.shared.reading(reads)
        }

        // And one of the living, for the tally's `alive` column.
        Renderer.shared.nodeBorn()
    }

    deinit {
        if !reads.isEmpty {
            Renderer.shared.unreading(reads)
        }

        Renderer.shared.nodeGone()
    }
}

extension HostPatch {
    /// True when this patch says nothing beyond naming the element, in which
    /// case its parent leaves it out of the message entirely.
    ///
    /// `transitions` is not asked about: a transition names a property in
    /// `properties`, so a patch with one always has that property too, and a
    /// patch carrying nothing but a transition would name a property it is
    /// not sending - which is a bug, not a message.
    ///
    /// `driven` COUNTS, an emptied set included: a driven modifier writes
    /// nothing into `properties`, so a child whose only change is which states it
    /// ties - a conditional `.opacity($fade)` dropped, one state swapped for
    /// another under one property - has no other field to be heard by, and
    /// the empty set is the message that unties. Held by
    /// `CarriedStateTests.testADrivenModifierDroppedFromAChildUntiesIt`.
    var isEmpty: Bool {
        !replace
            && motion == nil
            && properties.isEmpty
            && clearedProperties.isEmpty
            && events == nil
            && shape == nil
            && recycles == nil
            && driven == nil
            && !children.hasChange
    }

    /// This patch followed by a later one about the same element - the one
    /// message the host would have applied the two as, the later winning
    /// wherever both say something about the same thing.
    ///
    /// What a render sends when the handlers it ran wrote state before its
    /// message left: its own patch, then the walk of what they wrote. The
    /// later patch was worked out against the tree the earlier one left, so
    /// every element it names is one the earlier one brought, changed or left
    /// standing. See `Renderer.renderWire`.
    ///
    /// - Parameter later: the later patch.
    func merging(_ later: HostPatch) -> HostPatch {
        // Built again, and complete when it says so.
        if later.replace {
            return later
        }

        var merged = self

        // An element this message BRINGS arrives at its values: nothing
        // travels to them and nothing is cleared, what is not in its patch
        // never having been set.
        for (prop, value) in later.properties {
            merged.properties[prop] = value
            merged.transitions[prop] = fresh ? nil : later.transitions[prop]
            merged.clearedProperties.removeAll { $0 == prop }
        }

        for prop in later.clearedProperties {
            merged.properties[prop] = nil
            merged.transitions[prop] = nil

            if !fresh, !merged.clearedProperties.contains(prop) {
                merged.clearedProperties.append(prop)
            }
        }

        merged.clearedProperties.sort()

        merged.motion = later.motion ?? motion
        merged.driven = later.driven ?? driven
        merged.events = later.events ?? events
        merged.shape = later.shape ?? shape
        merged.recycles = later.recycles ?? recycles
        merged.children = HostChildrenUpdate.merging(children, with: later.children)

        return merged
    }
}

extension HostChildrenUpdate {
    /// Whether this value carries any child update. An empty arrangement still
    /// counts because it removes every child.
    var hasChange: Bool {
        switch self {
        case .unchanged:
            false
        case .changed(let patches):
            !patches.isEmpty
        case .arranged:
            true
        }
    }

    /// The child patches in this update, independent of whether they are sparse
    /// or a complete arrangement.
    var patches: [HostPatch] {
        switch self {
        case .unchanged:
            []
        case .changed(let patches), .arranged(let patches):
            patches
        }
    }

    /// The children of two patches about one element: the later list where
    /// it is ARRANGED, being the whole list in order, each child merged with
    /// what the earlier one said about it - and otherwise the earlier list,
    /// with each child the later one names merged in by its identity.
    fileprivate static func merging(
        _ earlier: HostChildrenUpdate,
        with later: HostChildrenUpdate
    ) -> HostChildrenUpdate {
        switch later {
        case .unchanged:
            return earlier

        case .arranged(let laterPatches):
            let earlierPatches = earlier.patches
            return .arranged(laterPatches.map { child in
                earlierPatches.first { $0.id == child.id }
                    .map { $0.merging(child) } ?? child
            })

        case .changed(let laterPatches):
            var merged = earlier.patches

            for child in laterPatches {
                if let at = merged.firstIndex(where: { $0.id == child.id }) {
                    merged[at] = merged[at].merging(child)
                } else {
                    // A sparse list names only children that stand, and an
                    // arranged earlier list holds every child that does.
                    if case .arranged = earlier {
                        assertionFailure(
                            "a later patch names a child the earlier arrangement has not got")
                    }
                    merged.append(child)
                }
            }

            if case .arranged = earlier {
                return .arranged(merged)
            }

            return .changed(merged)
        }
    }
}
