// How `@State` on a view survives the view being rebuilt.
//
// A composed view - a ContentView, a ContentPage - is a value, rebuilt on every
// render, so a `@State` declared on one comes back as a fresh box holding the
// initial value. What makes the state survive anyway is done here, in two
// halves:
//
//   1. The view's body is not built when the tree is written. It goes into the
//      tree as a PLACEHOLDER carrying the view's type, its state boxes, and a
//      closure that builds the real subtree.
//
//   2. The differ, on reaching the placeholder, knows the element's identity -
//      which the tree alone never does - and whether the same KIND of view
//      stood there last render. If it did, the fresh boxes adopt the old ones'
//      storage (State.adopt), and only THEN is the subtree built, so everything
//      the body reads sees the surviving values.
//
// Same identity, same view type, same state - the rule the differ already
// applies to controls (same identity, same control), one level up. A different
// view type at the same position starts over, exactly as a different control
// type replaces the control.
//
// The boxes are found by reflection, ONCE per placeholder, walking the view's
// stored properties. Reflection is otherwise banned in this project because of
// trimming on the C# side; this is Swift's own Mirror over Swift values, which
// trimming never sees.

/// What the differ needs to know about any state box, without knowing the
/// value's type: that it can adopt another box's storage.
protocol StateBox: AnyObject {
    /// Takes over `other`'s storage when it is a box of the same value type;
    /// does nothing when it is not.
    func adopt(from other: AnyObject)
}

/// Marks a wrapper whose state is OWNED elsewhere - `Binding`.
///
/// The box collector stops at one: the storage behind a borrowed value belongs
/// to whoever lent it, survives on its owner, and must never be adopted as if
/// the borrowing view owned it.
protocol BorrowedState {}

/// Every state box a view owns, in declaration order.
///
/// Declaration order is what pairs a box with its predecessor: two instances of
/// the same view type mirror their stored properties in the same order, which
/// is why adoption can go by position - and why it is guarded by the view TYPE
/// matching first.
///
/// The walk recurses through structs, enums and collections, because a view
/// may keep another view - and with it, that view's state - in a stored
/// property. It stops at a `Binding` (borrowed, owned elsewhere), at a `Node`
/// (built interface, never a state owner), and at any other class (a reference
/// keeps itself alive; whatever state it holds does not need rescuing).
func stateBoxes(in value: Any) -> [StateBox] {
    stateParts(in: value).boxes
}

/// Every state box AND every `@Environment` slot a view owns, one walk for
/// both: the boxes are adopted, the slots are filled from the differ's scope
/// before the body builds. See Core/Environment.swift for the slots' half.
func stateParts(in value: Any) -> (boxes: [StateBox], slots: [EnvironmentSlot]) {
    var boxes: [StateBox] = []
    var slots: [EnvironmentSlot] = []
    collectStateParts(in: value, boxes: &boxes, slots: &slots)
    return (boxes, slots)
}

private func collectStateParts(
    in value: Any,
    boxes: inout [StateBox],
    slots: inout [EnvironmentSlot]
) {
    if let box = value as? StateBox {
        boxes.append(box)
        return
    }

    if let slot = value as? EnvironmentSlot {
        slots.append(slot)
        return
    }

    if value is BorrowedState || value is Node {
        return
    }

    let mirror = Mirror(reflecting: value)

    if mirror.displayStyle == .class {
        return
    }

    for child in mirror.children {
        collectStateParts(in: child.value, boxes: &boxes, slots: &slots)
    }
}

extension Node {
    /// A subtree nobody has built yet, and what it takes to build it right.
    struct Stateful {
        /// The composed view's Swift type, module-qualified. What decides
        /// whether last render's state is this view's to keep.
        let viewType: String

        /// The state boxes the freshly built view owns, in declaration order.
        let boxes: [StateBox]

        /// The `@Environment` slots the view declares, filled from the scope
        /// of provided objects BEFORE the body builds - so the body and every
        /// handler that captured the view read a resolved object. See
        /// Core/Environment.swift.
        let slots: [EnvironmentSlot]

        /// Builds the subtree. Called by the differ, AFTER the boxes have
        /// adopted their predecessors' storage - never before, or the body
        /// would read initial values.
        let build: () -> Node

        /// Fills every slot with the nearest provided object of its type.
        /// A type nobody provided leaves its slot alone, and the READ is what
        /// says so - a structural expansion has no providers to offer.
        func resolve(from scope: [(key: ObjectIdentifier, object: AnyObject)]) {
            for slot in slots {
                if let found = scope.last(where: { $0.key == slot.wants }) {
                    slot.fill(found.object)
                }
            }
        }

        /// Builds the subtree and lands what the author wrote ON the view -
        /// modifiers, handlers, an id - on what the view is made of.
        func expand(over written: Node) -> Node {
            var node = build()
            node.props.merge(written.props) { _, wrote in wrote }

            // With the properties, because an arm belongs to the property it
            // was written beside: `MyRow().opacity($fade)` writes both onto
            // the placeholder, and carrying only the value would leave the
            // flight with nothing to move - the same silence the slot below
            // records.
            node.armed.merge(written.armed) { _, wrote in wrote }

            for (name, handler) in written.events.sorted(by: { $0.key < $1.key }) {
                node.addHandler(name, handler)
            }

            // What the view was made of first, what was written ON it after -
            // one order, held to on every render, which is all the pairing of
            // a watch with its predecessor asks for. See Core/Changes.swift.
            node.watches += written.watches

            // And the same for a SLOT written on the view - a `.contextFlyout`,
            // which is a child rather than a property. Appended, so what the
            // view is made of keeps the positions it was built with. Without
            // this the modifier compiles, renders nothing and says nothing,
            // which is the one failure this library refuses to ship.
            node.children += written.children

            node.id = written.id ?? node.id
            node.key = written.key ?? node.key
            return node
        }
    }

    /// This node with every placeholder built, recursively - WITHOUT any state
    /// carried over, since there is no previous render to carry it from.
    ///
    /// For tests that read a tree structurally. Rendering never comes here: the
    /// differ expands each placeholder itself, after deciding whose state it
    /// holds.
    ///
    /// BOTH kinds of placeholder, and the memo is the one easy to forget. A
    /// `.memoized(by:)` subtree is a token and a closure until the differ asks
    /// for it, so a test reading the tree would otherwise find an empty node
    /// where a whole page hangs - and would say the page was missing rather than
    /// that it had not been asked for.
    ///
    /// Seeded with the STANDARD providers, exactly as every differ walk is -
    /// so a view reading `@Environment var device: DeviceInfo` expands
    /// structurally too, answering the headless defaults.
    var built: Node { built(within: StandardEnvironment.scope) }

    /// The same, resolving `@Environment` from `scope` - the differ's stack,
    /// stood in for by an array, so a structural read sees exactly what a
    /// render at this position would.
    func built(within scope: [(key: ObjectIdentifier, object: AnyObject)]) -> Node {
        var node = self
        var scope = scope
        scope.append(contentsOf: node.environments)

        while true {
            if let stateful = node.stateful {
                stateful.resolve(from: scope)
                node = stateful.expand(over: node)
                scope.append(contentsOf: node.environments)
                continue
            }

            if let memo = node.memo {
                var expanded = memo.build()
                expanded.props.merge(node.props) { _, wrote in wrote }
                expanded.armed.merge(node.armed) { _, wrote in wrote }
                expanded.watches += node.watches
                expanded.children += node.children
                expanded.id = node.id ?? expanded.id
                expanded.key = node.key ?? expanded.key
                node = expanded
                scope.append(contentsOf: node.environments)
                continue
            }

            break
        }

        node.children = node.children.map { $0.built(within: scope) }
        return node
    }

    /// A placeholder for a composed view, expanded by the differ.
    ///
    /// The type name never reaches the host - the differ always expands the
    /// placeholder before anything is sent - but if a bug ever let it through,
    /// the host would draw its red unknown-type marker naming it, which is the
    /// diagnosable failure this project prefers.
    static func composed(_ view: Any, type: String, build: @escaping () -> Node) -> Node {
        var node = Node(type: .composed)
        let parts = stateParts(in: view)
        node.stateful = Stateful(
            viewType: type, boxes: parts.boxes, slots: parts.slots, build: build)
        return node
    }
}
