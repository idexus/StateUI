// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Stepper`'s own properties, shared by the control and its `Style<Stepper>`.
public protocol StepperProperties: PropertyContainer {}

extension StepperProperties {

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
public struct Stepper: ElementView, StepperProperties, FocusElement, RangeElement {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: StepperContract.self)
    }

    /// A stepper sitting at `value`. One-way: the step goes nowhere without
    /// `.onValueChanged`.
    public init(_ value: Double) {
        node = Node(contract: StepperContract.self)
        node.write(RangeElementContract.value, value)
    }

    /// Two-way: shows what the state holds and writes back what is stepped to,
    /// with no view rebuilt for it.
    ///
    ///     @State private var count = 1.0
    ///
    ///     Stepper($count)
    ///
    /// A Stepper draws its number on some platforms and not on others: show
    /// `count` beside it, or a driven text an engine writes, which costs no render.
    public init(_ state: Binding<Double>) {
        self = Stepper().value(state)
    }

    /// The value it holds.
    func value(_ value: Double) -> Modified {
        setValue(RangeElementContract.value, value)
    }

    /// The value from a state, carried by the host as a journey.
    func value(_ state: Binding<Double>) -> Modified {
        journey(RangeElementContract.value.token, by: state)
    }
}

extension Stepper {
    /// `step` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func step(_ state: Binding<Double>) -> Modified {
        twin(StepperContract.step, by: state)
    }
}

