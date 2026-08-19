// What the C# side is holding, and what it is about to be told.
//
// A Node is what an author wrote this render and is thrown away after it. These
// two types are the ones that persist:
//
//   RenderedNode  one element as it now stands on the C# side - its identity,
//                 its properties, the handler ids C# quotes back, its children
//   Patch         the difference between that and the tree just written, which
//                 is all that goes over the wire
//
// Keeping the first is what makes the second possible. Without it, "what
// changed" has no answer and the only correct message is the whole tree.

/// Identity of an element, stable for as long as the element lives.
///
/// The two cases are two namespaces that cannot collide, which is the point:
///
///   .auto     assigned by the renderer, written as a NUMBER
///   .manual   whatever the author passed to `.id()`, written as TEXT
///
/// An automatic identity survives a render as long as the element stays where it
/// is among its siblings. A manual one survives anywhere, which is what a
/// collection needs.
enum ElementId: Hashable {
    /// Assigned by the renderer, from position. Written as a number.
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

    /// What this element was last built from, when it was built by a memoized
    /// view. Unchanged means the subtree below is not built again - see
    /// Core/Memo.swift.
    var memo: AnyHashable?

    /// The composed views this element was built by, outermost first: each
    /// one's type, and the state boxes it owned.
    ///
    /// What lets a `@State` survive the view being rebuilt: next render, a view
    /// of the same type at the same identity hands its fresh boxes this
    /// render's storage. See Core/Stateful.swift.
    var views: [(type: String, boxes: [StateBox])]

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

    /// The state this element's builds read, by storage identity - what
    /// decides, against the changes a render carries, whether the subtree is
    /// built again or carried over. See Core/Invalidation.swift.
    var reads: Set<ObjectIdentifier>

    /// What this element PROVIDED to its subtree - the objects `.environment()`
    /// put on its node and on the content it unwrapped to. The clean walk
    /// pushes these as it descends, so a view rebuilt deep under clean
    /// ancestors resolves exactly what a full build would hand it.
    var provided: [(key: ObjectIdentifier, object: AnyObject)]

    /// The environments VISIBLE when a memoized subtree here was built - per
    /// type, the nearest object's identity. An unchanged memo token says the
    /// INPUTS are unchanged; it says nothing about a provider above replacing
    /// its object, so the skip compares this too. See Core/Environment.swift.
    var seen: [ObjectIdentifier: ObjectIdentifier]

    /// What this element's `.onChanged` values were last time it was built, in
    /// the order they were written.
    ///
    /// The values themselves rather than the watches: the closures belong to
    /// the render that wrote them, and what has to outlive a render is only
    /// what the next one compares against. See Core/Changes.swift.
    var watched: [Any]

    /// The elements under it, in the order C# has them.
    var children: [RenderedNode]

    /// One element as C# currently has it. Built by the differ, never by hand.
    init(
        id: ElementId,
        type: NodeType,
        props: [Prop: PropValue],
        events: [Event: Int],
        key: String? = nil,
        memo: AnyHashable? = nil,
        views: [(type: String, boxes: [StateBox])] = [],
        placeholder: Node? = nil,
        reads: Set<ObjectIdentifier> = [],
        provided: [(key: ObjectIdentifier, object: AnyObject)] = [],
        seen: [ObjectIdentifier: ObjectIdentifier] = [:],
        watched: [Any] = [],
        children: [RenderedNode]
    ) {
        self.memo = memo
        self.views = views
        self.placeholder = placeholder
        self.reads = reads
        self.provided = provided
        self.seen = seen
        self.watched = watched
        self.id = id
        self.type = type
        self.props = props
        self.events = events
        self.key = key
        self.children = children
    }
}

/// What changed about one element, and about the elements under it.
///
/// Every field is optional and every one is omitted when it did not change, so
/// an element that is only carrying the path down to a changed child is two
/// fields wide. The one rule the C# side reads it by: **a field that is not here
/// did not change**. An absent property is not a property that was unset - that
/// is what `replace` is for.
struct Patch {
    /// Which element this is about. Always sent - it is how C# finds the
    /// control.
    let id: ElementId

    /// Always sent. It costs the two bytes of its number from the session
    /// dictionary and makes every message say which MAUI class it is about,
    /// which is worth more than the bytes.
    let type: NodeType

    /// The control cannot be updated into what the node now says, so C# throws
    /// it away and builds it again from this patch - which is complete when this
    /// is set.
    ///
    /// Set when the MAUI type changed, or when a property the element carried
    /// last render is gone: the renderer assigns only what arrives, so a
    /// property that has GONE AWAY has nothing to overwrite it and would
    /// linger on the control.
    var replace = false

    /// Only the properties that changed. All of them when `replace` is set or
    /// the element is new.
    var props: [Prop: PropValue] = [:]

    /// The properties among `props` the host is to WALK to rather than
    /// assign, and how. Empty on almost every patch there ever is.
    ///
    /// A flown property is an ordinary property in every other respect: its
    /// target is in `props`, the differ compares it the way it compares
    /// anything, and a host that ignored this field would simply snap. What
    /// this adds is how long the walk takes, on what curve, and which
    /// completion the handler that started it is waiting on.
    var transitions: [Prop: Transition] = [:]

    /// The complete event map, sent only when the set of handled events changed.
    /// Handler ids are stable, so an unchanged set needs no message.
    var events: [Event: Int]?

    /// Whether `children` is the COMPLETE list, in order - sent exactly when
    /// the arrangement changed: something added, removed or moved.
    ///
    /// The list itself then carries everything a rearrangement needs: its
    /// order is the order, its length is the count, and an element absent
    /// from it has left - so there is no order field, no count and no removal
    /// list to keep in step with it. A child that merely stands where it
    /// stood rides along as a stub, its identity and type and nothing else.
    /// When this is false, `children` names only the children whose CONTENT
    /// changed, each found by its identity, and nothing else is touched.
    var arranged = false

    /// The children - all of them, in order, when `arranged`; only the
    /// changed ones otherwise.
    var children: [Patch] = []

    /// True when this patch says nothing beyond naming the element, in which
    /// case its parent leaves it out of the message entirely.
    ///
    /// `transitions` is not asked about: a transition names a property in
    /// `props`, so a patch with one always has that property too, and a
    /// patch carrying nothing but a transition would name a property it is
    /// not sending - which is a bug, not a message.
    var isEmpty: Bool {
        !replace
            && props.isEmpty
            && events == nil
            && !arranged
            && children.isEmpty
    }
}

/// How a property is MOVED rather than set: the host walks the control from
/// wherever it is now to the target sitting in the patch's `props`, and says
/// so on `channel` when it arrives.
///
/// One flight is one of these, however many properties and however many
/// controls it moves - a state armed on three views sends three transitions
/// carrying the same channel, and the handler is resumed once, when the last
/// of them is done.
struct Transition: Equatable, Sendable {
    /// How long the walk takes, in milliseconds.
    let length: UInt32

    /// The curve it walks on.
    let easing: Easing

    /// The completion the handler that started the flight is waiting on -
    /// one of the negative ids every act already answers on.
    let channel: Int32

    /// How many milliseconds apart the host is to REPORT where the walk has
    /// got to, or 0 when nobody asked. The cadence is stated by whoever
    /// started the flight; the frames themselves are the host's and are never
    /// what crosses.
    let report: UInt32
}
