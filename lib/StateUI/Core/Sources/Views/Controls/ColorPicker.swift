// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `ColorPicker`'s own properties, shared by the control and its
/// `Style<ColorPicker>`.
public protocol ColorPickerProperties: PropertyContainer {}

extension ColorPickerProperties {
    /// The color the well shows. Usually given in the initializer.
    public func color(_ value: Color) -> Modified {
        setValue(ColorPickerContract.color, value)
    }

    /// Whether the user chooses the color's opacity too; an opaque color only where false, the default.
    public func choosesOpacity(_ value: Bool) -> Modified {
        setValue(ColorPickerContract.choosesOpacity, value)
    }

    /// `choosesOpacity` from a state, `$x`: the host sets each new value as it stands, and no view is rebuilt
    /// for it.
    public func choosesOpacity(_ state: Binding<Bool>) -> Modified {
        twin(ColorPickerContract.choosesOpacity, by: state)
    }
}

/// A well showing a color, which the user opens to choose another in the
/// platform's own picker.
///
///     @State private var tint = Color.steelBlue
///     …
///     ColorPicker($tint)
///
/// Given a binding it shows what the binding holds and writes every choice
/// back. Given a plain `Color` it only shows: `.onColorChanged` is then the one
/// way a choice reaches anywhere.
public struct ColorPicker: ElementView, ColorPickerProperties, FocusElement {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<ColorPicker>` is written against.
    public init() {
        node = Node(contract: ColorPickerContract.self)
    }

    /// A well showing `color`. One-way: what the user chooses goes nowhere
    /// without `.onColorChanged`.
    public init(_ color: Color) {
        node = Node(contract: ColorPickerContract.self)
        node.write(ColorPickerContract.color, color)
    }

    /// Two-way: shows what the binding holds, and writes back what the user
    /// chooses.
    public init(_ state: Binding<Color>) {
        self = ColorPicker().color(state)
    }

    // Design: docs/design/views/bindings.md#two-way-controls
    /// Two-way: shows what the state holds and writes back what the user
    /// chooses, with no view rebuilt for it. The host carries the state as a
    /// journey, as it carries a fill or a background, so one state paints
    /// what the picker chooses:
    ///
    ///     ColorPicker($tint)
    ///     Rectangle().fill($tint)
    ///
    /// - Parameter state: the state shown, and written back into as the user
    ///   chooses.
    /// - Returns: the picker, wearing and reporting that color.
    public func color(_ state: Binding<Color>) -> Modified {
        state.image == nil
            ? described(ColorPickerContract.color.token, state, on: ColorPickerContract.colorChanged.token)
            : journey(ColorPickerContract.color.token, by: state)
    }

    // MARK: Events

    /// Fires when the user chooses another color, with it. Runs after a
    /// binding's write, if there is one.
    public func onColorChanged(_ handler: @escaping @MainActor (Color) throws -> Void) -> Modified {
        onEvent(ColorPickerContract.colorChanged, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onColorChanged(_ policy: GatePolicy, _ handler: @escaping ValueEventHandler<Color>) -> Modified {
        onEvent(ColorPickerContract.colorChanged, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onColorChanged(gate: Gate, _ handler: @escaping ValueEventHandler<Color>) -> Modified {
        onEvent(ColorPickerContract.colorChanged, gate: gate, handler)
    }
}
