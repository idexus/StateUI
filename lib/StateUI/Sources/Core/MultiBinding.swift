// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// SEVERAL STATES READ AS ONE, on their way to a control.
//
//     Label(.multi($info, $value).convert { "\($0) = \($1)" })
//
// The same machinery `convert(_:)` is built on, over as many states as are
// named: the derived value is a second state the host carries, worked out by
// an engine the differ writes, so it costs the arithmetic on the display's own
// frames and no render at all. `.multi` is a static member of `Binding`, so
// the leading dot resolves against the type the control takes - and what a
// reader writes is the pair, the states and then the arithmetic over them.
//
// THE ARITIES ARE WRITTEN OUT, two to ten, and this file is GENERATED. A
// parameter pack looks like the answer and is not: capturing one in the
// escaping closure that reads the sources crashes the 6.3 compiler, and
// shorthand closure arguments have no arity to bind to over a pack. What the
// spelled-out arities buy is exactly that - `$0`, `$1` at the call site, each
// with the source's own type.

/// The states a `.multi` conversion reads, waiting for the arithmetic.
///
/// What `Binding.multi(_:_:)` answers. `Sources` is the tuple of their types,
/// which is what each `convert` overload is chosen by - so the closure's
/// arguments arrive with the types the states were declared with.
public struct MultiBinding<Out: StateValue, Sources> {
    /// Every source's value, read afresh whenever the engine runs.
    ///
    /// Read off the STORAGE and not through the binding: a read through the
    /// binding at build would record one, which would make the closure that
    /// wrote the conversion a reader of every source - and the whole point of
    /// handing a state on is that it is not.
    let values: () -> Sources

    /// The sources' storages, in the order they were named - nothing where a
    /// binding was a part of a state or made from closures, which is what the
    /// complaint below is about.
    let parts: [(any AnyStateStorage)?]

    /// The derived state itself: one object per line that wrote a conversion,
    /// kept on the first source, with the engine that keeps it up to date.
    ///
    /// - Parameters:
    ///   - key: where the conversion is written, which is what keeps the
    ///     derived state one object across renders.
    ///   - read: the arithmetic over the sources.
    /// - Returns: the derived state, to hand on.
    func made(at key: String, _ read: @escaping () -> Out) -> Binding<Out> {
        let storages = parts.compactMap { $0 }

        guard storages.count == parts.count, let first = storages.first else {
            complain("`multi` was handed a part of a state, or a binding made from "
                + "closures, which the host cannot carry. The value is worked out at "
                + "build instead, and nothing reports back through it.")
            return Binding<Out>(get: read, set: { _ in })
        }

        let derived = first.derived(Out.self, at: key, make: read)
        let conversion = derived.conversion ?? Conversion()

        conversion.sources = storages
        conversion.forward = { [weak derived] asking in
            guard let derived else { return }

            derived.settle(read(), asking: asking)
        }
        conversion.derived = { [weak derived] in derived }
        derived.conversion = conversion

        return Binding<Out>(over: derived)
    }
}

extension Binding where Value: StateValue {
    /// 2 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Label(.multi($a, $b).convert { ... })
    ///
    /// - Parameters:
    ///   - a: source 1.
    ///   - b: source 2.
    /// - Returns: the sources, waiting for the arithmetic that makes them one.
    public static func multi<A: StateValue, B: StateValue>(
        _ a: Binding<A>, _ b: Binding<B>
    ) -> MultiBinding<Value, (A, B)> {
        MultiBinding(
            values: { (a.described?.value ?? a.wrappedValue, b.described?.value ?? b.wrappedValue) },
            parts: [a.described, b.described])
    }

    /// 3 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Label(.multi($a, $b, $c).convert { ... })
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
            values: { (a.described?.value ?? a.wrappedValue, b.described?.value ?? b.wrappedValue, c.described?.value ?? c.wrappedValue) },
            parts: [a.described, b.described, c.described])
    }

    /// 4 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Label(.multi($a, $b, $c, $d).convert { ... })
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
            values: { (a.described?.value ?? a.wrappedValue, b.described?.value ?? b.wrappedValue, c.described?.value ?? c.wrappedValue, d.described?.value ?? d.wrappedValue) },
            parts: [a.described, b.described, c.described, d.described])
    }

    /// 5 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Label(.multi($a, $b, $c, $d, $e).convert { ... })
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
            values: { (a.described?.value ?? a.wrappedValue, b.described?.value ?? b.wrappedValue, c.described?.value ?? c.wrappedValue, d.described?.value ?? d.wrappedValue, e.described?.value ?? e.wrappedValue) },
            parts: [a.described, b.described, c.described, d.described, e.described])
    }

    /// 6 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Label(.multi($a, $b, $c, $d, $e, $f).convert { ... })
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
            values: { (a.described?.value ?? a.wrappedValue, b.described?.value ?? b.wrappedValue, c.described?.value ?? c.wrappedValue, d.described?.value ?? d.wrappedValue, e.described?.value ?? e.wrappedValue, f.described?.value ?? f.wrappedValue) },
            parts: [a.described, b.described, c.described, d.described, e.described, f.described])
    }

    /// 7 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Label(.multi($a, $b, $c, $d, $e, $f, $g).convert { ... })
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
            values: { (a.described?.value ?? a.wrappedValue, b.described?.value ?? b.wrappedValue, c.described?.value ?? c.wrappedValue, d.described?.value ?? d.wrappedValue, e.described?.value ?? e.wrappedValue, f.described?.value ?? f.wrappedValue, g.described?.value ?? g.wrappedValue) },
            parts: [a.described, b.described, c.described, d.described, e.described, f.described, g.described])
    }

    /// 8 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Label(.multi($a, $b, $c, $d, $e, $f, $g, $h).convert { ... })
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
            values: { (a.described?.value ?? a.wrappedValue, b.described?.value ?? b.wrappedValue, c.described?.value ?? c.wrappedValue, d.described?.value ?? d.wrappedValue, e.described?.value ?? e.wrappedValue, f.described?.value ?? f.wrappedValue, g.described?.value ?? g.wrappedValue, h.described?.value ?? h.wrappedValue) },
            parts: [a.described, b.described, c.described, d.described, e.described, f.described, g.described, h.described])
    }

    /// 9 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Label(.multi($a, $b, $c, $d, $e, $f, $g, $h, $i).convert { ... })
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
            values: { (a.described?.value ?? a.wrappedValue, b.described?.value ?? b.wrappedValue, c.described?.value ?? c.wrappedValue, d.described?.value ?? d.wrappedValue, e.described?.value ?? e.wrappedValue, f.described?.value ?? f.wrappedValue, g.described?.value ?? g.wrappedValue, h.described?.value ?? h.wrappedValue, i.described?.value ?? i.wrappedValue) },
            parts: [a.described, b.described, c.described, d.described, e.described, f.described, g.described, h.described, i.described])
    }

    /// 10 states read as one on their way to a control, in the order they
    /// are named. This library's own.
    ///
    ///     Label(.multi($a, $b, $c, $d, $e, $f, $g, $h, $i, $j).convert { ... })
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
            values: { (a.described?.value ?? a.wrappedValue, b.described?.value ?? b.wrappedValue, c.described?.value ?? c.wrappedValue, d.described?.value ?? d.wrappedValue, e.described?.value ?? e.wrappedValue, f.described?.value ?? f.wrappedValue, g.described?.value ?? g.wrappedValue, h.described?.value ?? h.wrappedValue, i.described?.value ?? i.wrappedValue, j.described?.value ?? j.wrappedValue) },
            parts: [a.described, b.described, c.described, d.described, e.described, f.described, g.described, h.described, i.described, j.described])
    }
}

extension MultiBinding {
    /// The one value `a`, `b` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B>(
        _ transform: @escaping (A, B) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B) {
        let values = values

        return made(at: "\(file):\(line):\(column)") {
            let read = values()

            return transform(read.0, read.1)
        }
    }

    /// The one value `a`, `b`, `c` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C>(
        _ transform: @escaping (A, B, C) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C) {
        let values = values

        return made(at: "\(file):\(line):\(column)") {
            let read = values()

            return transform(read.0, read.1, read.2)
        }
    }

    /// The one value `a`, `b`, `c`, `d` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D>(
        _ transform: @escaping (A, B, C, D) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D) {
        let values = values

        return made(at: "\(file):\(line):\(column)") {
            let read = values()

            return transform(read.0, read.1, read.2, read.3)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E>(
        _ transform: @escaping (A, B, C, D, E) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E) {
        let values = values

        return made(at: "\(file):\(line):\(column)") {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e`, `f` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E, F>(
        _ transform: @escaping (A, B, C, D, E, F) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E, F) {
        let values = values

        return made(at: "\(file):\(line):\(column)") {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4, read.5)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e`, `f`, `g` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E, F, G>(
        _ transform: @escaping (A, B, C, D, E, F, G) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E, F, G) {
        let values = values

        return made(at: "\(file):\(line):\(column)") {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4, read.5, read.6)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e`, `f`, `g`, `h` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E, F, G, H>(
        _ transform: @escaping (A, B, C, D, E, F, G, H) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E, F, G, H) {
        let values = values

        return made(at: "\(file):\(line):\(column)") {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4, read.5, read.6, read.7)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e`, `f`, `g`, `h`, `i` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E, F, G, H, I>(
        _ transform: @escaping (A, B, C, D, E, F, G, H, I) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E, F, G, H, I) {
        let values = values

        return made(at: "\(file):\(line):\(column)") {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4, read.5, read.6, read.7, read.8)
        }
    }

    /// The one value `a`, `b`, `c`, `d`, `e`, `f`, `g`, `h`, `i`, `j` make, worked out by an engine the differ writes -
    /// so it costs the arithmetic on the host's own frames and no render.
    ///
    /// - Parameters:
    ///   - transform: the derived value, from each source in turn.
    ///   - file: where the conversion is written - which, with the line, is
    ///     what keeps the derived state one object across renders.
    ///   - line: the same.
    ///   - column: the same.
    /// - Returns: the derived state, to hand on.
    public func convert<A, B, C, D, E, F, G, H, I, J>(
        _ transform: @escaping (A, B, C, D, E, F, G, H, I, J) -> Out,
        file: StaticString = #fileID,
        line: UInt = #line,
        column: UInt = #column
    ) -> Binding<Out> where Sources == (A, B, C, D, E, F, G, H, I, J) {
        let values = values

        return made(at: "\(file):\(line):\(column)") {
            let read = values()

            return transform(read.0, read.1, read.2, read.3, read.4, read.5, read.6, read.7, read.8, read.9)
        }
    }
}
