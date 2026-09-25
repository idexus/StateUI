// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI

/// A SearchField: WinUI's `AutoSuggestBox` with its search glyph, whose query submits.
@MainActor
final class WinUISearchFieldView: WinUIInputView {
    init() {
        super.init { number in stateui_winui_search_make(number) }
    }
}
