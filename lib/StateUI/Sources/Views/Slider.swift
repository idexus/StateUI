// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Slider's own properties - the half a `Style<Slider>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol SliderProperties: PropertyContainer {}

extension SliderProperties {
    /// Where the thumb stands, between `minimum` and `maximum`.
    ///
    /// `Slider(0.5)` and `Slider($volume)` both say this from their argument,
    /// so a modifier written beside one wins - and a binding goes on being
    /// written back to, which is how the two can then disagree.
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
public struct Slider: View, TintElement, SliderProperties {
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

    /// Two-way: shows what the state holds and writes back what is dragged -
    /// and HANDED OVER, so the slider is no reader of the state.
    ///
    ///     @State private var volume = 0.0
    ///
    ///     Slider($volume)
    ///
    /// The host carries the value as a journey. An assignment (`volume = 1`)
    /// sends the thumb there under the element's law - `.motion(.none)` on the
    /// slider lands it at once - and a drag is written back onto the value and
    /// its destination together, so nothing aims the thumb out from under the
    /// hand holding it. What a drag COSTS is decided by who reads `volume` at
    /// build: nothing where nobody prints it, and a render per report for the
    /// body that does. A reading that keeps up with every report is a text an
    /// engine following `$volume` writes, or `$volume.convert { … }`.
    ///
    /// The journey is the state's, as every walked state's is: `$volume.journey`
    /// reads where the thumb IS while the host walks it, and
    /// `try await $volume.journey.move(to: 1)` waits for the arrival.
    public init(_ value: Binding<Double>) {
        self = Slider().value(value)
    }

    /// The same two-way value as `Slider($value)`, written as a modifier.
    ///
    ///     Slider($volume)
    ///     Slider().value($volume)
    ///
    /// BOTH SPELLINGS ALWAYS, and they mean the same thing: the initializer is
    /// the short way to say what gives this control its purpose, and the
    /// modifier is the way every other property is written. Neither is the
    /// real one.
    ///
    /// BOTH WAYS: a value written to the state moves the thumb, and the
    /// reader's own drag is written back onto the journey's value and
    /// destination together, so nothing aims the thumb out from under the hand
    /// holding it. What tells the two apart is WHEN the platform's report
    /// arrives - one raised inside the host's own write is the host hearing
    /// itself and is dropped.
    ///
    /// **A FINGER TAKES A THUMB THAT IS ALREADY MOVING.** Its first report ends
    /// the old journey where the reader put it, zeroes its velocity and resumes
    /// an awaiting move with `false`. From then on every report writes the
    /// journey's value and destination together, so nothing pulls against the
    /// hand.
    ///
    /// - Parameter value: the state the thumb shows and writes back into,
    ///   carried by the host as a journey.
    /// - Returns: the control, wearing and reporting that value.
    public func value(_ value: Binding<Double>) -> Modified {
        journey(SliderContract.value.token, by: value)
    }

    // MARK: Properties

    // MARK: Events

    /// Fires on every step of a drag, with the value dragged to. Runs after a
    /// binding's write, if there is one.
    ///
    /// Work heavy enough to stutter belongs in `.onDragCompleted` instead, this
    /// one running for every position the thumb passes through.
    public func onValueChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
        onEvent(SliderContract.valueChanged, handler)
    }

    /// Runs when the thumb is grabbed - the start of a drag whose every step
    /// is an `onValueChanged`.
    public func onDragStarted(_ handler: @escaping EventHandler) -> Self {
        onEvent(SliderContract.dragStarted, handler)
    }

    /// Runs when the thumb is let go - where work too heavy for every step of
    /// the drag belongs.
    public func onDragCompleted(_ handler: @escaping EventHandler) -> Self {
        onEvent(SliderContract.dragCompleted, handler)
    }
}
