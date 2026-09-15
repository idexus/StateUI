// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A number changed one step at a time.

/// Stepper's own properties - the half a `Style<Stepper>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol StepperProperties: PropertyContainer {}

extension StepperProperties {
    /// The number it is showing, between `minimum` and `maximum`.
    ///
    /// `Stepper(1)` and `Stepper($count)` both say this from their argument, so
    /// a modifier written beside one wins - and a binding goes on being written
    /// back to, which is how the two can then disagree.
    public func value(_ value: Double) -> Modified {
        setValue(StepperContract.value, value)
    }

    /// The lowest it goes - the minus button stops here.
    /// It is 0 until told otherwise.
    public func minimum(_ value: Double) -> Modified {
        setValue(StepperContract.minimum, value)
    }

    /// The highest it goes - the plus button stops here.
    /// It is 100 until told otherwise.
    public func maximum(_ value: Double) -> Modified {
        setValue(StepperContract.maximum, value)
    }

    /// How far one tap moves the value.
    /// It is 1 until told otherwise.
    public func step(_ value: Double) -> Modified {
        setValue(StepperContract.step, value)
    }
}

/// A number changed one step at a time, by two buttons.
///
///     Stepper($servings)
///         .minimum(1)
///         .maximum(12)
///         .step(1)
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
        node = Node(contract: StepperContract.self)
    }

    /// A stepper sitting at `value`. One-way: the step goes nowhere without
    /// `.onValueChanged`.
    public init(_ value: Double) {
        node = Node(contract: StepperContract.self)
        node.write(StepperContract.value, value)
    }

    /// Two-way: shows what the state holds and writes back what is stepped to
    /// - and HANDED OVER, so the stepper is no reader of the state.
    ///
    ///     @State private var count = 1.0
    ///
    ///     Stepper($count)
    ///
    /// The host carries the value as a journey, as a `Slider`'s: an assignment
    /// sends it under the element's law, a press is written back landed, and
    /// what a press COSTS is decided by who reads `count` at build. A Stepper
    /// draws its two buttons and NO number, so the reading beside it is either
    /// a body that prints `count` - a render per press - or a text an engine
    /// writes, which costs none.
    public init(_ value: Binding<Double>) {
        self = Stepper().value(value)
    }

    /// The same two-way value as `Stepper($value)`, written as a modifier.
    ///
    ///     Stepper($count)
    ///     Stepper().value($count)
    ///
    /// BOTH SPELLINGS ALWAYS, and they mean the same thing: the initializer is
    /// the short way to say what gives this control its purpose, and the
    /// modifier is the way every other property is written. Neither is the
    /// real one.
    ///
    /// - Parameter value: the state the stepper shows and writes back into,
    ///   carried by the host as a journey.
    /// - Returns: the control, wearing and reporting that value.
    public func value(_ value: Binding<Double>) -> Modified {
        journey(StepperContract.value.token, by: value)
    }

    // MARK: Properties

    // MARK: Events

    /// Fires on every tap of either button, with the value stepped to. Runs
    /// after a binding's write, if there is one.
    public func onValueChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
        onEvent(StepperContract.valueChanged, handler)
    }
}
