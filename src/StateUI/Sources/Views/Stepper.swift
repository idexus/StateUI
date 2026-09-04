// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: Stepper.

/// Stepper's own properties - the half a `Style<Stepper>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol StepperProperties: PropertyContainer {}

extension StepperProperties {
    /// The number it is showing, between `minimum` and `maximum`.
    /// MAUI: Stepper.Value.
    ///
    /// `Stepper(1)` and `Stepper($count)` both say this from their argument, so
    /// a modifier written beside one wins - and a binding goes on being written
    /// back to, which is how the two can then disagree.
    public func value(_ value: Double) -> Modified {
        setValue(.value, .number(value))
    }

    /// The lowest it goes - the minus button stops here.
    /// MAUI: Stepper.Minimum, which is 0 until told otherwise.
    public func minimum(_ value: Double) -> Modified {
        setValue(.minimum, .number(value))
    }

    /// The highest it goes - the plus button stops here.
    /// MAUI: Stepper.Maximum, which is 100 until told otherwise.
    public func maximum(_ value: Double) -> Modified {
        setValue(.maximum, .number(value))
    }

    /// How far one tap moves the value.
    /// MAUI: Stepper.Increment, which is 1 until told otherwise.
    public func increment(_ value: Double) -> Modified {
        setValue(.increment, .number(value))
    }
}

/// A number changed one step at a time, by two buttons. MAUI: Stepper.
///
///     Stepper($servings)
///         .minimum(1)
///         .maximum(12)
///         .increment(1)
///
/// A Slider for a value with few enough steps to name: where a slider is dragged
/// to somewhere about right, a stepper is tapped to exactly four.
///
/// Given a binding it shows the value and writes every step back. Given a number
/// it shows that, and `.onValueChanged` is how the step gets anywhere.
public struct Stepper: View, StepperProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Stepper>` is written against.
    public init() {
        node = Node(type: .stepper)
    }

    /// A stepper sitting at `value`. One-way: the step goes nowhere without
    /// `.onValueChanged`.
    public init(_ value: Double) {
        node = Node(type: .stepper, props: [.value: .number(value)])
    }

    /// Two-way: shows what the binding holds, and writes back what is stepped
    /// to.
    ///
    ///     @State private var count = 1.0
    ///
    ///     Stepper($count)
    ///
    /// DESCRIBED, so every press is a render - which is what a value the tree
    /// shows costs. A state declared driven takes the SAME spelling and costs
    /// none: see `init(_:)` over `AnimatedValue`.
    public init(_ value: Binding<Double>) {
        self = Stepper().value(value)
    }

    /// The same spelling over a state the HOST moves, exactly as a `Slider`'s
    /// is - and the declaration is the only place that says which:
    ///
    ///     @State private var count = 1.0                  // described
    ///     @DrivenState
    ///     private var steps = AnimatedValue(1.0)          // driven
    ///
    ///     Stepper($count)      // every press is a render
    ///     Stepper($steps)      // no press is
    ///
    /// A Stepper draws its two buttons and NO number, so a driven one wants a
    /// reading beside it - a driven text an engine writes, since a view cannot
    /// show a driven state.
    public init(_ state: Binding<AnimatedValue<Double>>) {
        self = Stepper().value(state)
    }

    /// The same two-way value as `Stepper($value)`, written as a modifier.
    ///
    ///     Stepper($level)
    ///     Stepper().value($level)
    ///
    /// BOTH SPELLINGS ALWAYS, and they mean the same thing: the initializer is
    /// the short way to say what gives this control its purpose, and the
    /// modifier is the way every other property is written. Neither is the
    /// real one.
    ///
    /// - Parameter value: the state shown, and written back into as the reader
    ///   moves it.
    /// - Returns: the control, showing and reporting that value.
    public func value(_ value: Binding<Double>) -> Modified {
        modified {
            $0.props[.value] = .number(value.wrappedValue)
            $0.armed[.value] = value.flightKey

            $0.addHandler(.valueChanged) {
                guard !value.isFlying else { return }

                if let stepped = EventBuffer.current.value()?.number {
                    value.snap(to: stepped)
                }
            }
        }
    }

    // MARK: Properties

    // MARK: Events

    /// Fires on every tap of either button, with the value stepped to - MAUI's
    /// `ValueChangedEventArgs.NewValue`. Runs after a binding's write, if there
    /// is one. MAUI: Stepper.ValueChanged.
    public func onValueChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
        addHandler(.valueChanged) {
            // A payload that will not parse leaves the handler alone, the rule
            // every gesture follows.
            if let value = EventBuffer.current.value()?.number {
                try await handler(value)
            }
        }
    }
}
