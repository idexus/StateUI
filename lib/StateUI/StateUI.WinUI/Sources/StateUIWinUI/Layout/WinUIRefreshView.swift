// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// WinUI's `RefreshContainer`, which a ScrollView's scroller stands in while it offers the pull to refresh.
/// Design: docs/design/platforms/winui/layout.md#the-pull-to-refresh
@MainActor
final class WinUIRefreshView: WinUIView {
    /// Hears the user's pull; answers whether its spinner stays.
    var onPulled: (() -> Bool)?

    init() {
        super.init { number in stateui_winui_refresh_make(number) }
    }

    /// Whether a scroller stands in it: the pull offered.
    private(set) var isOffered = false

    /// Stands `content` in the container - none for the pull withheld - and its refresh under way or not.
    func set(content: WinUIView?, refreshing: Bool) {
        isOffered = content != nil
        stateui_winui_refresh_set(handle, content?.handle, refreshing)
    }

    override func detach() {
        super.detach()
        onPulled = nil
    }
}
