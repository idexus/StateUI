// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Stepper`'s own properties, shared by the control and its `Style<Stepper>`.
public protocol StepperProperties: PropertyContainer {}

extension StepperProperties {
    /// The number it is showing, between `minimum` and `maximum`. Usually given
    /// in the initializer.
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

    /// Two-way: shows what the state holds and writes back what is stepped to,
    /// with no view rebuilt for it.
    ///
    ///     @State private var count = 1.0
    ///
    ///     Stepper($count)
    ///
    /// A Stepper draws its two buttons and no number: show `count` beside it,
    /// or a driven text an engine writes, which costs no render.
    public init(_ value: Binding<Double>) {
        self = Stepper().value(value)
    }

    // Design: docs/design/views/bindings.md#two-way-controls
    /// The same two-way value as `Stepper($value)`, written as a modifier.
    ///
    ///     Stepper($count)
    ///     Stepper().value($count)
    ///
    /// - Parameter value: the state the stepper shows and writes back into,
    ///   carried by the host as a journey.
    /// - Returns: the control, wearing and reporting that value.
    public func value(_ value: Binding<Double>) -> Modified {
        journey(StepperContract.value.token, by: value)
    }

    // MARK: Events

    /// Fires on every tap of either button, with the value stepped to. Runs
    /// after a binding's write, if there is one.
    public func onValueChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
        onEvent(StepperContract.valueChanged, handler)
    }
}
