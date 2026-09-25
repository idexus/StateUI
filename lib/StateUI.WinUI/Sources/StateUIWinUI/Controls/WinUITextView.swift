// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A WinUI `TextBlock`: its words, how they break and stand, and the space between the letters and the lines.
/// Design: docs/design/platforms/winui/controls.md#words
@MainActor
class WinUITextView: WinUIView {
    /// The font's size, in DIPs - what the letters' and the lines' spacing is measured against.
    private var fontSize = WinUITextView.platformFontSize

    /// The space between the letters in DIPs, and the height of a line as a multiple of the font's.
    private var letterSpacing = 0.0
    private var lineHeight: Double?

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
        fontSize = size.flatMap { $0 > 0 ? $0 : nil } ?? Self.platformFontSize
        writeSpacing()
    }

    /// How the words break - wrapped, on one line, or cut short - and the most lines; nil for any.
    func setLines(breaking: LineBreak, maximum: Int?) {
        stateui_winui_text_set_lines(handle, breaking.rawValue, Int32(maximum ?? 0))
    }

    /// Where the words stand across the label.
    func setAlignment(horizontal: TextAlignment) {
        stateui_winui_text_set_alignment(handle, horizontal.rawValue)
    }

    /// The space between the letters, in DIPs.
    func setLetterSpacing(_ points: Double) {
        letterSpacing = points
        writeSpacing()
    }

    /// The height of a line, as a multiple of the font's own; nil for the font's.
    func setLineHeight(_ multiple: Double?) {
        lineHeight = multiple.flatMap { $0 > 0 ? $0 : nil }
        writeSpacing()
    }

    /// A line under the words, or through them.
    func setDecorations(_ decorations: TextDecorations?) {
        stateui_winui_text_set_decorations(
            handle, decorations?.contains(.underline) == true, decorations?.contains(.strikethrough) == true)
    }

    /// WinUI spaces letters in thousandths of an em and lines in DIPs: both measured against the font's size.
    private func writeSpacing() {
        let thousandths = Int32((letterSpacing / fontSize * 1000).rounded())
        let line = lineHeight.map { $0 * fontSize * Self.lineHeightOfFont } ?? 0
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
