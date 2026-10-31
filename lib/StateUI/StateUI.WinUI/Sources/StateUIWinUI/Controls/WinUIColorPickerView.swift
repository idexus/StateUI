// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A ColorPicker: a `DropDownButton` showing the color in a swatch, its flyout WinUI's `ColorPicker`; each color the
/// user chooses there is reported as the host layer reports it, and the program's only shown.
/// Design: docs/design/platforms/winui/controls.md#a-color-picker
@MainActor
final class WinUIColorPickerView: WinUIView {
    /// What the picker does as the user chooses a color.
    var onChosen: ((Color) -> Void)?

    override var takesDirection: Bool { true }

    init() {
        super.init { number in stateui_winui_color_make(number) }
    }

    /// The color WinUI's picker holds.
    var color: Color { Color(argb: stateui_winui_color(handle)) }

    /// Whether WinUI's picker offers opacity.
    var choosesOpacity: Bool { stateui_winui_color_chooses_opacity(handle) }

    /// The color it shows where `write` says the tree changed it, and whether the picker offers opacity.
    func apply(color: Color, write: Bool, choosesOpacity: Bool) {
        stateui_winui_color_set_opacity(handle, choosesOpacity)
        if write, let argb = color.propValue.argb { stateui_winui_color_set(handle, argb) }
    }

    override func colorChosen(_ argb: UInt32) {
        guard let held = Color(argb: argb).propValue.fractions else { return }
        onChosen?(ColorChoice.reported(held, choosesOpacity: choosesOpacity))
    }

    override func detach() {
        super.detach()
        onChosen = nil
    }
}
