// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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

    /// The storage this box holds - what says, after adoption, whether a box
    /// at a path the previous render answered is the same state. See
    /// `Input.box`.
    var lender: AnyObject { get }

    /// Says what the author calls this state - the path the walk below
    /// reached it by, which is the property's own name. Kept so a render can
    /// be explained in those names. See Core/Builds.swift.
    func named(_ path: String)
}

extension StateBox {
    /// A box whose state cannot be named answers to nothing, which is what a
    /// borrowed value and a class of the author's own both are.
    func named(_ path: String) {}
}

/// Marks a wrapper whose state is OWNED elsewhere - `Binding`, the borrowed
/// form.
///
/// The box collector stops at one: the storage behind a borrowed value belongs
/// to whoever lent it, survives on its owner, and must never be adopted as if
/// the borrowing view owned it. Stopping by the MARK rather than by the shape
/// of the wrapper is what keeps that true whatever fields the wrapper gains.
protocol BorrowedState {
    /// What the wrapper borrows from - the storage behind a whole `@State`
    /// and which part of it, or nothing for a binding made from closures.
    /// What `Input.borrowed` compares: the storage, never the value, which is
    /// the storage's own business. See `Input`.
    var lends: (lender: AnyObject?, lent: AnyHashable?) { get }
}

/// One stored property of a composed view, as far as the differ can see it.
///
/// WHAT A VIEW WAS BUILT WITH is what decides, beside what it read, whether it
/// is described again or CARRIED - subtree, state and handlers untouched -
/// when its parent's closure runs again. The parent constructs a fresh view
/// value every time; these are that value's stored properties, each compared
/// the one way it can be:
///
/// - a value by equality;
/// - a lent state (`@Binding`) by the STORAGE it lends, never by the value in
///   it - a body that reads through the binding is that storage's reader,
///   and is built again by the reader rule when the storage moves;
/// - a state the view owns (`@State`) by the storage it holds after adoption,
///   so a box at a path the previous render answered is the same state;
/// - an `@Environment` slot by the object it resolves to;
/// - an object by identity - what it holds that a body should see is
///   `@State` on it, with readers of its own;
/// - and a closure, a built node, or anything else with no way to be compared
///   NEVER: an opaque input is a changed one, and the view is built as it
///   always was.
///
/// The comparison errs toward BUILDING, the direction every other piece of
/// invalidation errs in: what it cannot see through, it does not assume. A
/// container of values also records how many parts it has, so two collections
/// of different length differ even where every pair compared so far agreed.
enum Input {
    /// A value that says whether it equals another.
    case value(any Equatable)

    /// An object, by identity.
    case reference(ObjectIdentifier)

    /// A state lent to the view: the storage it lends, and which part of it.
    case borrowed(ObjectIdentifier, AnyHashable?)

    /// A state the view owns, compared by the storage it holds - AFTER
    /// adoption, which is when the box knows.
    case box(StateBox)

    /// An `@Environment` slot, compared by what it resolved to.
    case slot(EnvironmentSlot)

    /// How many parts a container of values has.
    case parts(Int)

    /// A closure, a built node, anything nothing can compare.
    case opaque

    /// Whether every input matches its predecessor, path for path.
    static func same(
        _ fresh: [(path: String, input: Input)],
        _ kept: [(path: String, input: Input)]
    ) -> Bool {
        guard fresh.count == kept.count else { return false }

        for (now, then) in zip(fresh, kept) {
            guard now.path == then.path, matches(now.input, then.input) else { return false }
        }

        return true
    }

    /// The first input that does not match its predecessor, named by its
    /// property - what an inspector gives as the reason a view was built
    /// rather than carried. Nothing where every one matches.
    static func difference(
        _ fresh: [(path: String, input: Input)],
        _ kept: [(path: String, input: Input)]
    ) -> String? {
        guard fresh.count == kept.count else { return "set of properties" }

        for (now, then) in zip(fresh, kept) where now.path != then.path
            || !matches(now.input, then.input) {
            let name = BuildScope.readable(now.path)

            if case .opaque = now.input {
                return "\(name), which cannot be compared"
            }

            return name
        }

        return nil
    }

    /// Whether one input matches its predecessor.
    private static func matches(_ now: Input, _ then: Input) -> Bool {
        switch (now, then) {
        case let (.value(a), .value(b)):
            return equal(a, b)
        case let (.reference(a), .reference(b)):
            return a == b
        case let (.borrowed(a, partA), .borrowed(b, partB)):
            return a == b && partA == partB
        case let (.box(a), .box(b)):
            return a.lender === b.lender
        case let (.slot(a), .slot(b)):
            return a.filled === b.filled
        case let (.parts(a), .parts(b)):
            return a == b
        default:
            return false
        }
    }

    /// Equality across the existential - opened on the first value's type,
    /// which is the type both have where the two are the same property.
    private static func equal(_ a: any Equatable, _ b: any Equatable) -> Bool {
        func open<Value: Equatable>(_ a: Value) -> Bool {
            (b as? Value).map { $0 == a } ?? false
        }

        return open(a)
    }
}

/// Every state box AND every `@Environment` slot a view owns, one walk for
/// both: the boxes are adopted, the slots are filled from the differ's scope
/// before the body builds. See Core/Environment.swift for the slots' half.
///
/// Each box comes back under the PATH the walk reached it by - the stored
/// property's name at every level, the branch a keyed child came from, and the
/// TYPE of any view stored along the way. That path is what pairs a box with
/// its predecessor next render, and it is why a slot that fills - an
/// `Element?` going from nil to a view - moves nothing else: the newcomer's
/// path is one nothing answered last render, so it starts at its initial value
/// and every other box keeps its own.
///
/// The walk recurses through structs, enums and collections, because a view
/// may keep another view - and with it, that view's state - in a stored
/// property. It stops at a `Binding` (borrowed, owned elsewhere), at a `Node`
/// (built interface, never a state owner), and at any other class (a reference
/// keeps itself alive; whatever state it holds does not need rescuing).
func stateParts(
    in value: Any
) -> (
    boxes: [(path: String, box: StateBox)],
    slots: [EnvironmentSlot],
    inputs: [(path: String, input: Input)]
) {
    var boxes: [(path: String, box: StateBox)] = []
    var slots: [EnvironmentSlot] = []
    var inputs: [(path: String, input: Input)] = []
    collectStateParts(in: value, at: "", boxes: &boxes, slots: &slots, inputs: &inputs)
    return (boxes, slots, inputs)
}

private func collectStateParts(
    in value: Any,
    at path: String,
    boxes: inout [(path: String, box: StateBox)],
    slots: inout [EnvironmentSlot],
    inputs: inout [(path: String, input: Input)]
) {
    if let box = value as? StateBox {
        boxes.append((path: path, box: box))
        box.named(path)
        inputs.append((path: path, input: .box(box)))
        return
    }

    if let slot = value as? EnvironmentSlot {
        slots.append(slot)
        inputs.append((path: path, input: .slot(slot)))
        return
    }

    // A borrowed state is compared by what it borrows FROM, and a binding
    // made from closures borrows from nothing anybody can name.
    if let borrowed = value as? BorrowedState {
        let lends = borrowed.lends
        inputs.append((
            path: path,
            input: lends.lender.map { .borrowed(ObjectIdentifier($0), lends.lent) } ?? .opaque))
        return
    }

    // A built node is interface, never state - and what it describes is
    // whatever closure built it, which nothing can compare.
    if value is Node {
        inputs.append((path: path, input: .opaque))
        return
    }

    // A keyed element carries the BRANCH of the builder it was written in,
    // which says more about where it is than the wrapper's own two stored
    // properties do: both arms of an `if` are the same property holding
    // different views, and the segment is what tells them apart. The TYPE of
    // the view inside still matters beside it: one branch can hold another
    // view each render through a type-erased factory, and the type is what
    // starts the newcomer at its own initial value.
    if let keyed = value as? Keyed {
        collectStateParts(
            in: keyed.element,
            at: "\(path).\(keyed.segment)\(storedViewType(of: keyed.element))",
            boxes: &boxes,
            slots: &slots,
            inputs: &inputs)
        return
    }

    // A value that can say whether it equals another is compared whole -
    // an array of items by its own `==`, never element by element through
    // the mirror.
    if let comparable = value as? any Equatable {
        inputs.append((path: path, input: .value(comparable)))
        return
    }

    let mirror = Mirror(reflecting: value)

    // A reference keeps itself alive, and whatever state it holds does not
    // need rescuing; as an input it is the object it is.
    if mirror.displayStyle == .class {
        inputs.append((path: path, input: .reference(ObjectIdentifier(value as AnyObject))))
        return
    }

    let children = Array(mirror.children)

    // A leaf the mirror cannot open is a closure, a metatype or the like:
    // nothing to compare, so it counts as changed. A struct or an enum with
    // nothing in it is the one value it can be.
    if children.isEmpty {
        inputs.append((path: path, input: mirror.displayStyle == nil ? .opaque : .parts(0)))
        return
    }

    inputs.append((path: path, input: .parts(children.count)))

    // A collection's children have no labels, so their position stands in -
    // which is all a position ever has to be here, the elements of one array
    // being one property's contents rather than separate declarations.
    for (offset, child) in children.enumerated() {
        collectStateParts(
            in: child.value,
            at: "\(path).\(child.label ?? String(offset))\(storedViewType(of: child.value))",
            boxes: &boxes,
            slots: &slots,
            inputs: &inputs)
    }
}

/// The type of a stored VIEW, in brackets after the property holding it, and
/// nothing at all for anything else.
///
/// A slot holding a view is the one place a path built from names alone would
/// lie: the same property holds one view this render and another the next, and
/// a path naming only the property would hand the newcomer its predecessor's
/// state. Naming the type makes the two paths two, which is what starts the
/// newcomer at its initial value. Module-qualified, as the composed view's own
/// `viewType` is - two modules can export one name.
private func storedViewType(of value: Any) -> String {
    value is Element ? "(\(String(reflecting: type(of: value))))" : ""
}

extension Node {
    /// A subtree nobody has built yet, and what it takes to build it right.
    struct Stateful {
        /// The composed view's Swift type, module-qualified. What decides
        /// whether last render's state is this view's to keep.
        let viewType: String

        /// The state boxes the freshly built view owns, each under the path
        /// the reflection walk reached it by - what pairs it with the box the
        /// same path held last render.
        let boxes: [(path: String, box: StateBox)]

        /// The `@Environment` slots the view declares, filled from the scope
        /// of provided objects BEFORE the body builds - so the body and every
        /// handler that captured the view read a resolved object. See
        /// Core/Environment.swift.
        let slots: [EnvironmentSlot]

        /// What the view was built with - its stored properties, each as far
        /// as the differ can see it - compared against the previous render's
        /// to decide whether the body is built or the subtree carried. See
        /// `Input`.
        let inputs: [(path: String, input: Input)]

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

            // And the STATES driven to it, for the same reason again: a
            // `.opacity($fade)` on a composed view is about the view, and a
            // registration left on the placeholder names a control nothing
            // holds - the property would simply never be written.
            node.driven.merge(written.driven) { _, wrote in wrote }

            // And how what the view is made of MOVES, for the same reason: a
            // `.motion(.none)` written on a composed view is about the view,
            // and a modifier that compiles, renders nothing and says nothing
            // is the one failure this library refuses to ship.
            node.motion = MotionPlan.merged(node.motion, under: written.motion)

            for (name, handler) in written.events.sorted(by: { $0.key < $1.key }) {
                node.addHandler(name, handler)
            }

            // What the view was made of first, what was written ON it after -
            // one order, held to on every render, which is all the pairing of
            // a watch with its predecessor asks for. See Core/Changes.swift.
            node.watches += written.watches

            // And the arithmetic written on it, in the same one order - an
            // engine on a composed view is registered against the element its
            // body ends on, which is the element the host holds.
            node.engines += written.engines

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

            break
        }

        node.materialize()
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
            viewType: type,
            boxes: parts.boxes,
            slots: parts.slots,
            inputs: parts.inputs,
            build: build)
        return node
    }
}
