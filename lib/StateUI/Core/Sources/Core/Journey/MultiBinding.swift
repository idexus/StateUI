// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// `.multi($a, $b).convert { … }`: several states read as one on their way to a
// control. The arities two to ten are written out, one overload each.
// Design: docs/design/core/journeys.md#many-sources

/// The states a `.multi` conversion reads, waiting for the arithmetic.
///
/// What `Binding.multi(_:_:)` answers. `Sources` is the tuple of their types,
/// which is what each `convert` overload is chosen by - so the closure's
/// arguments arrive with the types the states were declared with.
@MainActor
public struct MultiBinding<Out: StateValue, Sources> {
    /// Every source's value, read afresh when the engine runs - off the storage, so
    /// nothing that reads it at build becomes the sources' reader.
    let values: () -> Sources

    /// The sources' storages in the order named.
    /// Each source as its binding reaches it, as it stands when asked.
    let reaches: [() -> (any AnyStateStorage)?]

    /// The derived state: one object per line that wrote a conversion, kept on the
    /// first source, its destination worked out by the conversions' graph.
    func made(at key: PathNumber, motion: Motion, _ read: @escaping () -> Out) -> Binding<Out> {
        // Every source stands while the bindings `values` reads hold it.
        let parts = reaches.compactMap { $0() }
        let derived = parts[0].derived(Out.self, at: key) { ConversionEvaluation.run(read) }
        let conversion = derived.conversion ?? Conversion()

        conversion.declare(derived, from: reaches, upstream: parts.compactMap(\.conversion), motion: motion) { read() }

        return Binding<Out>(over: derived)
    }
}

extension Binding where Value: StateValue {
    /// 2 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Text(.multi($a, $b).convert { ... })
    ///
    /// - Parameters:
    ///   - a: source 1.
    ///   - b: source 2.
    /// - Returns: the sources, waiting for the arithmetic that makes them one.
    public static func multi<A: StateValue, B: StateValue>(
        _ a: Binding<A>, _ b: Binding<B>
    ) -> MultiBinding<Value, (A, B)> {
        MultiBinding(
            values: { (a.standing, b.standing) },
            reaches: [a.anyReach, b.anyReach])
    }

    /// 3 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Text(.multi($a, $b, $c).convert { ... })
    ///
    /// - Parameters:
    ///   - a: source 1.
    ///   - b: source 2.
    ///   - c: source 3.
    /// - Returns: the sources, waiting for the arithmetic that makes them one.
    public static func multi<A: StateValue, B: StateValue, C: StateValue>(
        _ a: Binding<A>, _ b: Binding<B>, _ c: Binding<C>
    ) -> MultiBinding<Value, (A, B, C)> {
        MultiBinding(
            values: { (a.standing, b.standing, c.standing) },
            reaches: [a.anyReach, b.anyReach, c.anyReach])
    }

    /// 4 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Text(.multi($a, $b, $c, $d).convert { ... })
    ///
    /// - Parameters:
    ///   - a: source 1.
    ///   - b: source 2.
    ///   - c: source 3.
    ///   - d: source 4.
    /// - Returns: the sources, waiting for the arithmetic that makes them one.
    public static func multi<A: StateValue, B: StateValue, C: StateValue, D: StateValue>(
        _ a: Binding<A>, _ b: Binding<B>, _ c: Binding<C>, _ d: Binding<D>
    ) -> MultiBinding<Value, (A, B, C, D)> {
        MultiBinding(
            values: { (a.standing, b.standing, c.standing, d.standing) },
            reaches: [a.anyReach, b.anyReach, c.anyReach, d.anyReach])
    }

    /// 5 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Text(.multi($a, $b, $c, $d, $e).convert { ... })
    ///
    /// - Parameters:
    ///   - a: source 1.
    ///   - b: source 2.
    ///   - c: source 3.
    ///   - d: source 4.
    ///   - e: source 5.
    /// - Returns: the sources, waiting for the arithmetic that makes them one.
    public static func multi<A: StateValue, B: StateValue, C: StateValue, D: StateValue, E: StateValue>(
        _ a: Binding<A>, _ b: Binding<B>, _ c: Binding<C>, _ d: Binding<D>, _ e: Binding<E>
    ) -> MultiBinding<Value, (A, B, C, D, E)> {
        MultiBinding(
            values: { (a.standing, b.standing, c.standing, d.standing, e.standing) },
            reaches: [a.anyReach, b.anyReach, c.anyReach, d.anyReach, e.anyReach])
    }

    /// 6 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Text(.multi($a, $b, $c, $d, $e, $f).convert { ... })
    ///
    /// - Parameters:
    ///   - a: source 1.
    ///   - b: source 2.
    ///   - c: source 3.
    ///   - d: source 4.
    ///   - e: source 5.
    ///   - f: source 6.
    /// - Returns: the sources, waiting for the arithmetic that makes them one.
    public static func multi<A: StateValue, B: StateValue, C: StateValue, D: StateValue, E: StateValue, F: StateValue>(
        _ a: Binding<A>, _ b: Binding<B>, _ c: Binding<C>, _ d: Binding<D>, _ e: Binding<E>, _ f: Binding<F>
    ) -> MultiBinding<Value, (A, B, C, D, E, F)> {
        MultiBinding(
            values: { (a.standing, b.standing, c.standing, d.standing, e.standing, f.standing) },
            reaches: [a.anyReach, b.anyReach, c.anyReach, d.anyReach, e.anyReach, f.anyReach])
    }

    /// 7 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Text(.multi($a, $b, $c, $d, $e, $f, $g).convert { ... })
    ///
    /// - Parameters:
    ///   - a: source 1.
    ///   - b: source 2.
    ///   - c: source 3.
    ///   - d: source 4.
    ///   - e: source 5.
    ///   - f: source 6.
    ///   - g: source 7.
    /// - Returns: the sources, waiting for the arithmetic that makes them one.
    public static func multi<A: StateValue, B: StateValue, C: StateValue, D: StateValue, E: StateValue, F: StateValue, G: StateValue>(
        _ a: Binding<A>, _ b: Binding<B>, _ c: Binding<C>, _ d: Binding<D>, _ e: Binding<E>, _ f: Binding<F>, _ g: Binding<G>
    ) -> MultiBinding<Value, (A, B, C, D, E, F, G)> {
        MultiBinding(
            values: { (a.standing, b.standing, c.standing, d.standing, e.standing, f.standing, g.standing) },
            reaches: [a.anyReach, b.anyReach, c.anyReach, d.anyReach, e.anyReach, f.anyReach, g.anyReach])
    }

    /// 8 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Text(.multi($a, $b, $c, $d, $e, $f, $g, $h).convert { ... })
    ///
    /// - Parameters:
    ///   - a: source 1.
    ///   - b: source 2.
    ///   - c: source 3.
    ///   - d: source 4.
    ///   - e: source 5.
    ///   - f: source 6.
    ///   - g: source 7.
    ///   - h: source 8.
    /// - Returns: the sources, waiting for the arithmetic that makes them one.
    public static func multi<A: StateValue, B: StateValue, C: StateValue, D: StateValue, E: StateValue, F: StateValue, G: StateValue, H: StateValue>(
        _ a: Binding<A>, _ b: Binding<B>, _ c: Binding<C>, _ d: Binding<D>, _ e: Binding<E>, _ f: Binding<F>, _ g: Binding<G>, _ h: Binding<H>
    ) -> MultiBinding<Value, (A, B, C, D, E, F, G, H)> {
        MultiBinding(
            values: { (a.standing, b.standing, c.standing, d.standing, e.standing, f.standing, g.standing, h.standing) },
            reaches: [a.anyReach, b.anyReach, c.anyReach, d.anyReach, e.anyReach, f.anyReach, g.anyReach, h.anyReach])
    }

    /// 9 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Text(.multi($a, $b, $c, $d, $e, $f, $g, $h, $i).convert { ... })
    ///
    /// - Parameters:
    ///   - a: source 1.
    ///   - b: source 2.
    ///   - c: source 3.
    ///   - d: source 4.
    ///   - e: source 5.
    ///   - f: source 6.
    ///   - g: source 7.
    ///   - h: source 8.
    ///   - i: source 9.
    /// - Returns: the sources, waiting for the arithmetic that makes them one.
    public static func multi<A: StateValue, B: StateValue, C: StateValue, D: StateValue, E: StateValue, F: StateValue, G: StateValue, H: StateValue, I: StateValue>(
        _ a: Binding<A>, _ b: Binding<B>, _ c: Binding<C>, _ d: Binding<D>, _ e: Binding<E>, _ f: Binding<F>, _ g: Binding<G>, _ h: Binding<H>, _ i: Binding<I>
    ) -> MultiBinding<Value, (A, B, C, D, E, F, G, H, I)> {
        MultiBinding(
            values: { (a.standing, b.standing, c.standing, d.standing, e.standing, f.standing, g.standing, h.standing, i.standing) },
            reaches: [a.anyReach, b.anyReach, c.anyReach, d.anyReach, e.anyReach, f.anyReach, g.anyReach, h.anyReach, i.anyReach])
    }

    /// 10 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Text(.multi($a, $b, $c, $d, $e, $f, $g, $h, $i, $j).convert { ... })
    ///
    /// - Parameters:
    ///   - a: source 1.
    ///   - b: source 2.
    ///   - c: source 3.
    ///   - d: source 4.
    ///   - e: source 5.
    ///   - f: source 6.
    ///   - g: source 7.
    ///   - h: source 8.
    ///   - i: source 9.
    ///   - j: source 10.
    /// - Returns: the sources, waiting for the arithmetic that makes them one.
    public static func multi<A: StateValue, B: StateValue, C: StateValue, D: StateValue, E: StateValue, F: StateValue, G: StateValue, H: StateValue, I: StateValue, J: StateValue>(
        _ a: Binding<A>, _ b: Binding<B>, _ c: Binding<C>, _ d: Binding<D>, _ e: Binding<E>, _ f: Binding<F>, _ g: Binding<G>, _ h: Binding<H>, _ i: Binding<I>, _ j: Binding<J>
    ) -> MultiBinding<Value, (A, B, C, D, E, F, G, H, I, J)> {
        MultiBinding(
            values: { (a.standing, b.standing, c.standing, d.standing, e.standing, f.standing, g.standing, h.standing, i.standing, j.standing) },
            reaches: [a.anyReach, b.anyReach, c.anyReach, d.anyReach, e.anyReach, f.anyReach, g.anyReach, h.anyReach, i.anyReach, j.anyReach])
    }
}

extension MultiBinding {
    /// The one value `a`, `b` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - motion: how the result travels where a host shows it; the application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B>(
        _ transform: @escaping (A, B) -> Out,
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B) {
        let values = values

        return made(at: PathNumber(file: file, line: line, column: column), motion: motion) {
            let read = values()

            return transform(read.0, read.1)
        }
    }

    /// The one value two states make, and the way back: a control's report lands
    /// on both, each in its own type.
    ///
    ///     Slider(.multi($hours, $minutes).convert { h, m in h * 60 + m } back: { total in
    ///         ((total / 60).rounded(.down), total.truncatingRemainder(dividingBy: 60))
    ///     })
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - back: both sources' values, from a reported derived one.
    ///   - motion: how the result travels where a host shows it; the application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A: StateValue, B: StateValue>(
        _ transform: @escaping (A, B) -> Out,
        back: @escaping (Out) -> (A, B),
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B) {
        let converted = convert(transform, motion: motion, file: file, line: line, column: column)
        let reaches = reaches

        // A write into the result goes back to both states `multi` was handed, each in its own type.
        converted.conversion?.declareBack { value in
            guard let value = value as? Out,
                  let first = reaches[0]() as? State<A>.Storage, let second = reaches[1]() as? State<B>.Storage
            else { return nil }

            let (one, two) = back(value)
            return [BackCandidate(first, one), BackCandidate(second, two)]
        }
        return converted
    }

    /// The one value `a`, `b`, `c` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - motion: how the result travels where a host shows it; the application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C>(
        _ transform: @escaping (A, B, C) -> Out,
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C) {
        let values = values

        return made(at: PathNumber(file: file, line: line, column: column), motion: motion) {
            let read = values()

            return transform(read.0, read.1, read.2)
        }
    }

    /// The one value `a`, `b`, `c`, `d` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - motion: how the result travels where a host shows it; the application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D>(
        _ transform: @escaping (A, B, C, D) -> Out,
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D) {
        let values = values

        return made(at: PathNumber(file: file, line: line, column: column), motion: motion) {
            let read = values()

            return transform(read.0, read.1, read.2, read.3)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - motion: how the result travels where a host shows it; the application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E>(
        _ transform: @escaping (A, B, C, D, E) -> Out,
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E) {
        let values = values

        return made(at: PathNumber(file: file, line: line, column: column), motion: motion) {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e`, `f` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - motion: how the result travels where a host shows it; the application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E, F>(
        _ transform: @escaping (A, B, C, D, E, F) -> Out,
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E, F) {
        let values = values

        return made(at: PathNumber(file: file, line: line, column: column), motion: motion) {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4, read.5)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e`, `f`, `g` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - motion: how the result travels where a host shows it; the application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E, F, G>(
        _ transform: @escaping (A, B, C, D, E, F, G) -> Out,
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E, F, G) {
        let values = values

        return made(at: PathNumber(file: file, line: line, column: column), motion: motion) {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4, read.5, read.6)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e`, `f`, `g`, `h` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - motion: how the result travels where a host shows it; the application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E, F, G, H>(
        _ transform: @escaping (A, B, C, D, E, F, G, H) -> Out,
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E, F, G, H) {
        let values = values

        return made(at: PathNumber(file: file, line: line, column: column), motion: motion) {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4, read.5, read.6, read.7)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e`, `f`, `g`, `h`, `i` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - motion: how the result travels where a host shows it; the application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E, F, G, H, I>(
        _ transform: @escaping (A, B, C, D, E, F, G, H, I) -> Out,
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E, F, G, H, I) {
        let values = values

        return made(at: PathNumber(file: file, line: line, column: column), motion: motion) {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4, read.5, read.6, read.7, read.8)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e`, `f`, `g`, `h`, `i`, `j` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - motion: how the result travels where a host shows it; the application's unless said.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E, F, G, H, I, J>(
        _ transform: @escaping (A, B, C, D, E, F, G, H, I, J) -> Out,
        motion: Motion = .inherited,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E, F, G, H, I, J) {
        let values = values

        return made(at: PathNumber(file: file, line: line, column: column), motion: motion) {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4, read.5, read.6, read.7, read.8, read.9)
        }
    }
}
