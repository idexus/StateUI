// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A sheet: a page the window's modal stack presents, on a card over a veil across the window, under the page's
/// title.
/// Design: docs/design/platforms/winui/pages.md#the-modal-stack
@MainActor
final class WinUISheetView: WinUIView {
    init() {
        super.init { _ in stateui_winui_sheet_make() }
    }

    /// Shows `page` under `title`.
    func show(title: String, page: WinUIView?) {
        stateui_winui_sheet_set(handle, title, page?.handle)
    }
}
