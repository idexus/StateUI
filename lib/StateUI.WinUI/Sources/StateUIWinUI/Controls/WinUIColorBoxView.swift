// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A ColorBox: a WinUI `Border` of one colour, which takes the room its layout gives it and asks for none.
@MainActor
final class WinUIColorBoxView: WinUIView {
    init() {
        super.init { _ in stateui_winui_color_box_make() }
    }

    /// The box's colour, and the radii of its corners - one for all four, or four in StateUI's order: top left,
    /// top right, bottom left, bottom right; nil draws no colour.
    func apply(color: HostValue?, corners: HostValue?) {
        let radii: [Double] = if let radius = corners?.number {
            [radius, radius, radius, radius]
        } else if let four = corners?.numbers, four.count >= 4 {
            [four[0], four[1], four[3], four[2]]
        } else {
            [0, 0, 0, 0]
        }
        let kept = radii.map { $0.isFinite ? max(0, $0) : 0 }
        stateui_winui_color_box_set(handle, color.flatMap(WinUIBrush.argb) ?? 0, kept)
    }
}
