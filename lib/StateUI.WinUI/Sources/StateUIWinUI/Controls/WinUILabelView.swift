// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A Label: a `TextBlock` - its words, or runs of them each in its own colour, size, weight and background.
/// Design: docs/design/platforms/winui/controls.md#runs-of-words
@MainActor
final class WinUILabelView: WinUITextView {
    /// The label's own words, and the runs shown in their place; nil while it shows its own.
    private var ownText = ""
    private var runs: [TextRun]?

    override func setText(_ text: String) {
        ownText = text
        if runs == nil { super.setText(text) }
    }

    /// Runs of words shown in place of the label's own (`MountedElement.textRuns`), each in its own look over the
    /// label's; nil shows its own words again.
    func setRuns(_ runs: [TextRun]?) {
        self.runs = runs
        guard let runs else { return super.setText(ownText) }

        WinUIStrings.withCStrings(runs.map(\.text)) { texts in
            let words = runs.indices.map { index in
                let look = runs[index].look
                let color = look.color?.argb
                let background = look.background?.argb
                return StateUIWordsRun(
                    text: texts[index], color: color ?? 0, background: background ?? 0, size: look.size ?? 0,
                    hasColor: color != nil, hasBackground: background != nil,
                    bold: look.attributes.contains(.bold), italic: look.attributes.contains(.italic),
                    underline: look.decorations.contains(.underline),
                    strikethrough: look.decorations.contains(.strikethrough))
            }
            stateui_winui_text_set_runs(handle, words, Int32(words.count))
        }
    }
}
