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
    /// The value is ARMED with this state, exactly as a `Slider`'s is, so it
    /// can be FLOWN to a number instead of jumping there:
    ///
    ///     @State private var count = 1.0
    ///
    ///     Stepper($count)
    ///
    ///     Button("A dozen")
    ///         .onClicked { try await $count.animateTo(12, length: 400) }
    ///
    /// A report arriving while it flies is ignored - see `Binding.isFlying`.
    public init(_ value: Binding<Double>) {
        node = Node(type: .stepper, props: [.value: .number(value.wrappedValue)])
        node.armed[.value] = value.flightKey

        node.addHandler(.valueChanged) {
            guard !value.isFlying else { return }

            if let stepped = EventBuffer.current.value()?.number {
                value.wrappedValue = stepped
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
