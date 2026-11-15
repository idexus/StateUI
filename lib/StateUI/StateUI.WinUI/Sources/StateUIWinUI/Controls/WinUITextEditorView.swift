// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A TextEditor: a WinUI `TextBox` of several lines, whose Enter starts a new one; growing with its words, or
/// keeping the height it is given and scrolling them.
/// Design: docs/design/platforms/winui/controls.md#an-editor
@MainActor
final class WinUITextEditorView: WinUITextInputView {
    /// Whether the editor takes the height of its words.
    var growsWithText = false {
        didSet { if growsWithText != oldValue { invalidateMeasure() } }
    }

    init() {
        super.init { number in stateui_winui_editor_make(number) }
    }

    /// Growing, the height its words take; not growing, one line's, whatever it holds.
    /// Design: docs/design/platforms/winui/controls.md#an-editor
    override func measure(width: Double?, height: Double?) -> LayoutSize {
        guard !growsWithText else { return super.measure(width: width, height: height) }
        let own = super.measure(width: width, height: 0)
        return LayoutSize(width: own.width, height: lineHeight(width: width ?? .infinity))
    }

    /// The empty TextBox WinUI measures the editor's line by, once it was first measured.
    private var line: StateUIObjectRef?

    /// The height of one of the editor's lines at `width`, as WinUI measures it on the editor's window.
    private func lineHeight(width: Double) -> Double {
        guard let line = line ?? stateui_winui_editor_line_make() else { return 0 }
        self.line = line
        return stateui_winui_editor_line_height(handle, line, width)
    }

    isolated deinit {
        line.map { stateui_winui_release($0) }
    }
}
