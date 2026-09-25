// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A Label: a `TextBlock` - its words, or runs of them each in its own colour, size, weight and background.
/// Design: docs/design/platforms/winui/controls.md#runs-of-words
@MainActor
final class WinUILabelView: WinUITextView {
    /// One run of a label's words, and how it differs from the label's own.
    struct Run: Equatable {
        var text: String
        var color: HostValue?
        var size: Double?
        var attributes: FontAttributes?
        var background: HostValue?
        var decorations: TextDecorations?
    }

    /// The runs shown, in place of the label's own words.
    func setRuns(_ runs: [Run]) {
        WinUIStrings.withCStrings(runs.map(\.text)) { texts in
            let color = runs.map { $0.color.flatMap(WinUIBrush.argb) }
            let background = runs.map { $0.background.flatMap(WinUIBrush.argb) }
            let words = runs.indices.map { index in
                let run = runs[index]
                return StateUIWordsRun(
                    text: texts[index], color: color[index] ?? 0, background: background[index] ?? 0,
                    size: run.size ?? 0, hasColor: color[index] != nil, hasBackground: background[index] != nil,
                    bold: run.attributes?.contains(.bold) == true, italic: run.attributes?.contains(.italic) == true,
                    underline: run.decorations?.contains(.underline) == true,
                    strikethrough: run.decorations?.contains(.strikethrough) == true)
            }
            stateui_winui_text_set_runs(handle, words, Int32(words.count))
        }
    }
}
