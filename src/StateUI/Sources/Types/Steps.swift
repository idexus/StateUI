// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which step a sequence is on, and how long it has been there. This library's
/// own.
///
///     enum Catch { case free, held, settling }
///
///     @EngineState private var phase = Phase(Catch.free)
///
///     .engine(following: $drag, $held) { cycle in
///         switch phase.current {
///         case .free where held: phase.go(to: .held)
///         case .held where !held: phase.go(to: .settling)
///         case .settling where phase.elapsed(cycle) > 300: phase.go(to: .free)
///         default: break
///         }
///     }
///
/// A sequence written as a `switch` over the step, with the conditions to leave
/// it beside each arm - which is what an engine that has to do one thing and
/// then another is. Kept in a `@EngineState`, so it holds across renders and the
/// engine that read it runs again when it moves.
///
/// The clock is the CYCLE's, never a date: `elapsed(_:)` stamps the step the
/// first time it is asked, so a step entered while nothing was moving starts
/// counting from the cycle that first looked at it rather than from whenever it
/// was written.
public struct Phase<Step: Equatable & Sendable>: Sendable {
    /// Which step it is on.
    public private(set) var current: Step

    /// When the step was first seen, in milliseconds on the cycle's clock, or
    /// nil while nothing has looked at it yet.
    public private(set) var entered: Double?

    /// A sequence standing on its first step.
    ///
    /// - Parameter step: where it starts.
    public init(_ step: Step) {
        current = step
    }

    /// How long this step has been running, in milliseconds.
    ///
    /// Nought on the cycle that first asks, which is what stamps the step.
    ///
    /// - Parameter cycle: the cycle asking.
    /// - Returns: milliseconds since the step was first seen.
    public mutating func elapsed(_ cycle: EngineCycle) -> Double {
        guard let entered else {
            self.entered = cycle.now
            return 0
        }

        return max(0, cycle.now - entered)
    }

    /// Moves to a step, whose clock starts at the next cycle that asks.
    ///
    /// Writing the step it is already on RE-ENTERS it: the clock starts over,
    /// which is what a step that repeats means.
    ///
    /// - Parameter step: where to go.
    public mutating func go(to step: Step) {
        current = step
        entered = nil
    }
}
