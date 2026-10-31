// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The tree an author writes: a `Node` is one element as written this render and
// is thrown away after it. Its key and handler ids belong to the element it
// describes (Tree.swift).
// Design: docs/design/core/identity-and-diffing.md#keys

/// A value in StateUI's tree and at the host boundary. `.themed` stays in the
/// renderer until it picks the half in force.
public enum PropValue: Equatable, Sendable {
    /// Text someone wrote - a label's words, a placeholder, a url, an SVG path. A
    /// closed vocabulary is `.enumeration`, a name is `.name`, and a value with
    /// parts is `.values`.
    case string(String)

    /// One member of a closed vocabulary, as its number (the vocabularies under Types) - a bit
    /// set such as `FontAttributes` too.
    case enumeration(Int32)

    /// A value that is not there, said out loud: for a position in an act's
    /// arguments or in a list, where absence cannot be left out.
    case nothing

    /// A name from an open vocabulary - a style key, a visual state, a font family,
    /// a radio group. It crosses as its spelling.
    case name(String)

    /// A number. Everything numeric crosses as a Double.
    case number(Double)

    /// True or false.
    case bool(Bool)

    /// A fixed-length list of numbers - a structured value such as `Insets`, as
    /// left, top, right, bottom.
    case numbers([Double])

    /// A list of strings. What a Picker is given to choose from.
    case strings([String])

    /// Bytes as they stand - a file's contents read or written.
    case bytes([UInt8])

    /// A color: four sRGB channels from 0 to 255, alpha included (Color.swift).
    case color(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)

    /// A list of values of any kind, for a value whose parts differ in shape - a
    /// brush (Brush.swift).
    case values([PropValue])

    /// A value with a half for each theme, resolved by the differ as the element is
    /// built. Never handed to a host.
    /// Design: docs/design/core/identity-and-diffing.md#themes
    indirect case themed(light: PropValue, dark: PropValue)

    /// A color of the system's - 0, the accent in force - let through to
    /// `alpha`, resolved by the differ as the element is built. Never handed to
    /// a host.
    /// Design: docs/design/types/color-and-theme.md#the-accent-in-force
    case systemColor(Int32, alpha: UInt8)

    /// Whether this value has components a host may animate; a host snaps any pair
    /// it cannot interpolate.
    var moves: Bool {
        switch self {
        case .number, .color, .numbers, .values: true
        default: false
        }
    }

    /// Which kind of value this is where the value itself says: a color.
    var kind: MotionValues {
        switch self {
        case .color, .values: .color
        default: []
        }
    }

    /// Whether this value has a half for each theme, or a color of the system's, anywhere in it.
    var isThemed: Bool {
        switch self {
        case .themed, .systemColor: true
        case .values(let values): values.contains { $0.isThemed }
        default: false
        }
    }

    /// This value with the half in force picked - a read of the theme.
    @MainActor
    func resolvingTheme() -> PropValue {
        switch self {
        case .themed(let light, let dark):
            (StandardEnvironment.application.info.colorScheme == .dark ? dark : light).resolvingTheme()
        case .systemColor(_, let alpha):
            StandardEnvironment.application.info.accentColor.opacity(Double(alpha) / 255).propValue.resolvingTheme()
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

    /// The number, when this value is one - nil for any other kind, so text is
    /// never read as a quantity.
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

    /// The name, when this value is one - nil for any other kind, text included.
    public var name: String? {
        if case .name(let value) = self { return value }
        return nil
    }

    /// The whole number nearest the number, when this value is a finite number - what
    /// an index or a position payload is read with, as a carried lane is: 2.6 answers 3;
    /// text, infinity or a number past `Int` answers nil.
    public var int: Int? {
        guard case .number(let value) = self else { return nil }
        return Int(nearest: value)
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

    /// The bytes, when this value is a run of them - a file's contents.
    public var bytes: [UInt8]? {
        if case .bytes(let value) = self { return value }
        return nil
    }

    /// The four channels, when this value is a color - nil for any other
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
    /// The value at `index`, or nil when the list is shorter - how a value of an
    /// application's own reads the parts it crossed as:
    ///
    ///     init?(propValue: PropValue) {
    ///         guard let parts = propValue.values,
    ///               let latitude = parts.value(0)?.number,
    ///               let longitude = parts.value(1)?.number else { return nil }
    ///
    ///         self.init(latitude: latitude, longitude: longitude)
    ///     }
    public func value(_ index: Int = 0) -> PropValue? {
        indices.contains(index) ? self[index] : nil
    }
}

/// What a handler that awaits runs - through a gate, or once by `.onCreated`
/// and `.onDestroying`:
///
///     Button("Save").onClicked(.ignoreWhileRunning) { try await model.save() }
///
/// It runs on `@MainActor`, up to its first `await` inside its event; what it
/// throws is reported to the host.
public typealias EventHandler = @MainActor () async throws -> Void

/// What an event that carries values runs - one parameter for each, in the order
/// the event declares them. An event with nothing to say takes an `EventHandler`.
///
///     TextField("").onTextChanged(.cancelPrevious) { text in try await model.search(text) }
///     let heard = HostEvents.on(NotesContract.batteryChanged, policy: .cancelPrevious) { level, _ in try await log(level) }
public typealias ValueEventHandler<each Value> = @MainActor (repeat each Value) async throws -> Void

/// One element of the UI tree: its type, properties, children and handlers.
///
/// Every element ends up as one, made from its contract - which is how an
/// application describes a control it registered with a host:
///
///     struct Beacon: ElementView {
///         var node = Node(contract: BeaconContract.self)
///
///         func title(_ value: String) -> Self {
///             setValue(BeaconContract.title, value)
///         }
///     }
///
/// A type no host resolves draws the unknown-control marker rather than hiding
/// the rest of the interface.
@MainActor
public struct Node {
    /// The element's StateUI type token, such as `.text`,
    /// `.vStack`, or an application's own registered type.
    public internal(set) var type: NodeType

    /// Who this element is, when the author says so - `.id("row-7")` - as its patch names it. An element that
    /// keeps its key keeps its control, with its focus, caret and scroll offset; a collection's rows need one.
    public internal(set) var id: String? {
        get { identity.map(Self.described) }
        set { identity = newValue.map { ElementIdentity(AnyHashable($0)) } }
    }

    /// The value the element is written as, compared as that value: what matches it with the element it continues.
    /// Design: docs/design/core/identity-and-diffing.md#keys
    var identity: ElementIdentity?

    /// Writes `value` as who this element is.
    mutating func identify(_ value: some Hashable) {
        identity = ElementIdentity(AnyHashable(value))
    }

    /// An identity as the patch names it: its description, made where an element is born.
    /// Design: docs/design/core/identity-and-diffing.md#keys
    static func described(_ identity: ElementIdentity) -> String {
        if let text = identity.value.base as? String { return text }
        Renderer.shared.texts += 1
        return String(describing: identity.value.base)
    }

    /// The aim put on this view with `.aim(_:)`: a box the differ fills with the
    /// element's key. It takes no part in matching and never crosses.
    var aim: AimBox?

    /// The readings asked for with `.samples(_:into:_:)`, for the differ to put on
    /// the values they read. Never crosses (Sampling.swift).
    var samples: [(image: HostStorage, into: ObjectIdentifier, asks: Asks, take: @MainActor () -> Void)] = []

    /// The objects `.environment()` wrote here, in writing order, provided to this
    /// element and its subtree by type. Never crosses.
    var environments: [(key: ObjectIdentifier, object: AnyObject)] = []

    /// Where this node was written among its siblings - the builder path: which
    /// statement, which branch. Never crosses; the differ matches children by it.
    /// Design: docs/design/core/identity-and-diffing.md#keys
    var key: PathNumber?

    /// The branch a composed view's content root was written in - an `if/else`
    /// there - which the placeholder's key covers; part of what the element is.
    /// Design: docs/design/core/identity-and-diffing.md#another-kind-of-view
    var branch: PathNumber?

    /// The element's properties, by token.
    var props: [Prop: PropValue]

    /// Nested nodes: those it was made with and the slot children modifiers append;
    /// a container's own content waits in its producer until the differ describes it.
    public var children: [Node]

    /// The container's content, run when the differ describes this element; nil once
    /// run.
    /// Design: docs/design/core/identity-and-diffing.md#containers-run-their-own-content
    var producer: (() -> [Node])?

    /// What the element reads of a state it was handed, run as the differ describes it.
    /// Design: docs/design/core/invalidation.md#an-element-reads-what-it-was-handed
    var describedReads: [@MainActor (inout Node) -> Void] = []

    /// Reads a state as the differ describes this element, never while the body writing it builds: the element is the
    /// state's reader, and a write describes the element alone again.
    mutating func readsWhenDescribed(_ read: @escaping @MainActor (inout Node) -> Void) {
        describedReads.append(read)
    }

    /// Runs what the element reads when described, here and now - for a reading of the tree outside the differ.
    mutating func readAsDescribed() {
        let reads = describedReads
        describedReads = []
        for read in reads { read(&self) }
    }

    /// Runs the producer, if pending, filing its nodes ahead of the slots. Idempotent.
    mutating func materialize() {
        guard let make = producer else { return }

        producer = nil
        children = make() + children
    }

    /// The visual states it declares, its style's merged in by the differ; and what
    /// `.onVisualStateChanged` runs (DeclaredState.swift).
    var visualStates: [DeclaredState] = []
    var visualStateListeners: [VisualStateListener] = []

    /// Each event's handlers in written order, each with the gate it passes through; the ids belong to the element,
    /// assigned by the differ.
    var events: [Event: [Handler]]

    /// The properties driven by a state and how each crosses - what `.opacity($fade)`
    /// records instead of a value (StateAttachment.swift).
    var driven: [Prop: StateRegistration] = [:]

    /// Whether this element reports its own frame, so its own size never animates.
    var reportsFrame: Bool {
        events[.frameChanged] != nil || driven[.frame] != nil
    }

    /// Whether this layout's children take their sizes at once: it or one of them is
    /// measured.
    var childSizesArrive: Bool {
        reportsFrame || children.contains(where: \.reportsFrame)
    }

    /// How this element's values animate - what `.motion(_:)` wrote - or nil for the
    /// application's. Per node, never inherited (MotionPlan.swift).
    var motion: MotionPlan?

    /// The values `.onChanged` watches, in written order (Changes.swift).
    var watches: [Watch] = []

    /// What `.onCreated` runs, in written order (Lifetime.swift).
    var created: [EventHandler] = []

    /// What `.onDestroying` runs, in written order.
    var destroying: [EventHandler] = []

    /// The events of the application's `.onHostEvent` hears while the element stands, in written order
    /// (HostEventRelay.swift).
    var hostEvents: [HostEventListen] = []

    /// The engines this element runs, in written order; the differ registers them
    /// under numbers the element keeps (Engine.swift).
    var engines: [EngineDeclaration] = []

    /// Set on a placeholder for a composed view whose body is not built yet
    /// (Stateful.swift).
    var stateful: Stateful?

    /// What the view says of the page it stands on, apart from its own values (PageValues.swift).
    var pageValues: PageValues?

    /// Adds a handler beside any the event already has, never instead of it; it starts runs as an owner of its own.
    /// Design: docs/design/core/identity-and-diffing.md#handlers-and-their-ids
    mutating func addHandler(_ event: Event, gate: Gating, _ handler: @escaping EventHandler) {
        events[event, default: []].append(Handler(run: handler, gate: gate))
    }

    /// The same, for a step - a handler that does not await, which passes no gate.
    mutating func addHandler(_ event: Event, _ handler: @escaping @MainActor () throws -> Void) {
        events[event, default: []].append(Handler(step: handler))
    }

    /// Takes `handlers` for `event` after any it already has - what is written on a composed view, moved onto
    /// its body.
    mutating func addHandlers(_ event: Event, _ handlers: [Handler]) {
        events[event, default: []] += handlers
    }

    /// A node of a type with its parts already made - what `Node(contract:)` and the
    /// library's structure are written over.
    init(
        type: NodeType,
        id: String? = nil,
        props: [Prop: PropValue] = [:],
        children: [Node] = [],
        events: [Event: @MainActor () throws -> Void] = [:]
    ) {
        self.type = type
        self.identity = id.map { ElementIdentity(AnyHashable($0)) }
        self.props = props
        self.children = children
        self.events = events.mapValues { [Handler(step: $0)] }
    }

    /// A node of an element's own type: how every element's view begins.
    ///
    ///     struct TrafficLight: ElementView {
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

/// Anything that describes itself as a UI tree. A view is a value; StateUI reads
/// `node` whenever it needs the element's description.
@MainActor
public protocol Element {
    /// This element as a node, read afresh on every render.
    var node: Node { get }
}

/// A `Node` is an `Element`: a node already is what an element describes.
extension Node: Element {
    /// Itself - a node already is what an element describes.
    public var node: Node { self }
}
