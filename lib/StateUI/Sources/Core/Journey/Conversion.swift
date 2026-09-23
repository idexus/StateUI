// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A binding converted on its way to a control: a second state the host carries,
// worked out by an engine the differ writes, with `convertBack` for a control
// that reports.
// Design: docs/design/core/journeys.md#conversions

/// What the differ writes engines for: the sources, the arithmetic each way, and
/// the derived state.
final class Conversion: @unchecked Sendable {
    /// The sources, weakly: held strongly, they would make a ring nothing breaks.
    /// Design: docs/design/core/journeys.md#conversions
    private var kept: [WeakSource] = []

    /// The sources that still exist, for a read at build to record and the back
    /// engine to write.
    var sources: [any AnyStateStorage] {
        get { kept.compactMap { $0.storage } }
        set { kept = newValue.map { WeakSource($0) } }
    }

    /// The same, as what the forward engine follows.
    var follows: [any FollowedState] { sources }

    /// Works the derived value out and settles it, asking its readers where `asking`
    /// says - the engine does, a read at build does not.
    var forward: (_ asking: Bool) -> Void = { _ in }

    /// Works the sources out from the derived value, where a control reports into it.
    var back: (() -> Void)?

    /// The derived state, for the back engine to follow.
    var derived: () -> (any FollowedState)? = { nil }

    /// The engines for this conversion, ahead of every author's: the back one first,
    /// since a report is the newer word.
    /// Design: docs/design/core/journeys.md#conversions
    func declarations() -> [EngineDeclaration] {
        var made: [EngineDeclaration] = []

        if let back {
            made.append(
                EngineDeclaration(follows: derived().map { [$0] } ?? [], sync: .display, priority: -2) { _ in
                    back()
                    return .wait
                })
        }

        made.append(
            EngineDeclaration(follows: follows, sync: .display, priority: -1) { [self] _ in
                forward(true)
                return .wait
            })

        return made
    }
}

/// One source as the conversion knows it: weakly.
final class WeakSource: @unchecked Sendable {
    weak var storage: (any AnyStateStorage)?

    init(_ storage: any AnyStateStorage) { self.storage = storage }
}

/// What a conversion needs of a source's storage without its type: whether a
/// build read it, where a derived state is kept, and its write count.
protocol AnyStateStorage: FollowedState {
    /// Whether any build has ever read this state.
    var readAtBuild: Bool { get set }

    /// The derived state a conversion written at `key` keeps on this source.
    func derived<Out>(_: Out.Type, at key: String, make: @escaping () -> Out) -> State<Out>.Storage
}

extension Journey {
    /// The journey converted on its way to a control - words worked out from where
    /// the value is this frame, how fast, or where it is going - a second state the
    /// host carries, settled on every frame the value moves with nothing built.
    ///
    ///     @State private var offset = Point.zero
    ///
    ///     ScrollView { … }.scrollOffset($offset)
    ///     Label($offset.journey.convert { "\(Int($0.value.y)) down" })
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
        guard let source = storage else {
            complain("`journey.convert` was called on a part of a state, or a binding made "
                + "from closures, which the host cannot walk. The value is worked out at "
                + "build instead, and nothing reports back through it.")
            return Binding<Out>(get: { transform(self) }, set: { _ in })
        }

        // The image is made now, so the engine has a journey from its first run and a
        // body reading the result reads the journey.
        _ = source.walkedImage()

        let journey = self
        let derived = source.derived(Out.self, at: "\(file):\(line):\(column)") { transform(journey) }
        let conversion = derived.conversion ?? Conversion()

        conversion.sources = [source]
        conversion.forward = { [weak derived] (asking: Bool) in
            guard let derived else { return }

            derived.settle(transform(journey), asking: asking)
        }
        conversion.derived = { [weak derived] in derived }
        derived.conversion = conversion

        return Binding<Out>(over: derived)
    }
}

extension Journey {
    /// Two journeys converted into one value - the words for a point, the distance
    /// between two animated values - settled on every frame either moves.
    ///
    ///     Label($liveX.journey.convert(with: $liveY.journey) { x, y in
    ///         "at \(Int(x.value)), \(Int(y.value))"
    ///     })
    ///
    /// - Parameters:
    ///   - other: the second journey.
    ///   - transform: the derived value, from both as they stand.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<Other: Walked, Out: StateValue>(
        with other: Journey<Other>,
        _ transform: @escaping (Journey<Value>, Journey<Other>) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> {
        guard let source = storage, let second = other.storage else {
            complain("`journey.convert(with:)` was handed a part of a state, or a binding "
                + "made from closures, which the host cannot walk. The value is worked "
                + "out at build instead, and nothing reports back through it.")
            return Binding<Out>(get: { transform(self, other) }, set: { _ in })
        }

        _ = source.walkedImage()
        _ = second.walkedImage()

        let journey = self
        let derived = source.derived(Out.self, at: "\(file):\(line):\(column)") {
            transform(journey, other)
        }
        let conversion = derived.conversion ?? Conversion()

        conversion.sources = [source, second]
        conversion.forward = { [weak derived] (asking: Bool) in
            guard let derived else { return }

            derived.settle(transform(journey, other), asking: asking)
        }
        conversion.derived = { [weak derived] in derived }
        derived.conversion = conversion

        return Binding<Out>(over: derived)
    }
}

extension Binding where Value: StateValue {
    /// The conversion this binding is the derived side of, if it is one.
    var conversion: Conversion? { described?.conversion }

    /// This state converted on its way to a control: a second state the host
    /// carries, worked out from this one by an engine the differ writes, so
    /// the control shows `transform(value)` as the value moves and nothing is
    /// built for it. This library's own.
    ///
    ///     @State private var volume = 0.2                       // 0…1
    ///
    ///     Slider($volume.convert { $0 * 100 }.convertBack { $0 / 100 })
    ///         .maximum(100)                                     // the thumb in percent
    ///
    /// Handed to a control that reports, `convertBack` says how a report lands
    /// on the source; without it the control's reports go nowhere. A body that
    /// reads the result reads the source too, and is rebuilt when it moves.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from this state's.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<Out: StateValue>(
        _ transform: @escaping (Value) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> {
        guard let source = described else {
            complain("`convert` was called on a part of a state, or a binding made from "
                + "closures, which the host cannot carry. The value is worked out at "
                + "build instead, and nothing reports back through it.")
            return Binding<Out>(get: { transform(self.wrappedValue) }, set: { _ in })
        }

        let derived = source.derived(Out.self, at: "\(file):\(line):\(column)") { transform(source.value) }
        let conversion = derived.conversion ?? Conversion()

        conversion.sources = [source]
        conversion.forward = { [weak source, weak derived] asking in
            guard let source, let derived else { return }

            derived.settle(transform(source.value), asking: asking)
        }
        conversion.derived = { [weak derived] in derived }
        derived.conversion = conversion

        return Binding<Out>(over: derived)
    }

    /// Two states converted into one on their way to a control - a sum, a
    /// ratio, a caption from two numbers - by an engine following both.
    /// This library's own.
    ///
    ///     Label().text($width.convert(with: $height) { w, h in "\(Int(w))×\(Int(h))" })
    ///
    /// - Parameters:
    ///   - other: the second state.
    ///   - transform: the derived value, from both.
    ///   - file: where the conversion is written, as for `convert(_:)`.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<Other: StateValue, Out: StateValue>(
        with other: Binding<Other>,
        _ transform: @escaping (Value, Other) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> {
        guard let source = described, let second = other.described else {
            complain("`convert(with:)` was handed a part of a state, or a binding made "
                + "from closures, which the host cannot carry. The value is worked out "
                + "at build instead, and nothing reports back through it.")
            return Binding<Out>(get: { transform(self.wrappedValue, other.wrappedValue) }, set: { _ in })
        }

        let derived = source.derived(Out.self, at: "\(file):\(line):\(column)") {
            transform(source.value, second.value)
        }
        let conversion = derived.conversion ?? Conversion()

        conversion.sources = [source, second]
        conversion.forward = { [weak source, weak second, weak derived] asking in
            guard let source, let second, let derived else { return }

            derived.settle(transform(source.value, second.value), asking: asking)
        }
        conversion.derived = { [weak derived] in derived }
        derived.conversion = conversion

        return Binding<Out>(over: derived)
    }

    /// How a report into a converted state lands on its source: the engine the
    /// other way, run whenever the derived state moves. This library's own.
    ///
    ///     Stepper($celsius.convert { $0 * 9 / 5 + 32 }.convertBack { ($0 - 32) * 5 / 9 })
    ///
    /// Written after `convert(_:)` and nowhere else: on a binding that is not a
    /// conversion, or with the wrong type for the source, it says so and
    /// writes nothing back.
    ///
    /// - Parameter transform: the source's value, from the derived one.
    /// - Returns: the same derived state, now reporting back.
    public func convertBack<Source: StateValue>(_ transform: @escaping (Value) -> Source) -> Binding<Value> {
        guard let derived = described,
              let conversion = derived.conversion,
              conversion.sources.count == 1,
              let source = conversion.sources[0] as? State<Source>.Storage
        else {
            complain("`convertBack` was written on a binding that is not a conversion of "
                + "one whole state, or with a type its source is not. Nothing is written "
                + "back.")
            return self
        }

        conversion.back = { [weak source, weak derived] in
            guard let source, let derived else { return }

            source.settle(transform(derived.value), asking: true)
        }

        return self
    }

    /// The same for a conversion of two states: a report lands on both.
    ///
    /// - Parameter transform: both sources' values, from the derived one.
    /// - Returns: the same derived state, now reporting back.
    public func convertBack<First: StateValue, Second: StateValue>(
        _ transform: @escaping (Value) -> (First, Second)
    ) -> Binding<Value> {
        guard let derived = described,
              let conversion = derived.conversion,
              conversion.sources.count == 2,
              let first = conversion.sources[0] as? State<First>.Storage,
              let second = conversion.sources[1] as? State<Second>.Storage
        else {
            complain("`convertBack` was written on a binding that is not a conversion of "
                + "two whole states, or with types its sources are not. Nothing is "
                + "written back.")
            return self
        }

        conversion.back = { [weak first, weak second, weak derived] in
            guard let first, let second, let derived else { return }

            let (one, two) = transform(derived.value)

            first.settle(one, asking: true)
            second.settle(two, asking: true)
        }

        return self
    }
}
