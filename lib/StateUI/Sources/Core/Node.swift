// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// StateUI's authored UI tree.
//
// Swift views produce nodes; the renderer owns identity and diffing, and a
// native host materializes the resulting `HostPatch` with its own toolkit.
// Same-process Swift hosts consume that patch directly. Foreign-language hosts
// consume its deterministic Wire encoding.
//
// A Node is deliberately plain: a StateUI type token, semantic properties,
// child nodes and event handlers. Hosts adapt those stable tokens to native
// controls without exposing toolkit types to application source.
//
// A node is what an author WROTE, this render. It carries no identity of its own
// beyond an optional `id`, and no handler ids: those belong to the element the
// node describes, which outlives the node. Diff.swift matches the two up.

/// A value in StateUI's authored tree and host boundary.
///
/// Every resolved case has a stable `HostValue` and Wire shape; `.themed`
/// remains in the renderer until it selects the active alternative. The differ
/// compares values between renders and includes only changes in a sparse
/// `HostPatch`.
public enum PropValue: Equatable, Sendable {
    /// TEXT SOMEONE WROTE - a label's words, a placeholder, a url, an SVG
    /// path, a format string. Nothing else: a closed vocabulary is
    /// `.enumeration`, a name is `.name`, and a value with parts is
    /// `.values`. Keeping those apart lets every host read a value
    /// as the thing it is, with nothing to parse and nothing to guess.
    case string(String)

    /// One member of a CLOSED vocabulary, as its NUMBER - `.tailTruncation`,
    /// `.bold`, `.cubicOut`. Whose numbers those are, and why, is the head of
    /// Types/Enums.swift.
    ///
    /// A bit set - FontAttributes, TextDecorations, AbsoluteLayoutProportions,
    /// SwipeDirection - is one of these too, carrying its bits.
    ///
    /// `Int32` rather than a Double because that is what the host contract's
    /// enumeration tag carries.
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

    /// A number. Everything numeric travels as a Double; each host converts it
    /// to the representation the semantic property requires.
    case number(Double)

    /// True or false.
    case bool(Bool)

    /// A fixed-length list of numbers. Used by the structured value types - a
    /// Insets travel as left, top, right, bottom.
    case numbers([Double])

    /// A list of strings. What a Picker is given to choose from.
    case strings([String])

    /// A colour, as the four channels it is - each 0 to 255, sRGB, alpha
    /// included. Four bytes on the wire and no host-side parser: one
    /// colour, whichever theme it was picked for - a pair is `.themed` until
    /// the differ picks. See Types/Color.swift.
    case color(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)

    /// A list of values of any kind - what a structured value travels as when
    /// its parts are not all the same shape. A Brush is the one that needs it:
    /// a kind, its geometry, and a colour per stop. See Types/Brush.swift.
    case values([PropValue])

    /// A value with a half for each THEME - a `Color(light:dark:)`, an
    /// `ImageSource(light:dark:)` - held as both until the differ builds the
    /// element wearing it, which picks the half in force and is from then on
    /// a READER of the theme: a theme change builds that element again, and
    /// nothing else. So a pair written anywhere - in a body, in a style, into
    /// a session from a handler - is right in both themes. Never on the wire.
    indirect case themed(light: PropValue, dark: PropValue)

    /// Whether this value has continuous lanes a host may transition.
    ///
    /// Numbers, colours and numeric lists are continuous. A structured value is
    /// provisionally continuous so shape-preserving values such as compatible
    /// gradients can move lane by lane. Text, flags, names and enumerations snap.
    ///
    /// `Prop.unmoved` supplies semantic property exceptions. A host validates
    /// the source and target shapes and snaps any pair it cannot interpolate.
    var moves: Bool {
        switch self {
        case .number, .color, .numbers, .values: true
        default: false
        }
    }

    /// Which KIND of value this is, where the value itself says.
    ///
    /// A colour identifies its own group regardless of which semantic property
    /// carries it. Every other group is answered by the property; see
    /// `Prop.moving`.
    var kind: MotionValues {
        switch self {
        case .color, .values: .colour
        default: []
        }
    }

    /// Whether this value has a half for each theme, anywhere in it - a pair,
    /// or a brush with a pair among its stops.
    var isThemed: Bool {
        switch self {
        case .themed: true
        case .values(let values): values.contains { $0.isThemed }
        default: false
        }
    }

    /// This value with the half in force picked wherever it has two - which
    /// READS the theme, so whoever builds with it becomes the theme's reader.
    /// See `element` in Core/Diff.swift.
    func resolvingTheme() -> PropValue {
        switch self {
        case .themed(let light, let dark):
            (StandardEnvironment.app.requestedTheme == .dark ? dark : light).resolvingTheme()
        case .values(let values):
            .values(values.map { $0.resolvingTheme() })
        default:
            self
        }
    }

    /// The text, when this value is text - nil for any other kind. What an
    /// `onEvent` handler reads a TextField's new text with, and what the few
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

/// What a StateUI event runs.
///
/// May await, and usually does not:
///
///     Button("Save").onClicked { saved = true }
///     Button("Open").onClicked { path.append(.details) }
///
/// A handler that never awaits finishes before event dispatch returns. One that
/// does await resumes on `@MainThread` in a later turn; see Core/MainThread.swift.
///
/// `nonisolated(nonsending)` is what makes that true: it says the handler runs on
/// its CALLER's executor, which is `@MainThread`. Written as a plain
/// `() async -> Void` it would run on Swift's cooperative pool instead, next to a
/// render that assumes it is alone.
///
/// Throwing is allowed so that `try await` reads without a `do` around it. What
/// escapes is reported to the host rather than lost - see Renderer.dispatch.
public typealias EventHandler = nonisolated(nonsending) () async throws -> Void

/// The same execution contract, for an event that carries values - one
/// parameter for each, in the order the event declares them.
///
///     TextField("").onTextChanged { text in query = text }
///     .onEvent(NotesContract.batteryChanged) { level, charging in … }
///
/// The distinct name is required because Swift cannot overload type aliases by
/// generic arity: an event with nothing to say takes an `EventHandler`.
public typealias ValueEventHandler<each Value> = nonisolated(nonsending) (repeat each Value) async throws -> Void

/// One element of the UI tree: its semantic type, properties, children and
/// event handlers.
///
/// Every control in this library ends up as one, and a `Node` is itself an
/// `Element`, so one written by hand goes into any builder. That is how an
/// application describes a control it registered with a host, and how it sets
/// a property for which it has no typed modifier:
///
///     extension NodeType {
///         static let marker = NodeType("Maps.Marker")
///     }
///
///     Node(type: .marker, props: ["title": .string("Harbour")])
///
/// The host resolves the type token through StateUI's built-in contract or its
/// application control registry. An unresolved type draws the unknown-control
/// marker rather than hiding the rest of the interface.
///
/// It is what an author WROTE, this render. It carries no identity of its own
/// beyond `id` and no handler ids: those belong to the element the node
/// describes, which outlives the node.
public struct Node {
    /// The element's StateUI type token, such as `.label`,
    /// `.vStack`, or an application's own registered type.
    public var type: NodeType

    /// Who this element is, when the author says so - `.id("row-7")`.
    ///
    /// An element that keeps its identity between renders keeps its CONTROL, and
    /// with it focus, caret position and scroll offset. Anything without one is
    /// identified by its position among its siblings, which is right for a fixed
    /// layout and wrong for a collection: insert a row at the top and every row
    /// below it becomes the row that used to be above it.
    public var id: String?

    /// The aim put on this view with `.aim(_:)`, waiting for the differ to
    /// fill it with the element's identity.
    ///
    /// The BOX rather than the aim: a node is not generic and has no use for
    /// which control it is about. Not an `id` either - it takes no part in
    /// matching and never crosses the boundary. The differ writes the identity
    /// it settled INTO the box as it walks, which is the whole mechanism - see
    /// Core/Aim.swift.
    var aim: AimBox?

    /// The readings views on this element asked for with
    /// `.samples(_:into:_:)`, waiting for the differ to put them on the values
    /// they read.
    ///
    /// The host's STORAGE and a closure rather than the bindings, for the
    /// reason `aim` holds a box: a node is not generic and has no use for
    /// what kind of value a state holds. A list, because one view may read
    /// several values - and none of it crosses the boundary, because a reading
    /// is renderer-local. See Core/Sampling.swift.
    var samples: [(image: HostStorage, into: ObjectIdentifier, asks: Asks, take: @Sendable () -> Void)] = []

    /// The objects `.environment()` wrote on this node, in writing order -
    /// each provided to this element and everything under it, resolved by
    /// TYPE. A non-wire field like `aim`: nothing about it crosses the
    /// boundary. See Core/Environment.swift.
    var environments: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// What this element holds for its life, where it asks for something - a
    /// page's session: made the first time the element is built, handed back
    /// on every build after, and offered below like an object `.environment()`
    /// wrote here. Nothing about it crosses the boundary. See
    /// Core/ElementSession.swift.
    var session: ElementSession?

    /// WHERE this node was written, among its siblings - the path the builder
    /// took to reach it.
    ///
    /// Not the author's `id`, and it never crosses the boundary. An `id` is a
    /// NAME the author chose; this is a PLACE IN THE SOURCE: which statement of
    /// the closure, which branch of the `if`. A loop has no place per row -
    /// `ForEach` identifies its rows by their ITEMS, in the id namespace. See
    /// Views/ViewBuilder.swift, which writes it, and the differ, which matches
    /// a child by it (`Differ.match`) and carries it onto the element for
    /// nothing else.
    ///
    /// It exists because position is not identity once a closure has an `if` in
    /// it. An `if` that produces one child in one state and none in the other
    /// moves everything after it up a place, and matching by index would then
    /// hand the next view the control - and the focus, the caret, the scroll -
    /// belonging to the one that left. The path does not move.
    var key: String?

    /// The element's semantic properties, keyed by StateUI tokens such as
    /// `.text`, `.fontSize` and `.horizontalAlignment`.
    public var props: [Prop: PropValue]

    /// Nested nodes. Empty for leaf controls.
    ///
    /// TWO HALVES: what `producer` makes, and what sits here. A container's
    /// content lives in `producer` and is not run until the differ descends
    /// into this element; this array is the TAIL - the slot children a
    /// modifier appends after construction (a visual state, a context
    /// flyout, a swipe item). `materialize()` joins the two, produced
    /// content first, which is the order the slots were always appended in.
    public var children: [Node]

    /// The container's content, deferred until the differ asks for it.
    ///
    /// This is what makes a container cheap to construct and a carry real:
    /// the author's closure runs when this element is described, not when
    /// the author's line of code constructs the view - so a closure written
    /// inside a carried view never runs, an ancestor's `.environment()` is in
    /// scope when it does run, and the reads it makes land on THIS element
    /// and no other: the closure that read a state is the reader of it, and
    /// the one built again when the state moves.
    ///
    /// Nil once run: a node is described once, and the differ writes the
    /// result into `children` where everything downstream already looks.
    var producer: (() -> [Node])?

    /// Runs the producer, if one is pending, and files what it made ahead of
    /// the appended slots. Safe to call twice; the second is a no-op.
    mutating func materialize() {
        guard let make = producer else { return }

        producer = nil
        children = make() + children
    }

    /// Whether any of the children is a visual state.
    ///
    /// One bit, written where a visual state is added - by a state modifier
    /// and by `styled(_:with:)` - and read by the differ's motion field, which
    /// then needs no walk over the children to know whether any of them is a
    /// state.
    var states = false

    /// Each semantic event token and the handler it runs.
    ///
    /// The closure itself, not an id: building a tree has no business writing to
    /// a registry, and the id a host reports has to outlive this node anyway.
    /// The differ registers handlers under ids that belong to the ELEMENT and
    /// stay put for as long as it lives.
    public var events: [Event: EventHandler]

    /// The properties driven by a state, and how each one crosses - what
    /// `.opacity($fade)` records where it writes no value at all.
    ///
    /// Empty on almost every node there is. It DOES cross the boundary, as the
    /// registration field: the host has to know which number to
    /// read a property from, because nothing on the wire ever carries that
    /// property's value again. See Core/StateValue.swift.
    var driven: [Prop: StateRegistration] = [:]

    /// Whether this element reports its own frame - an `.onFrameChanged`, or a
    /// `.frame($x)` feed. What it reports is what it holds, arranged in the
    /// size it was given, so a size of its own is not carried through a
    /// motion. See Core/Diff.swift.
    var reportsFrame: Bool {
        events[.frameChanged] != nil || driven[.frame] != nil
    }

    /// Whether this layout's children take their sizes at once: it reports its
    /// own frame, or one of them reports theirs - and what a measurement
    /// reports is what the views beside it leave it. Their places still
    /// travel.
    var childSizesArrive: Bool {
        reportsFrame || children.contains(where: \.reportsFrame)
    }

    /// How this element's values MOVE when they change - what `.motion(_:)`
    /// and `.motion(_:_:)` wrote, or nil to travel at whatever the application
    /// says.
    ///
    /// The plan stays in the renderer. Its resolved answers become
    /// `HostTransition` entries for changed properties and `HostLayoutMotion`
    /// for host-arranged children. It is per NODE and does not cascade from an
    /// ancestor; the application supplies the shared fallback. See
    /// Types/Motion.swift.
    var motion: MotionPlan?

    /// The values this element is watching, in the order they were written.
    ///
    /// Written by `.onChanged`, read by the differ against the values the same
    /// element carried last render - and by nothing else, since none of it
    /// crosses the boundary. Order is what pairs a value with its predecessor;
    /// see Core/Changes.swift.
    var watches: [Watch] = []

    /// What `.onCreated` runs, in the order it was written - once, in the
    /// render that brings the element into the tree, after its walk and before
    /// its message leaves. None of it crosses the boundary; see
    /// Core/Lifetime.swift.
    var created: [EventHandler] = []

    /// What `.onDestroying` runs, in the order it was written - once, in the
    /// render that takes the element out of the tree, before its message
    /// leaves. See Core/Lifetime.swift.
    var destroying: [EventHandler] = []

    /// The arithmetic this element runs on the host's own frames, in the order
    /// it was written.
    ///
    /// Written by `.engine(following:)`, registered by the differ under an id the element
    /// KEEPS, and read by nothing else - none of it crosses the boundary, the
    /// host asking for a cycle rather than for an engine. Order is what pairs
    /// an engine with its predecessor, exactly as it pairs a watch with one;
    /// see Core/Cycle.swift.
    var engines: [EngineDeclaration] = []

    /// Set on a layout whose children are ROWS - interchangeable subtrees, of
    /// which a few are described at a time and the rest are not there at all.
    ///
    /// The host then keeps a pool per layout: a child that leaves the described
    /// window is kept rather than dropped, and a child that arrives is given
    /// one of the kept controls when their SHAPES match. Written by this
    /// library's own list, on the layout its rows sit in, and by nothing
    /// else - see Core/Recycling.swift for what a shape is and what it costs
    /// to get one wrong.
    var recycles = false


    /// Set on a node that stands in for a composed view whose body has not been
    /// built yet.
    ///
    /// The differ builds it - after handing the view's `@State` boxes the
    /// storage their predecessors held, which is what identity alone can
    /// decide. See Core/Stateful.swift.
    var stateful: Stateful?

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
    ///   - type: the StateUI type token, built in or registered by the
    ///     application. A literal spelling works.
    ///   - id: who this element is, when the author says so. Nil leaves it to
    ///     be identified by where it was written.
    ///   - props: its properties, keyed by semantic StateUI tokens.
    ///   - children: the nodes under it, in order. Empty for a leaf control.
    ///   - events: what each semantic event runs, keyed by its StateUI token.
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

    /// A node of an element's own type: how every element's view begins.
    ///
    ///     struct TrafficLight: View {
    ///         var node = Node(contract: TrafficLightContract.self)
    ///     }
    ///
    /// - Parameters:
    ///   - contract: the element's contract, which names its node type.
    ///   - id: who this element is, when the author says so. Nil leaves it to
    ///     be identified by where it was written.
    ///   - children: the nodes under it, in order. Empty for a leaf control.
    public init<Declaration: ElementContract>(
        contract: Declaration.Type,
        id: String? = nil,
        children: [Node] = []
    ) {
        self.init(type: Declaration.nodeType, id: id, children: children)
    }
}

/// Anything that can describe itself as a UI tree.
///
/// Views are values, not native objects. StateUI evaluates `body` when it needs
/// the element's current description, including after a state read by that
/// element changes.
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
