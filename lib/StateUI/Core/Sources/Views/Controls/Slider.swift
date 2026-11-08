// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

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
public struct Slider: ElementView, TintElement, FocusElement, PressElement, RangeElement {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: SliderContract.self)
    }

    /// A slider sitting at `value`. One-way: the drag goes nowhere without
    /// `.onValueChanged`.
    public init(_ value: Double) {
        node = Node(contract: SliderContract.self)
        node.write(RangeElementContract.value, value)
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
    public init(_ state: Binding<Double>) {
        self = Slider().value(state)
    }

    /// Where the thumb stands.
    func value(_ value: Double) -> Modified {
        setValue(RangeElementContract.value, value)
    }

    /// The thumb's value from a state, carried by the host as a journey.
    func value(_ state: Binding<Double>) -> Modified {
        journey(RangeElementContract.value.token, by: state)
    }
}

