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
public struct Slider: ElementView, TintElement, SliderProperties {
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
    public init(_ value: Binding<Double>) {
        self = Slider().value(value)
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
    /// - Parameter value: the state the thumb shows and writes back into,
    ///   carried by the host as a journey.
    /// - Returns: the control, wearing and reporting that value.
    public func value(_ value: Binding<Double>) -> Modified {
        journey(SliderContract.value.token, by: value)
    }

    // MARK: Events

    /// Fires on every step of a drag, with the value dragged to, after a
    /// binding's write. Heavy work belongs in `.onReleased`.
    public func onValueChanged(_ handler: @escaping @MainActor (Double) throws -> Void) -> Self {
        onEvent(SliderContract.valueChanged, handler)
    }

    /// The same, with a handler that awaits: `repeated` says what the event does when it comes
    /// again while a run is under way.
    public func onValueChanged(_ repeated: RepeatedEvent, _ handler: @escaping ValueEventHandler<Double>) -> Self {
        onEvent(SliderContract.valueChanged, repeated, handler)
    }

    /// A handler that awaits says what the event does when it comes again while it runs.
    @available(*, unavailable, message: "a handler that awaits says what the event does when it comes again while it runs: .onValueChanged(.ignoreWhileRunning) { … } - or .cancelPrevious, .waitForPrevious, .overlap")
    public func onValueChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
        fatalError("unavailable")
    }

    /// Runs when the thumb is grabbed - the start of a drag whose every step
    /// is an `onValueChanged`.
    public func onPressed(_ handler: @escaping @MainActor () throws -> Void) -> Self {
        onEvent(SliderContract.pressed, handler)
    }

    /// The same, with a handler that awaits: `repeated` says what the event does when it comes
    /// again while a run is under way.
    public func onPressed(_ repeated: RepeatedEvent, _ handler: @escaping EventHandler) -> Self {
        onEvent(SliderContract.pressed, repeated, handler)
    }

    /// A handler that awaits says what the event does when it comes again while it runs.
    @available(*, unavailable, message: "a handler that awaits says what the event does when it comes again while it runs: .onPressed(.ignoreWhileRunning) { … } - or .cancelPrevious, .waitForPrevious, .overlap")
    public func onPressed(_ handler: @escaping EventHandler) -> Self {
        fatalError("unavailable")
    }

    /// Runs when the thumb is let go - where work too heavy for every step of
    /// the drag belongs.
    public func onReleased(_ handler: @escaping @MainActor () throws -> Void) -> Self {
        onEvent(SliderContract.released, handler)
    }

    /// The same, with a handler that awaits: `repeated` says what the event does when it comes
    /// again while a run is under way.
    public func onReleased(_ repeated: RepeatedEvent, _ handler: @escaping EventHandler) -> Self {
        onEvent(SliderContract.released, repeated, handler)
    }

    /// A handler that awaits says what the event does when it comes again while it runs.
    @available(*, unavailable, message: "a handler that awaits says what the event does when it comes again while it runs: .onReleased(.ignoreWhileRunning) { … } - or .cancelPrevious, .waitForPrevious, .overlap")
    public func onReleased(_ handler: @escaping EventHandler) -> Self {
        fatalError("unavailable")
    }
}

extension Slider {
    /// `maximum` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func maximum(_ state: Binding<Double>) -> Modified {
        plain(SliderContract.maximum.token, by: state)
    }

    /// `minimum` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func minimum(_ state: Binding<Double>) -> Modified {
        plain(SliderContract.minimum.token, by: state)
    }
}
