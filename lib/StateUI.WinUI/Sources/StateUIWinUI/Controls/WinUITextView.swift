// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A WinUI `TextBlock`: its words and their colour.
@MainActor
class WinUITextView: WinUIView {
    init() {
        super.init { _ in stateui_winui_text_make() }
    }

    /// The words shown.
    func setText(_ text: String) {
        stateui_winui_text_set_text(handle, text)
    }

    /// The words' colour as 0xAARRGGBB; nil puts back the platform's.
    func setTextColor(_ argb: UInt32?) {
        stateui_winui_text_set_color(handle, argb != nil, argb ?? 0)
    }

    /// The words the element shows now, read back from WinUI.
    var text: String {
        WinUIView.words(of: handle)
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
