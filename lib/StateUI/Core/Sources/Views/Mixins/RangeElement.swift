// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a control choosing a number in a range shares - a slider, a stepper: its range, which a style may give,
/// and what the user's change does. The number itself is given in its initializer.
///
///     Slider($volume).minimum(0).maximum(11).onValueChanged { print($0) }
public protocol RangeElement: PropertyContainer {}

extension RangeElement {
    /// The value at the near end of its range, 0 until told otherwise.
    public func minimum(_ value: Double) -> Modified {
        setValue(RangeElementContract.minimum, value)
    }

    /// The value at the far end of its range until told otherwise: 1 on a
    /// slider - so a slider meant to run to 100 must say so - and 100 on a
    /// stepper.
    public func maximum(_ value: Double) -> Modified {
        setValue(RangeElementContract.maximum, value)
    }
}

extension RangeElement where Self: ModifiableElement {
    /// Fires on every step of a drag, with the value dragged to, after a
    /// binding's write. Heavy work belongs in `.onReleased`.
    public func onValueChanged(_ handler: @escaping @MainActor (Double) throws -> Void) -> Modified {
        onEvent(RangeElementContract.valueChanged, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onValueChanged(policy: GatePolicy, _ handler: @escaping ValueEventHandler<Double>) -> Modified {
        onEvent(RangeElementContract.valueChanged, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onValueChanged(gate: Gate, _ handler: @escaping ValueEventHandler<Double>) -> Modified {
        onEvent(RangeElementContract.valueChanged, gate: gate, handler)
    }

    /// `maximum` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func maximum(_ state: Binding<Double>) -> Modified {
        twin(RangeElementContract.maximum, carrying: state)
    }

    /// `minimum` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func minimum(_ state: Binding<Double>) -> Modified {
        twin(RangeElementContract.minimum, carrying: state)
    }
}
