// The UI tree that Swift produces and C# materializes into real MAUI controls.
//
// Swift cannot create MAUI objects: the P/Invoke boundary only carries types
// representable in C, while Label and Button are managed objects. So the Swift
// side DESCRIBES the interface and the C# side BUILDS it - the split that
// makes a declarative Swift API possible.
//
// A Node is deliberately dumb: a type name, a bag of properties, child nodes,
// and event handlers. The type name is the MAUI class name ("Label",
// "VerticalStackLayout"), and every property key is the MAUI property name in
// camelCase ("fontSize", "horizontalOptions"). Nothing is translated in between,
// so what crosses the wire reads like the MAUI object it becomes.
//
// A node is what an author WROTE, this render. It carries no identity of its own
// beyond an optional `id`, and no handler ids: those belong to the element the
// node describes, which outlives the node. Diff.swift matches the two up.

/// A single property value. Restricted to what crosses the boundary cleanly,
/// one arm per kind of thing the wire carries.
///
/// Equatable because that is how a change is detected: the differ compares each
/// value against the one the C# side already has, and sends only what differs.
public enum PropValue: Equatable, Sendable {
    /// TEXT SOMEONE WROTE - a label's words, a placeholder, a url, an SVG
    /// path, a .NET format string. Nothing else: a closed vocabulary is
    /// `.enumeration`, a name is `.name`, and a value with parts is
    /// `.values`. Keeping those apart is what lets the far side read a value
    /// as the thing it is, with nothing to parse and nothing to guess.
    case string(String)

    /// One member of a CLOSED vocabulary, as its NUMBER - `.tailTruncation`,
    /// `.bold`, `.cubicOut`. Whose numbers those are, and why, is the head of
    /// Types/Enums.swift.
    ///
    /// A bit set - FontAttributes, TextDecorations, AbsoluteLayoutFlags,
    /// SwipeDirection - is one of these too, carrying its bits.
    ///
    /// `Int32` rather than a Double because that is what the wire's
    /// enumeration tag carries and what a C# enum reads back as.
    case enumeration(Int32)

    /// NOTHING - a value that is not there, said out loud.
    ///
    /// A property that did not change is ABSENT from a node, which is how the
    /// wire says unchanged and needs no value. But a POSITION cannot be
    /// absent: an act's third argument and the second element of a value
    /// list are found by counting, so "there is no destructive button" and
    /// "there is no base url" each need a value that says so. This is that
    /// value, and the only one - an empty string, a -1 or an empty list would
    /// each be indistinguishable from something someone meant.
    case nothing

    /// A NAME from an OPEN vocabulary - a style key, a visual state, a font
    /// family, a radio group. Text an author wrote, but a name rather than
    /// prose: it repeats across a tree and means the same thing every time,
    /// so it rides the SESSION's dictionary as its number exactly as a
    /// property key does, announced once and two bytes thereafter.
    case name(String)

    /// A number. Everything numeric travels as a Double; the renderer narrows it
    /// where MAUI wants an Int.
    case number(Double)

    /// True or false.
    case bool(Bool)

    /// A fixed-length list of numbers. Used by the structured value types - a
    /// Thickness travels as left, top, right, bottom.
    case numbers([Double])

    /// A list of strings. What a Picker is given to choose from.
    case strings([String])

    /// A colour, as the four channels it is - each 0 to 255, sRGB, alpha
    /// included. Four bytes on the wire and no parser on the far side; the
    /// theme has already been resolved by the time one is made, so a colour
    /// is one value however it was written. See Types/Color.swift.
    case color(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)

    /// A list of values of any kind - what a structured value travels as when
    /// its parts are not all the same shape. A Brush is the one that needs it:
    /// a kind, its geometry, and a colour per stop. See Types/Brush.swift.
    case values([PropValue])

    /// The text, when this value is text - nil for any other kind. What an
    /// `onEvent` handler reads an Entry's new text with, and what the few
    /// places that read a property back off a node use.
    public var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// The number, when this value is one - nil for any other kind, so a
    /// reader never mistakes text for a quantity.
    public var number: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    /// The member's number, when this value is one of a closed vocabulary -
    /// nil for any other kind, including a plain number, so nothing reads a
    /// font size as an alignment.
    public var enumeration: Int32? {
        if case .enumeration(let value) = self { return value }
        return nil
    }

    /// The name, when this value is one - nil for any other kind, including
    /// text. A reader that wants either asks for both; they are different
    /// things and the wire keeps them apart.
    public var name: String? {
        if case .name(let value) = self { return value }
        return nil
    }

    /// The number as a whole one, when this value is a number - what an index
    /// or a position payload is read with. Rounds nothing: 2.0 answers 2, and
    /// text answers nil.
    public var int: Int? {
        if case .number(let value) = self { return Int(value) }
        return nil
    }

    /// True or false, when this value is one - nil for any other kind.
    public var bool: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// The list of numbers, when this value is one - a frame report's eight
    /// coordinates, a selection's positions, a point's pair.
    public var numbers: [Double]? {
        if case .numbers(let value) = self { return value }
        return nil
    }

    /// The list of strings, when this value is one - what a Picker is given to
    /// choose from.
    public var strings: [String]? {
        if case .strings(let value) = self { return value }
        return nil
    }

    /// The four channels, when this value is a colour - nil for any other
    /// kind, so nothing mistakes a number for one.
    public var color: (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
        if case .color(let red, let green, let blue, let alpha) = self {
            return (red: red, green: green, blue: blue, alpha: alpha)
        }
        return nil
    }

    /// The values, when this value is a list of them - see `.values`.
    public var values: [PropValue]? {
        if case .values(let value) = self { return value }
        return nil
    }
}

extension [PropValue] {
    /// The value at `index`, or nil when the payload is shorter - so a
    /// payload that does not carry what a reader expects leaves the reader
    /// alone, which is the rule every typed event modifier follows.
    ///
    ///     .onEvent(.panUpdated) { payload in
    ///         let totalX = payload.value(1)?.number
    ///     }
    public func value(_ index: Int = 0) -> PropValue? {
        indices.contains(index) ? self[index] : nil
    }
}

/// What an event runs. MAUI: EventHandler.
///
/// May await, and usually does not:
///
///     Button("Save").onClicked { saved = true }
///     Button("Open").onClicked { path.append(.details) }
///
/// A handler that never awaits finishes before the event returns to the host.
/// One that does await resumes on the thread MAUI draws on, a turn later - see
/// Core/MainThread.swift.
///
/// `nonisolated(nonsending)` is what makes that true: it says the handler runs on
/// its CALLER's executor, which is `@MainThread`. Written as a plain
/// `() async -> Void` it would run on Swift's cooperative pool instead, next to a
/// render that assumes it is alone.
///
/// Throwing is allowed so that `try await` reads without a `do` around it. What
/// escapes is reported to the host rather than lost - see Renderer.dispatch.
public typealias EventHandler = nonisolated(nonsending) () async throws -> Void

/// The same, for an event that carries a value. MAUI: EventHandler<TEventArgs>.
///
///     Entry("").onTextChanged { text in query = text }
///
/// Not called `EventHandler` too, as it is in MAUI: Swift will not tell two
/// typealiases of the same name apart by how many type parameters they take.
public typealias ValueEventHandler<Value> = nonisolated(nonsending) (Value) async throws -> Void

/// One element of the UI tree: a MAUI class name, a bag of properties, the
/// children under it, and what its events run.
///
/// Every control in this library ends up as one, and a `Node` is itself an
/// `Element`, so one written by hand goes into any builder. That is how an
/// application describes a control it REGISTERED with the host
/// (`StateUIControls.Add`), and how a property this library has no modifier
/// for yet is set on a control it does describe:
///
///     extension NodeType {
///         static let trafficLight = NodeType("Gallery.TrafficLight")
///     }
///
///     Node(type: .trafficLight, props: ["state": .enumeration(0)])
///
/// The host matches on the type NAME, and a name it has neither a case nor a
/// registration for draws the unknown-control marker. So this reaches a
/// registered control and the ones the library already knows - not a MAUI
/// class nothing on the far side has been taught to build.
///
/// It is what an author WROTE, this render. It carries no identity of its own
/// beyond `id` and no handler ids: those belong to the element the node
/// describes, which outlives the node.
public struct Node {
    /// What kind of element this is - MAUI's class name as a token, e.g.
    /// `.label`, `.verticalStackLayout`, or an application's own. Matched by
    /// the renderer.
    public var type: NodeType

    /// Who this element is, when the author says so - `.id("row-7")`.
    ///
    /// An element that keeps its identity between renders keeps its CONTROL, and
    /// with it focus, caret position and scroll offset. Anything without one is
    /// identified by its position among its siblings, which is right for a fixed
    /// layout and wrong for a collection: insert a row at the top and every row
    /// below it becomes the row that used to be above it.
    public var id: String?

    /// The `ControlState` assigned to this view with `.assign()`, waiting for
    /// the differ to fill it with the element's identity.
    ///
    /// The BOX rather than the state: a node is not generic and has no use for
    /// which control it is about. Not an `id` either - it takes no part in
    /// matching and never crosses the boundary. The differ writes the identity
    /// it settled INTO the box as it walks, which is the whole mechanism - see
    /// Core/ControlState.swift.
    var assigned: ControlBox?

    /// The objects `.environment()` wrote on this node, in writing order -
    /// each provided to this element and everything under it, resolved by
    /// TYPE. A non-wire field like `assigned`: nothing about it crosses the
    /// boundary. See Core/Environment.swift.
    var environments: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// WHERE this node was written, among its siblings - the path the builder
    /// took to reach it.
    ///
    /// Not the author's `id`, and it never crosses the boundary. An `id` is a
    /// NAME the author chose; this is a PLACE IN THE SOURCE: which statement of
    /// the closure, which branch of the `if`. A loop has no place per row -
    /// `ForEach` identifies its rows by their ITEMS, in the id namespace. See
    /// Views/ViewBuilder.swift, which writes it, and `Differ.match`, which is
    /// the only thing that reads it.
    ///
    /// It exists because position is not identity once a closure has an `if` in
    /// it. An `if` that produces one child in one state and none in the other
    /// moves everything after it up a place, and matching by index would then
    /// hand the next view the control - and the focus, the caret, the scroll -
    /// belonging to the one that left. The path does not move.
    var key: String?

    /// The element's properties, keyed by their tokens - MAUI property names
    /// in camelCase, e.g. `.text`, `.fontSize`, `.horizontalOptions`.
    public var props: [Prop: PropValue]

    /// Nested nodes. Empty for leaf controls.
    public var children: [Node]

    /// The event token - MAUI's event name in camelCase - to what to run.
    ///
    /// The closure itself, not an id: building a tree has no business writing to
    /// a registry, and the id C# quotes back has to outlive this node anyway. The
    /// differ registers these under ids that belong to the ELEMENT and stay put
    /// for as long as it lives.
    public var events: [Event: EventHandler]

    /// The properties written from a `Binding`, and which state each borrows
    /// from - what `.opacity($fade)` records beside the value it also writes.
    ///
    /// Empty on almost every node there is. It never crosses the boundary: it
    /// is how the differ knows, when a property moves, whether a flight the
    /// author started is what moved it. See Core/Flight.swift.
    var armed: [Prop: FlightKey] = [:]

    /// The values this element is watching, in the order they were written.
    ///
    /// Written by `.onChanged`, read by the differ against the values the same
    /// element carried last render - and by nothing else, since none of it
    /// crosses the boundary. Order is what pairs a value with its predecessor;
    /// see Core/Changes.swift.
    var watches: [Watch] = []

    /// Set on a node that stands in for a subtree nobody has built yet.
    ///
    /// The differ asks for the subtree only when the token says the inputs have
    /// changed - see Core/Memo.swift.
    public var memo: Memo?

    /// Set on a node that stands in for a composed view whose body has not been
    /// built yet.
    ///
    /// The differ builds it - after handing the view's `@State` boxes the
    /// storage their predecessors held, which is what identity alone can
    /// decide. See Core/Stateful.swift.
    var stateful: Stateful?

    /// A subtree, and the reason to bother building it.
    public struct Memo {
        /// What the subtree was built from last time. Unchanged means the
        /// subtree would come out the same, so it is not built at all.
        let token: AnyHashable

        /// Produces the subtree. Called only when the token has changed.
        let build: () -> Node

        /// A subtree and the token that decides whether it is worth building.
        /// Written by `Element.memoized(by:)`, not by hand.
        public init(token: AnyHashable, build: @escaping () -> Node) {
            self.token = token
            self.build = build
        }
    }

    /// Adds a handler to an event that may already have one - every modifier
    /// in this library writes a token, `.textChanged` and never a spelling;
    /// Core/Tokens.swift is the one place the names exist.
    ///
    /// The primitive behind every typed event modifier: a handler written after
    /// another runs BESIDE it, never instead of it. What a two-way binding
    /// leaves behind is a handler, and an `.onTextChanged` that replaced it
    /// would kill the binding without a word. The public `onEvent` escape goes
    /// through here too, its literal spelling becoming a token on the way in.
    mutating func addHandler(_ event: Event, _ handler: @escaping EventHandler) {
        let existing = events[event]

        events[event] = {
            try await existing?()
            try await handler()
        }
    }

    /// A node. Every control's initializer ends here, and an author can too:
    /// a `Node` is an `Element`, so one written by hand drops into any builder
    /// - which is how a control an application registered with the host is
    /// described. What the host does with a type name it knows nothing about
    /// is on the type's own comment.
    ///
    /// - Parameters:
    ///   - type: the class name as a token - MAUI's, or an application's own
    ///     for a control it registered. A literal spelling works.
    ///   - id: who this element is, when the author says so. Nil leaves it to
    ///     be identified by where it was written.
    ///   - props: its properties, keyed by the MAUI property name camelCased.
    ///   - children: the nodes under it, in order. Empty for a leaf control.
    ///   - events: what each of its events runs, keyed by the MAUI event name
    ///     camelCased.
    public init(
        type: NodeType,
        id: String? = nil,
        props: [Prop: PropValue] = [:],
        children: [Node] = [],
        events: [Event: EventHandler] = [:]
    ) {
        self.type = type
        self.id = id
        self.props = props
        self.children = children
        self.events = events
    }
}

/// Anything that can describe itself as a UI tree.
///
/// Named after MAUI's own root class: everything that ends up on screen is an
/// Element. Views are values, not objects - `body` is called again on every
/// render, which is what makes state updates work without any manual wiring.
public protocol Element {
    /// This view as a node, read afresh on every render.
    var body: Node { get }
}

/// A Node is trivially an Element, which lets raw nodes and built-in controls be
/// mixed freely in the same builder.
extension Node: Element {
    /// Itself - a node already is what a body describes.
    public var body: Node { self }
}
