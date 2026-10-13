// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// How words look on any element showing them - a text block or a control: their font, their colour and the room
/// around them.
/// Design: docs/design/platforms/winui/controls.md#words
extension WinUIView {
    /// The font a look gives (`TextMembers.look`): its style's size and weight on WinUI's type ramp under the size
    /// and weight it gives, its slant and its family - the platform's where it says nothing. Answers the size the
    /// words stand at, nil for the platform's.
    /// Design: docs/design/platforms/winui/controls.md#a-text-style
    @discardableResult
    func setFont(_ look: TextLook) -> Double? {
        let (size, weight) = look.standing(styleSize: look.style?.winUISize, styleWeight: look.style?.winUIWeight)
        stateui_winui_set_font(
            handle, size ?? 0, Int32(weight?.number ?? 0), look.attributes.contains(.italic), look.family ?? "")
        return size
    }

    /// How the words look (`TextMembers.look`): their font, whether it grows with the user's text size, and their
    /// colour - each the platform's where the look says nothing.
    func setLook(_ look: TextLook) {
        setFont(look)
        setTextScales(look.scales)
        setForeground(look.color)
    }

    /// Whether the words grow with the user's text size.
    func setTextScales(_ scales: Bool) {
        stateui_winui_set_text_scales(handle, scales)
    }

    /// Whether the words grow with the user's text size, as WinUI holds it.
    var textScales: Bool {
        stateui_winui_text_scales(handle)
    }

    /// The room between the letters, in points, of words `size` points tall - the platform's size for nil.
    func setLetterSpacing(_ points: Double, size: Double?) {
        var look = TextLook()
        look.letterSpacing = points
        let ems = look.letterSpacing(inEmsOf: size ?? WinUITextualView.platformFontSize)
        stateui_winui_set_character_spacing(handle, Int32((ems * 1000).rounded()))
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

extension TextStyle {
    /// The style's size on WinUI's type ramp, in DIPs: the Display, Title, Subtitle, BodyStrong, Body and Caption
    /// text block styles.
    var winUISize: Double {
        switch self {
        case .display: 68
        case .title: 28
        case .subtitle: 20
        case .headline, .body: 14
        case .caption: 12
        }
    }

    /// The style's weight on WinUI's type ramp: semibold but for the body and a caption.
    var winUIWeight: FontWeight {
        switch self {
        case .display, .title, .subtitle, .headline: .semibold
        case .body, .caption: .regular
        }
    }
}
