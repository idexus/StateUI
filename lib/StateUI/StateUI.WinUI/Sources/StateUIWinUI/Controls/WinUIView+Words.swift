// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// How words look on any element showing them - a text block or a control: their font, their colour and the room
/// around them.
/// Design: docs/design/platforms/winui/controls.md#words
extension WinUIView {
    /// The font: its size in DIPs, its weight and slant, and its family; nil and empty for the platform's.
    func setFont(size: Double?, attributes: FontAttributes?, family: String?) {
        let attributes = attributes ?? []
        stateui_winui_set_font(
            handle, size ?? 0, attributes.contains(.bold), attributes.contains(.italic), family ?? "")
    }

    /// The words' colour; nil puts back the platform's.
    func setForeground(_ color: HostValue?) {
        let argb = color?.argb
        stateui_winui_set_foreground(handle, argb != nil, argb ?? 0)
    }

    /// The room kept around the words, in DIPs.
    func setPadding(_ padding: Insets?) {
        let room = padding ?? Insets(0)
        stateui_winui_set_padding(handle, room.left, room.top, room.right, room.bottom)
    }

    /// How the words look, as WinUI holds it.
    var wordsStyle: (size: Double, weight: Int, lines: Int, alignment: Int, color: UInt32) {
        var style = [Double](repeating: 0, count: 5)
        stateui_winui_text_style(handle, &style)
        return (style[0], Int(style[1]), Int(style[2]), Int(style[3]), UInt32(style[4]))
    }
}
