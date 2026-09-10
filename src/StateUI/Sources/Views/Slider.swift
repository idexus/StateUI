// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: Slider.

/// Slider's own properties - the half a `Style<Slider>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol SliderProperties: PropertyContainer {}

extension SliderProperties {
    /// Where the thumb stands, between `minimum` and `maximum`.
    /// MAUI: Slider.Value.
    ///
    /// `Slider(0.5)` and `Slider($volume)` both say this from their argument,
    /// so a modifier written beside one wins - and a binding goes on being
    /// written back to, which is how the two can then disagree.
    public func value(_ value: Double) -> Modified {
        setValue(.value, .number(value))
    }

    /// The value at the near end of the track. MAUI: Slider.Minimum, which is
    /// 0 until told otherwise.
    public func minimum(_ value: Double) -> Modified {
        setValue(.minimum, .number(value))
    }

    /// The value at the far end of the track. MAUI: Slider.Maximum, which is 1
    /// until told otherwise - so a slider meant to run to 100 must say so.
    public func maximum(_ value: Double) -> Modified {
        setValue(.maximum, .number(value))
    }

    /// The colour of the track BEHIND the thumb - the part already covered.
    /// MAUI: Slider.MinimumTrackColor.
    public func minimumTrackColor(_ value: Color) -> Modified {
        setValue(.minimumTrackColor, value.propValue)
    }

    /// The colour of the track AHEAD of the thumb - the part still to go.
    /// MAUI: Slider.MaximumTrackColor.
    public func maximumTrackColor(_ value: Color) -> Modified {
        setValue(.maximumTrackColor, value.propValue)
    }

    /// The colour of the thumb itself, the part that is dragged.
    /// MAUI: Slider.ThumbColor.
    public func thumbColor(_ value: Color) -> Modified {
        setValue(.thumbColor, value.propValue)
    }

    /// A picture in place of the platform's thumb - a file in the app's
    /// Resources/Images, by the name MAUI gives it once built.
    /// MAUI: Slider.ThumbImageSource.
    ///
    /// It REPLACES the thumb rather than tinting it, so `thumbColor` beside it
    /// paints nothing.
    public func thumbImageSource(_ value: ImageSource) -> Modified {
        setValue(.thumbImageSource, value.propValue)
    }
}

/// A value picked by dragging a thumb along a track. MAUI: Slider.
///
///     Slider($volume)
///         .minimum(0)
///         .maximum(100)
///
/// Given a binding it shows the value and writes every drag back. Given a
/// number it shows that, and `.onValueChanged` is how the drag gets anywhere.
///
/// The range is 0 to 1 until `.minimum` and `.maximum` say otherwise, which is
/// MAUI's own default and the usual surprise.
public struct Slider: View, SliderProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Slider>` is written against.
    public init() {
        node = Node(type: .slider)
    }

    /// A slider sitting at `value`. One-way: the drag goes nowhere without
    /// `.onValueChanged`.
    public init(_ value: Double) {
        node = Node(type: .slider, props: [.value: .number(value)])
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
    /// **A FINGER DOES NOT TAKE A THUMB THAT IS ALREADY MOVING.** While the host
    /// writes the value every frame, a drag on that thumb raises no report, so
    /// the journey runs to where it was sent. `$volume.journey.stop()` first if
    /// the reader is meant to interrupt it.
    ///
    /// - Parameter value: the state the thumb shows and writes back into,
    ///   carried by the host as a journey.
    /// - Returns: the control, wearing and reporting that value.
    public func value(_ value: Binding<Double>) -> Modified {
        journey(.value, by: value)
    }

    // MARK: Properties

    // MARK: Events

    /// Fires on every step of a drag, with the value dragged to - MAUI's
    /// `ValueChangedEventArgs.NewValue`. Runs after a binding's write, if there
    /// is one. MAUI: Slider.ValueChanged.
    ///
    /// Work heavy enough to stutter belongs in `.onDragCompleted` instead, this
    /// one running for every position the thumb passes through.
    public func onValueChanged(_ handler: @escaping ValueEventHandler<Double>) -> Self {
        addHandler(.valueChanged) {
            // A payload that will not parse leaves the handler alone, the rule
            // every gesture follows - a zero nobody dragged to would read as a
            // real position.
            if let value = EventBuffer.current.value()?.number {
                try await handler(value)
            }
        }
    }

    /// Runs when the thumb is grabbed - the start of a drag whose every step
    /// is an `onValueChanged`. MAUI: Slider.DragStarted.
    public func onDragStarted(_ handler: @escaping EventHandler) -> Self {
        addHandler(.dragStarted, handler)
    }

    /// Runs when the thumb is let go - where work too heavy for every step of
    /// the drag belongs. MAUI: Slider.DragCompleted.
    public func onDragCompleted(_ handler: @escaping EventHandler) -> Self {
        addHandler(.dragCompleted, handler)
    }
}
