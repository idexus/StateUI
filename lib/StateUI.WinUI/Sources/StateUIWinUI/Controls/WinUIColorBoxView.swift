// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A ColorBox: a figure of one colour, which takes the room its layout gives it and asks for none.
@MainActor
final class WinUIColorBoxView: WinUIView {
    init() {
        super.init { number in stateui_winui_color_box_make(number) }
    }

    /// The box's colour, and the radii of its corners - one for all four, or four in StateUI's order: top left,
    /// top right, bottom left, bottom right; nil draws no colour.
    func apply(color: HostValue?, corners: HostValue?) {
        let radii = BoxArithmetic.clockwise(corners.flatMap(CornerRadius.init(propValue:)))
        stateui_winui_color_box_set(handle, color?.argb ?? 0, radii)
    }
}
