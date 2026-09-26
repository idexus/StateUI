// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A WinUI `TextBlock`: its words, how they break and stand, and the space between the letters and the lines.
/// Design: docs/design/platforms/winui/controls.md#words
@MainActor
class WinUITextView: WinUIView {
    /// The font's size, the space between the letters and the height of a line - what the spacing is measured
    /// against, and what it is.
    private var look = TextLook()

    /// The size WinUI draws body text at, in DIPs.
    static let platformFontSize = 14.0

    /// How much taller than its size a line of Segoe UI stands.
    static let lineHeightOfFont = 4.0 / 3.0

    init() {
        super.init { _ in stateui_winui_text_make() }
    }

    /// The words shown.
    func setText(_ text: String) {
        stateui_winui_text_set_text(handle, text)
    }

    /// The words the element shows now, read back from WinUI.
    var text: String {
        WinUIView.words(of: handle)
    }

    /// The font, remembering its size for the spacing measured against it.
    func setTextFont(size: Double?, attributes: FontAttributes?, family: String?) {
        setFont(size: size, attributes: attributes, family: family)
        look.size = size.flatMap { $0 > 0 ? $0 : nil }
        writeSpacing()
    }

    /// How the words break - wrapped, on one line, or cut short - and the most lines; nil for any
    /// (`LineBreak.lines`).
    func setLines(breaking: LineBreak, maximum: Int?) {
        stateui_winui_text_set_lines(
            handle, breaking.wraps, Int32(breaking.lines(maximum: maximum) ?? 0), breaking.truncates)
    }

    /// Where the words stand across the label.
    func setAlignment(horizontal: TextAlignment) {
        stateui_winui_text_set_alignment(handle, horizontal.rawValue)
    }

    /// The space between the letters, in DIPs.
    func setLetterSpacing(_ points: Double) {
        look.letterSpacing = points
        writeSpacing()
    }

    /// The height of a line, as a multiple of the font's own; nil for the font's.
    func setLineHeight(_ multiple: Double?) {
        look.lineHeight = multiple.flatMap { $0 > 0 ? $0 : nil }
        writeSpacing()
    }

    /// A line under the words, or through them.
    func setDecorations(_ decorations: TextDecorations?) {
        stateui_winui_text_set_decorations(
            handle, decorations?.contains(.underline) == true, decorations?.contains(.strikethrough) == true)
    }

    /// WinUI spaces letters in thousandths of an em and lines in DIPs: both measured against the font's size.
    private func writeSpacing() {
        let size = look.size ?? Self.platformFontSize
        let thousandths = Int32((look.letterSpacing(inEmsOf: size) * 1000).rounded())
        let line = look.lineHeight.map { $0 * size * Self.lineHeightOfFont } ?? 0
        stateui_winui_text_set_spacing(handle, thousandths, line)
    }
}

extension WinUIView {
    /// The words a text block or a button's caption shows now, read back from WinUI.
    static func words(of handle: StateUIObjectRef) -> String {
        let length = Int(stateui_winui_text(handle, nil, 0))
        var bytes = [CChar](repeating: 0, count: length + 1)
        _ = stateui_winui_text(handle, &bytes, Int32(bytes.count))
        return String(decoding: bytes.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
