// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A WinUI `HyperlinkButton` holding no address: the host layer opens the link's as the user chooses it.
/// Design: docs/design/platforms/winui/controls.md#a-link
@MainActor
final class WinUILinkView: WinUIView, WinUIWordsView {
    /// What a click does: the host layer opens the link's address.
    var onClicked: (() -> Void)?

    override var takesDirection: Bool { true }

    init() {
        super.init { number in stateui_winui_button_make(number, .link) }
        stateui_winui_button_set_content(handle, "", "", 0, -1, 0, false, false)
    }

    func setText(_ text: String) {
        stateui_winui_button_set_words(handle, text)
    }

    /// The words the link shows now, read back from WinUI.
    var text: String {
        WinUIView.words(of: handle)
    }

    override func clicked() {
        onClicked?()
    }

    override func detach() {
        super.detach()
        onClicked = nil
    }
}
