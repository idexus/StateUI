// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A BINDING CONVERTED ON ITS WAY TO A CONTROL.
//
// `$volume.convert { $0 * 100 }` is a second state the host carries, worked
// out from the first by an engine the differ writes for you: whenever the
// source moves, the engine runs on the display's frames and settles the
// derived value where the control reads it. `.convertBack { $0 / 100 }` is the
// engine the other way, for a control that reports - a slider's thumb, a
// stepper's press, a switch - so what the reader did lands on the source in
// the source's own terms. Two sources make one derived value with
// `$a.convert(with: $b) { a, b in … }`, and `.convertBack { out in (a, b) }`
// sends a report back into both.
//
// NOTHING IS READ AT BUILD BY HANDING ONE ON: the derived state goes to a
// control as `$x` does, so converting costs the arithmetic on the host's
// frames and no render. The derived state is ONE object across renders - kept
// on its first source under the line that wrote the conversion - so the tie
// the host holds keeps its number from render to render. A body that READS a
// conversion reads its sources: the value is worked out afresh on the read,
// and the body is a reader of every source, rebuilt when any of them moves.
//
// `convertBack` is meant to be the inverse of `convert`. Where it is not
// exactly - a rounding, a clamp - the source settles on the value the round
// trip lands on, once, and both sides then agree.

/// What the differ writes an engine or two for: the sources a derived state
/// is worked out from, the arithmetic each way, and where the derived image
/// is.
final class Conversion: @unchecked Sendable {
    /// The sources, which the forward engine follows.
    var follows: [any FollowedState] = []

    /// The sources themselves, for a read at build to record and for the back
    /// engine to write into.
    var sources: [any AnyStateStorage] = []

    /// Works the derived value out from the sources and settles it - asking
    /// the derived state's readers for a render where `asking` says so, which
    /// the engine does and a read at build does not.
    var forward: (_ asking: Bool) -> Void = { _ in }

    /// Works the sources out from the derived value and settles them, where a
    /// control reports into the derived state.
    var back: (() -> Void)?

    /// The derived state, for the back engine to follow.
    var derived: () -> (any FollowedState)? = { nil }

    /// The engines the differ arms for this conversion, on the element that
    /// wears the derived state - both ahead of every engine an author wrote,
    /// so one following the derived state sees the converted value in the
    /// same cycle. THE BACK ONE RUNS FIRST: a report is the newer word, and
    /// the forward one then derives again from what it landed - which is
    /// what keeps a report that arrives in the very cycle the engines first
    /// run from being derived over by the sources it has not reached yet.
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

/// The part of a state's storage a conversion needs without knowing the value's
/// type: that a build read it, where a derived state is kept, and - being a
/// source the conversion's engine follows - how many times it was written.
protocol AnyStateStorage: FollowedState {
    /// Whether any build has ever read this state.
    var readAtBuild: Bool { get set }

    /// The derived state a conversion written at `key` keeps - the first
    /// source of a `.multi` is where it lives, as it is for `convert(_:)`.
    func derived<Out>(_: Out.Type, at key: String, make: @escaping () -> Out) -> State<Out>.Storage
}

extension Journey {
    /// The JOURNEY converted on its way to a control - words worked out from
    /// where the value IS this frame, how fast it is going, or where it is
    /// going - a second state the host carries, settled by an engine the
    /// differ writes on every frame the value moves, so the control shows
    /// `transform(journey)` as it walks and nothing is built for it.
    ///
    ///     @State private var offset = Point.zero
    ///
    ///     ScrollView { … }.scroll($offset)
    ///     Label($offset.journey.convert { "\(Int($0.value.y)) down" })
    ///
    /// `$offset.convert { … }` beside it is a conversion of the STATE, which
    /// is the destination - the number a plain read answers, worked out once
    /// per write. This one follows the walk, and costs no render either way.
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

        // The image is made now, so the engine below has a journey to read
        // from its first run - and so a body reading the result is a reader of
        // the journey, which is what makes the words move for it too.
        _ = source.walkedImage()

        let journey = self
        let derived = source.derived(Out.self, at: "\(file):\(line):\(column)") { transform(journey) }
        let conversion = derived.conversion ?? Conversion()

        conversion.follows = [source]
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
    /// Two journeys converted into one value - the words for a point, a
    /// distance between two walks - settled on every frame either moves.
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

        conversion.follows = [source, second]
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

        conversion.follows = [source]
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

        conversion.follows = [source, second]
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
