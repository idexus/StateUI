// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A binding converted on its way to a control: a second state the host carries,
// worked out by an engine the differ writes, with a way back for a control that
// reports.
// Design: docs/design/core/journeys.md#conversions

/// What the differ writes engines for: the sources, the arithmetic each way, and
/// the derived state.
@MainActor
final class Conversion {
    /// The sources, each as its binding reaches it when asked: the storage it was made from, held, answering the
    /// one it stands for - so a conversion made before its view's adoption, or kept past the box it was made from,
    /// reaches the state as it stands. The derived side knows this conversion weakly, so no ring closes.
    /// Design: docs/design/core/journeys.md#conversions
    private var reaches: [() -> (any AnyStateStorage)?] = []

    /// The sources that still exist, for a read at build to record and the back
    /// engine to write.
    var sources: [any AnyStateStorage] { reaches.compactMap { $0() } }

    /// Takes the sources as their bindings reach them.
    func reach(_ sources: [() -> (any AnyStateStorage)?]) {
        reaches = sources
    }

    /// The same, as what the forward engine follows.
    var follows: [any FollowedState] { sources }

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
            conversion.upstream.forEach(add)
            ordered.append(conversion)
        }
        add(self)
        return ordered
    }

    /// Works the derived value out and settles it, asking its readers where `asking`
    /// says - the engine does, a read at build does not.
    var forward: (_ asking: Bool) -> Void = { _ in }

    /// Works the sources out from the derived value, where a control reports into it - the current declaration's
    /// alone (`declareAgain`, `declareBack`).
    private(set) var back: (() -> Void)?

    /// Whether the declaration before this one wrote a way back.
    private var backBefore = false

    /// How many of the derived state's reports the way back has taken: a write of the derived state that is no
    /// report - the forward way's, settling what the application wrote - goes back to nobody.
    private var reportsTaken = 0

    /// The derived state, for the back engine to follow.
    var derived: () -> (any FollowedState)? = { nil }

    /// Starts a declaration of this conversion: the way back is what the new one writes, none unless it does.
    /// Design: docs/design/core/journeys.md#a-conversion-declared-again
    func declareAgain() {
        backBefore = back != nil
        back = nil
    }

    /// Says the way back this declaration writes. Written anew after a declaration with none, it takes only the
    /// reports made from now on.
    func declareBack(_ back: @escaping () -> Void) {
        if !backBefore, let reports = derived()?.reports { reportsTaken = reports }
        self.back = back
    }

    /// The engines for this conversion, ahead of every author's: the back one first,
    /// since a report is the newer word.
    /// Design: docs/design/core/journeys.md#conversions
    func declarations() -> [EngineDeclaration] {
        var made: [EngineDeclaration] = []

        if let back {
            made.append(
                EngineDeclaration(follows: derived().map { [$0] } ?? [], priority: -2) { [self] _ in
                    guard let reports = derived()?.reports, reports != reportsTaken else { return .wait }
                    reportsTaken = reports
                    back()
                    return .wait
                })
        }

        made.append(
            EngineDeclaration(follows: follows, priority: -1) { [self] _ in
                forward(true)
                return .wait
            })

        return made
    }
}

/// What a conversion needs of a source's storage without its type: whether a
/// build read it, where a derived state is kept, and its write count.
protocol AnyStateStorage: FollowedState {
    /// Whether any build has ever read this state.
    var readAtBuild: Bool { get set }

    /// The conversion this state is the derived side of, if it is one.
    var conversion: Conversion? { get }

    /// The derived state a conversion written at `key` keeps on this source.
    func derived<Out>(_: Out.Type, at key: PathNumber, make: @escaping () -> Out) -> State<Out>.Storage
}

extension Journey {
    /// The journey converted on its way to a control - words worked out from where
    /// the value is this frame, how fast, or where it is going - a second state the
    /// host carries, settled on every frame the value moves with nothing built.
    ///
    ///     @State private var offset = Point.zero
    ///
    ///     ScrollView { … }.scrollOffset($offset)
    ///     Text($offset.journey.convert { "\(Int($0.value.y)) down" })
    ///
    /// `$offset.convert { … }` converts the state instead, which is the destination.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from the journey as it stands.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<Out: StateValue>(
        _ transform: @escaping (Journey<Value>) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> {
        let source = storage

        // The image is made now, so the engine has a journey from its first run and a
        // body reading the result reads the journey.
        _ = source.walkedImage()

        let journey = self
        let derived = source.derived(Out.self, at: PathNumber(file: file, line: line, column: column)) { transform(journey) }
        let conversion = derived.conversion ?? Conversion()

        conversion.declareAgain()
        conversion.reach([anyReach])
        conversion.upstream = source.conversion.map { [$0] } ?? []
        conversion.forward = { [weak derived] (asking: Bool) in
            guard let derived else { return }

            derived.settle(transform(journey), asking: asking)
        }
        conversion.derived = { [weak derived] in derived }
        derived.conversion = conversion

        return Binding<Out>(over: derived)
    }
}

extension Binding where Value: StateValue {
    /// The conversion this binding is the derived side of, if it is one.
    var conversion: Conversion? { storage.conversion }

    /// This state converted on its way to a control: a second state the host
    /// carries, worked out from this one by an engine the differ writes, so
    /// the control shows `transform(value)` as the value moves and nothing is
    /// built for it. This library's own.
    ///
    ///     @State private var volume = 0.2                       // 0…1
    ///
    ///     Text($volume.convert { "\(Int($0 * 100))%" })        // shown, never reported
    ///     Slider($volume.convert { $0 * 100 } back: { $0 / 100 })
    ///         .maximum(100)                                     // the thumb in percent
    ///
    /// Handed to a control that reports, `back` says how a report lands on the
    /// source, in the source's own type; without it the control's reports go
    /// nowhere. A body that reads the result reads the source too, and is
    /// rebuilt when it moves.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from this state's.
    ///   - back: the source's value, from a reported derived one; nil where
    ///     nothing reports back.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<Out: StateValue>(
        _ transform: @escaping (Value) -> Out,
        back: ((Out) -> Value)? = nil,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> {
        // The source reached as it stands when asked: a conversion made before its view's adoption follows the
        // adopted state.
        let (source, reach) = (storage, reach)

        let derived = source.derived(Out.self, at: PathNumber(file: file, line: line, column: column)) { transform(source.value) }
        let conversion = derived.conversion ?? Conversion()

        conversion.declareAgain()
        conversion.reach([anyReach])
        conversion.upstream = source.conversion.map { [$0] } ?? []
        conversion.forward = { [weak derived] asking in
            guard let source = reach(), let derived else { return }

            derived.settle(transform(source.value), asking: asking)
        }
        conversion.derived = { [weak derived] in derived }
        derived.conversion = conversion

        if let back {
            conversion.declareBack { [weak derived] in
                guard let source = reach(), let derived else { return }

                source.settle(back(derived.value), asking: true)
                // A source that is a link of a chain carries the report on to its own sources.
                source.conversion?.back?()
            }
        }

        return Binding<Out>(over: derived)
    }
}
