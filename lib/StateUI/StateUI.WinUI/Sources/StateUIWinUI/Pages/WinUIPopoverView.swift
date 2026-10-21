// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A popover's view: what it holds, standing in WinUI's `Flyout` by its anchor while it shows - the relay's popover;
/// `onClosed` hears the user take it away.
/// Design: docs/design/platforms/winui/pages.md#a-popover
@MainActor
final class WinUIPopoverView: WinUISingleChildView {
    var onClosed: (() -> Void)?

    /// The flyout holding the view, once it was first shown.
    private(set) var flyout: StateUIObjectRef?

    /// Whether the flyout shows.
    var flyoutShows: Bool {
        flyout.map { stateui_winui_popover_is_open($0) } ?? false
    }

    /// Shows the popover by `anchor`.
    func show(by anchor: WinUIView) {
        let flyout = self.flyout ?? stateui_winui_popover_make(number, handle)
        self.flyout = flyout
        flyout.map { stateui_winui_popover_show($0, anchor.handle) }
    }

    func close() {
        flyout.map { stateui_winui_popover_close($0) }
    }

    override func presented(_ open: Bool) {
        if !open { onClosed?() }
    }

    override func detach() {
        close()
        super.detach()
        onClosed = nil
    }

    isolated deinit {
        flyout.map { stateui_winui_release($0) }
    }
}
