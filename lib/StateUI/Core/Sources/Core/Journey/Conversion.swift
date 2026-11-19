// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A binding converted on its way to a control: a second state, whose destination is worked out from its sources'
// destinations by the conversions' graph, with a way back for a write into it.
// Design: docs/design/core/journeys.md#conversions

/// One conversion: the sources, the arithmetic each way, and the derived state. A node of the conversions' graph
/// while an element wears its derived state.
@MainActor
final class Conversion {
    /// The order it was first declared in: what the graph breaks a tie by.
    let id: Int

    private static var declared = 0

    init() {
        Self.declared += 1
        id = Self.declared
    }

    /// The sources, each as its binding reaches it when asked: the storage it was made from, held, answering the
    /// one it stands for - so a conversion made before its view's adoption, or kept past the box it was made from,
    /// reaches the state as it stands. The derived side knows this conversion weakly, so no ring closes.
    /// Design: docs/design/core/journeys.md#conversions
    private var reaches: [() -> (any AnyStateStorage)?] = []

    /// The sources that still exist, for a read at build to record and the way back to write.
    var sources: [any AnyStateStorage] { reaches.compactMap { $0() } }

    /// Takes the sources as their bindings reach them.
    func reach(_ sources: [() -> (any AnyStateStorage)?]) {
        reaches = sources
        seen.removeAll()
    }

    /// The conversions this one's sources are the derived side of, held here: the middle of a chain has no binding
    /// of its own once the expression writing it ends, and the chain is worked out from its first sources.
    /// Design: docs/design/core/journeys.md#a-chain-of-conversions
    var upstream: [Conversion] = []

    /// This conversion and every one it is worked out from, the first sources' first, each once.
    var chain: [Conversion] {
        var seen = Set<ObjectIdentifier>()
        var ordered: [Conversion] = []
        func add(_ conversion: Conversion) {
            guard seen.insert(ObjectIdentifier(conversion)).inserted else { return }
            conversion.upstream.sorted { $0.id < $1.id }.forEach(add)
            ordered.append(conversion)
        }
        add(self)
        return ordered
    }

    /// Whether `other` is worked out from this one, however far down: taking it for a source would close a ring.
    func feeds(_ other: Conversion) -> Bool {
        other.chain.contains { $0 === self }
    }

    /// Works the derived destination out of the sources' and publishes it where it differs, asking its readers
    /// where `asking` says - the graph does, a read at build does not.
    var forward: (_ asking: Bool) -> Void = { _ in }

    /// Puts the derived state where its sources say, at once and standing still: what a control that reported
    /// goes back to.
    var land: () -> Void = {}

    /// What a derived value goes back to - a destination for each source - where the declaration writes a way back;
    /// the current declaration's alone (`declareAgain`, `declareBack`). Nil for a value of another type.
    private(set) var back: ((Any) -> [BackCandidate]?)?

    /// The derived state.
    var derived: () -> (any AnyStateStorage)? = { nil }

    /// The derived value as it stands, of no type.
    var derivedValue: () -> Any? = { nil }

    /// Starts a declaration of this conversion: the way back is what the new one writes, none unless it does.
    /// Design: docs/design/core/journeys.md#a-conversion-declared-again
    func declareAgain() {
        back = nil
    }

    /// Says the way back this declaration writes.
    func declareBack(_ back: @escaping (Any) -> [BackCandidate]?) {
        self.back = back
    }

    // MARK: - The graph's node

    /// Each source's destination revision as it stood when the derived destination was last worked out.
    private var seen: [ObjectIdentifier: Int] = [:]

    /// How many live elements wear the derived state: the graph keeps it up to date while any does.
    var wearers = 0

    /// Whether a source's destination moved since the derived one was worked out.
    var isStale: Bool {
        let sources = sources
        return sources.count != seen.count || sources.contains { seen[ObjectIdentifier($0)] != $0.targetRevision }
    }

    /// Works the derived destination out where a source's moved, and remembers where the sources stand.
    func refresh(asking: Bool) {
        guard isStale else { return }

        forward(asking)
        seen = Dictionary(sources.map { (ObjectIdentifier($0), $0.targetRevision) }) { _, last in last }
    }

    // MARK: - The way back

    /// Writes `requested` into the derived state by its way back - every source it goes back to, up the whole
    /// chain - whole or not at all, and answers how it ended.
    /// Design: docs/design/core/journeys.md#the-way-back
    func writeBack(_ requested: Any, origin: WriteOrigin) -> BackOutcome {
        // What the value goes back to, up the chain: a link with no way back makes the whole read-only.
        var candidates: [BackCandidate] = []
        func gather(_ conversion: Conversion, _ value: Any) -> Bool {
            guard let proposed = conversion.back?(value) else { return false }

            for candidate in proposed {
                candidates.append(candidate)
                if let above = candidate.storage.conversion, !gather(above, candidate.value) { return false }
            }
            return true
        }
        guard gather(self, requested) else { return .readOnly }

        // One storage met twice takes one value: equal proposals are one, others a conflict.
        var roots: [BackCandidate] = []
        for candidate in candidates where candidate.storage.conversion == nil {
            if let standing = roots.first(where: { $0.storage === candidate.storage }) {
                guard standing.proposesTheSame(as: candidate) else {
                    return .refused("a way back asked one state for two values at once; nothing was written")
                }
            } else {
                roots.append(candidate)
            }
        }

        // Each state's own word first, as things stand.
        for candidate in candidates {
            if let why = candidate.refusal() { return .refused(why) }
        }

        // Then against the whole proposal: every root staged, each asked with all the others standing.
        let links = chain
        let touched = roots.map(\.storage) + links.compactMap { $0.derived() }
        let restore = touched.map { $0.stager() }
        func takeBack() { restore.reversed().forEach { $0() } }

        let (refused, canonical): (String?, Any?) = BackProposal.standing(roots) {
            roots.forEach { $0.stage() }
            for (place, candidate) in roots.enumerated() {
                restore[place]()
                let why = BackProposal.without(candidate.storage) { candidate.refusal() }
                candidate.stage()
                if let why { return (why, nil) }
            }

            // What the sources would make of it: a program's write must be exactly that.
            links.forEach { $0.forward(false) }
            return (nil, derivedValue())
        }
        takeBack()
        if let refused { return .refused(refused) }
        if origin == .program, let canonical, !Self.same(canonical, requested) {
            return .refused(
                "a value written into a converted state must be what its sources make of it - "
                    + "`forward(back(value)) == value`; nothing was written")
        }

        // Accepted whole: the sources take their destinations together, and the chain follows.
        roots.forEach { $0.commit(origin) }
        links.forEach { $0.refresh(asking: true) }
        return .landed
    }

    /// Whether two values of no type are one value.
    private static func same(_ one: Any, _ other: Any) -> Bool {
        guard let one = one as? any Equatable else { return false }

        func equals<T: Equatable>(_ value: T) -> Bool { (other as? T) == value }
        return equals(one)
    }
}

/// Who wrote a value: what decides whether a way back runs and whether a handler hears it.
/// Design: docs/design/core/journeys.md#the-way-back
@_spi(Host) public enum WriteOrigin: Equatable, Sendable {
    /// The user, through a native control.
    case user

    /// The application.
    case program

    /// A frame of the host's animation.
    case animation

    /// The platform measured it: a frame, a size.
    case measurement

    /// A conversion published it from its sources.
    case conversion
}

/// The destinations a way back proposes, while it asks whether they may stand together: what a state's refusal
/// reads of the other states of the same write, where it reads them anywhere but their storages.
/// Design: docs/design/core/journeys.md#the-way-back
@MainActor
enum BackProposal {
    private static var proposed: [ObjectIdentifier: Any] = [:]

    /// The destination proposed for `storage` in the write being asked about, or nil for none.
    static func value(for storage: AnyObject) -> Any? { proposed[ObjectIdentifier(storage)] }

    /// Asks `body` with `candidates` standing as proposed.
    static func standing<T>(_ candidates: [BackCandidate], _ body: () -> T) -> T {
        let outer = proposed
        defer { proposed = outer }
        for candidate in candidates { proposed[ObjectIdentifier(candidate.storage)] = candidate.value }
        return body()
    }

    /// Asks `body` with nothing proposed for `storage`: a state is asked about a value while it holds its own.
    static func without<T>(_ storage: AnyObject, _ body: () -> T) -> T {
        let held = proposed.removeValue(forKey: ObjectIdentifier(storage))
        defer { proposed[ObjectIdentifier(storage)] = held }
        return body()
    }
}

/// How a write into a derived state ended.
enum BackOutcome: Equatable {
    /// Every source took its destination.
    case landed

    /// Nothing was written, for the reason given.
    case refused(String)

    /// No way back is declared, or a link up the chain has none.
    case readOnly
}

/// One source's destination a way back proposes: asked, staged and committed without its type.
@MainActor
struct BackCandidate {
    /// The state it is proposed to.
    let storage: any AnyStateStorage

    /// The destination proposed.
    let value: Any

    /// Why the state refuses it - its own word - or nil.
    let refusal: () -> String?

    /// Lays it silently, for the others to be asked against.
    let stage: () -> Void

    /// Writes it for good: where the user put it, at once and still; where the program did, a destination.
    let commit: (WriteOrigin) -> Void

    private let same: (Any) -> Bool

    init<Value: StateValue>(_ storage: State<Value>.Storage, _ value: Value) {
        self.storage = storage
        self.value = value
        same = { ($0 as? Value) == value }
        refusal = { storage.refuses?(value) }
        stage = { storage.value = value }
        commit = { origin in
            if origin == .user { storage.snap(value) } else { storage.write(value) }
            storage.askForRender()
        }
    }

    /// Whether `other` proposes this very value.
    func proposesTheSame(as other: BackCandidate) -> Bool { same(other.value) }
}

/// What a conversion needs of a storage without its type: whether a
/// build read it, where a derived state is kept, and where its destination stands.
protocol AnyStateStorage: FollowedState {
    /// Whether any build has ever read this state.
    var readAtBuild: Bool { get set }

    /// The conversion this state is the derived side of, if it is one.
    var conversion: Conversion? { get }

    /// How many times its destination changed: what a conversion of it compares.
    var targetRevision: Int { get }

    /// The derived state a conversion written at `key` keeps on this source.
    func derived<Out>(_: Out.Type, at key: PathNumber, make: @escaping () -> Out) -> State<Out>.Storage

    /// Takes the state as it stands, answering what puts it back so - silently: no reader asked, nothing kept,
    /// no stamp moved.
    func stager() -> () -> Void
}

extension Binding where Value: StateValue {
    /// The conversion this binding is the derived side of, if it is one.
    var conversion: Conversion? { storage.conversion }

    /// This state converted on its way to a control: a second state whose
    /// destination is worked out from this one's, so the control shows
    /// `transform(value)` and nothing is built for it. This library's own.
    ///
    ///     @State private var volume = 0.2                       // 0…1
    ///
    ///     Text($volume.convert { "\(Int($0 * 100))%" })        // shown, never reported
    ///     Slider($volume.convert { $0 * 100 } back: { $0 / 100 })
    ///         .maximum(100)                                     // the thumb in percent
    ///
    /// The result is a state of its own: shown by a host it has its own
    /// channel and travels under `motion`, whatever its source travels under,
    /// and it is worked out from where the source is going, never from where
    /// the source stands on a frame. `back` says how a write into the result -
    /// the user's on a control, or the program's - lands on the source, in the
    /// source's own type; without it the result is read-only. A body that
    /// reads the result reads the source too, and is rebuilt when it moves.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from this state's. It reads nothing
    ///     but its argument and writes nothing.
    ///   - back: the source's value, from a derived one; nil where nothing is
    ///     written back.
    ///   - motion: how the result travels where a host shows it; the
    ///     application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<Out: StateValue>(
        _ transform: @escaping (Value) -> Out,
        back: ((Out) -> Value)? = nil,
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> {
        // The source reached as it stands when asked: a conversion made before its view's adoption follows the
        // adopted state.
        let (source, reach) = (storage, reach)

        let derived = source.derived(Out.self, at: PathNumber(file: file, line: line, column: column)) {
            ConversionEvaluation.run { transform(source.value) }
        }
        let conversion = derived.conversion ?? Conversion()

        conversion.declare(derived, from: [anyReach], upstream: source.conversion.map { [$0] } ?? [], motion: motion) {
            reach().map { transform($0.value) }
        }

        if let back {
            conversion.declareBack { value in
                guard let value = value as? Out, let source = reach() else { return nil }

                return [BackCandidate(source, back(value))]
            }
        }

        return Binding<Out>(over: derived)
    }
}

extension Conversion {
    /// Declares this conversion over `derived`: its sources, the conversions they are derived by, how the result
    /// travels, and the arithmetic, which answers nil while a source is gone. A declaration that would close a
    /// ring - a source worked out from this very result - is refused, said once, and the one before stands.
    /// Design: docs/design/core/journeys.md#conversions
    func declare<Out: StateValue>(
        _ derived: State<Out>.Storage,
        from sources: [() -> (any AnyStateStorage)?],
        upstream: [Conversion],
        motion: Motion,
        _ read: @escaping () -> Out?
    ) {
        guard !upstream.contains(where: { feeds($0) }) else {
            complain("A conversion was given a source worked out from its own result; the ring is refused and the "
                + "conversion stands as it was declared before.")
            return
        }

        declareAgain()
        reach(sources)
        self.upstream = upstream
        if derived.law.kind != .custom { derived.law = motion }
        forward = { [weak derived] asking in
            guard let derived, let value = ConversionEvaluation.run(read) else { return }

            derived.publish(value, asking: asking)
        }
        land = { [weak derived] in
            guard let derived, let value = ConversionEvaluation.run(read) else { return }

            derived.snap(value)
            derived.askForRender()
        }
        self.derived = { [weak derived] in derived }
        derivedValue = { [weak derived] in derived?.value }
        derived.conversion = self
    }
}

/// The evaluation of a conversion's arithmetic: while one runs, a state written or an act sent is refused and said.
/// Design: docs/design/core/journeys.md#conversions
@MainActor
enum ConversionEvaluation {
    /// Whether a conversion's arithmetic runs now.
    private(set) static var running = false

    /// Runs `arithmetic` as a conversion's.
    static func run<T>(_ arithmetic: () -> T) -> T {
        let outer = running
        running = true
        defer { running = outer }
        return arithmetic()
    }
}
