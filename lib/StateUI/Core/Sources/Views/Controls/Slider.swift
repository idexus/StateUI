// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Slider`'s own properties, shared by the control and its `Style<Slider>`.
public protocol SliderProperties: PropertyContainer {}

extension SliderProperties {
    /// Where the thumb stands, between `minimum` and `maximum`. Usually given
    /// in the initializer.
    public func value(_ value: Double) -> Modified {
        setValue(SliderContract.value, value)
    }

    /// The value at the near end of the track, 0 until told otherwise.
    public func minimum(_ value: Double) -> Modified {
        setValue(SliderContract.minimum, value)
    }

    /// The value at the far end of the track, 1 until told otherwise - so a
    /// slider meant to run to 100 must say so.
    public func maximum(_ value: Double) -> Modified {
        setValue(SliderContract.maximum, value)
    }
}

/// A value picked by dragging a thumb along a native track.
///
///     Slider($volume)
///         .minimum(0)
///         .maximum(100)
///
/// Given a binding it shows the value and writes every drag back. Given a
/// number it shows that, and `.onValueChanged` is how the drag gets anywhere.
///
/// The range is 0 to 1 until `.minimum` and `.maximum` say otherwise.
public struct Slider: ElementView, TintElement, SliderProperties, FocusElement {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Slider>` is written against.
    public init() {
        node = Node(contract: SliderContract.self)
    }

    /// A slider sitting at `value`. One-way: the drag goes nowhere without
    /// `.onValueChanged`.
    public init(_ value: Double) {
        node = Node(contract: SliderContract.self)
        node.write(SliderContract.value, value)
    }

    /// Two-way: shows what the state holds and writes back what the user drags,
    /// with no view rebuilt for it.
    ///
    ///     @State private var volume = 0.0
    ///
    ///     Slider($volume)
    ///
    /// An assignment (`volume = 1`) animates the thumb there under the
    /// element's motion; `$volume.journey` reads where the thumb is, and
    /// `try await $volume.journey.move(to: 1).arrived()` waits for the arrival.
    public init(_ state: some TwoWay<Double>) {
        self = Slider().value(state)
    }

    // Design: docs/design/views/bindings.md#a-finger-takes-a-moving-thumb
    /// The same two-way value as `Slider($value)`, written as a modifier.
    ///
    ///     Slider($volume)
    ///     Slider().value($volume)
    ///
    /// A finger that takes a moving thumb stops its animation where the user
    /// holds it, and an awaiting move resumes with `false`.
    ///
    /// - Parameter state: the state the thumb shows and writes back into,
    ///   carried by the host as a journey.
    /// - Returns: the control, wearing and reporting that value.
    public func value(_ state: some TwoWay<Double>) -> Modified {
        guard let whole = state.whole else {
            return described(SliderContract.value.token, state, on: SliderContract.valueChanged.token)
        }

        return journey(SliderContract.value.token, by: whole)
    }

    // MARK: Events

    /// Fires on every step of a drag, with the value dragged to, after a
    /// binding's write. Heavy work belongs in `.onReleased`.
    public func onValueChanged(_ handler: @escaping @MainActor (Double) throws -> Void) -> Modified {
        onEvent(SliderContract.valueChanged, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onValueChanged(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<Double>) -> Modified {
        onEvent(SliderContract.valueChanged, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onValueChanged(gate: Gate, _ handler: @escaping ValueEventHandler<Double>) -> Modified {
        onEvent(SliderContract.valueChanged, gate: gate, handler)
    }

    /// Runs when the thumb is grabbed - the start of a drag whose every step
    /// is an `onValueChanged`.
    public func onPressed(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(SliderContract.pressed, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onPressed(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(SliderContract.pressed, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onPressed(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(SliderContract.pressed, gate: gate, handler)
    }

    /// Runs when the thumb is let go - where work too heavy for every step of
    /// the drag belongs.
    public func onReleased(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(SliderContract.released, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onReleased(_ policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(SliderContract.released, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onReleased(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(SliderContract.released, gate: gate, handler)
    }
}

extension Slider {
    /// `maximum` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func maximum(_ state: Binding<Double>) -> Modified {
        twin(SliderContract.maximum, carrying: state)
    }

    /// `minimum` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func minimum(_ state: Binding<Double>) -> Modified {
        twin(SliderContract.minimum, carrying: state)
    }
}
