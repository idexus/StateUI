// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A Text: a `TextBlock` - its words, or runs of them each in its own colour, size, weight, family, letter spacing
/// and background - standing in a `Border`, which draws what the label is drawn over and stands the words across its
/// height.
/// Design: docs/design/platforms/winui/controls.md#runs-of-words
@MainActor
final class WinUITextView: WinUITextualView {
    /// The label's own words, and the runs shown in their place; nil while it shows its own.
    private var ownText = ""
    private var runs: [TextRun]?

    override func setText(_ text: String) {
        ownText = text
        if runs == nil { super.setText(text) }
    }

    /// What the label is drawn over: a colour, a gradient, or nothing.
    override func setBackground(_ value: HostValue?) {
        let brush = WinUIBrush(value)
        paint("background", followsSize: brush.followsSize) { [handle] size in
            brush.withRelayBrush(over: size) { stateui_winui_text_set_background(handle, $0) }
        }
    }

    /// Where the words stand across the label's height.
    /// Whether the user can select the words and copy them.
    func setSelectable(_ selectable: Bool) {
        stateui_winui_text_set_selectable(handle, selectable)
    }

    func setVerticalAlignment(_ alignment: TextAlignment) {
        stateui_winui_text_set_vertical(handle, alignment.rawValue)
    }

    /// Runs of words shown in place of the label's own (`MountedElement.textRuns`), each in its own look over the
    /// label's; nil shows its own words again.
    func setRuns(_ runs: [TextRun]?) {
        // Shown without runs before, the label's own words stand already.
        guard runs != nil || self.runs != nil else { return }
        self.runs = runs
        guard let runs else { return super.setText(ownText) }

        WinUIStrings.withCStrings(runs.map(\.text)) { texts in
            WinUIStrings.withCStrings(runs.map { $0.look.family ?? "" }) { families in
                let words = runs.indices.map { index in
                    let look = runs[index].look
                    let color = look.color?.argb
                    let background = look.background?.argb
                    // The space between the letters in ems of the run's own size, its label's where it says none.
                    let shown = look.over(self.look)
                    let (size, weight) = look.standing(
                        styleSize: look.style?.winUISize, styleWeight: look.style?.winUIWeight)
                    let shownSize = shown.standing(styleSize: shown.style?.winUISize, styleWeight: nil).size
                    let spacing = shown.letterSpacing(inEmsOf: shownSize ?? Self.platformFontSize)
                    return StateUIWordsRun(
                        text: texts[index], color: color ?? 0, background: background ?? 0, size: size ?? 0,
                        hasColor: color != nil, hasBackground: background != nil,
                        weight: Int32(weight?.number ?? 0), italic: look.attributes.contains(.italic),
                        underline: look.decorations.contains(.underline),
                        strikethrough: look.decorations.contains(.strikethrough), family: families[index],
                        spacing: Int32((spacing * 1000).rounded()))
                }
                stateui_winui_text_set_runs(handle, words, Int32(words.count))
            }
        }
    }
}
