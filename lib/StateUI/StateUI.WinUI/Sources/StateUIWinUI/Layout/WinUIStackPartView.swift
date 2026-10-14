// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// What stands in a stack beside its controls, which the relay makes and nothing else sets.
/// Design: docs/design/host/layout.md#a-spacer
@MainActor
final class WinUIStackPartView: WinUIView {
    /// A spacer: an empty panel, asking for no room.
    static func spacer() -> WinUIStackPartView {
        WinUIStackPartView { stateui_winui_spacer_make() }
    }

    /// A divider in a stack: a panel holding the theme's divider line, one pixel thick both ways.
    static func divider() -> WinUIStackPartView {
        WinUIStackPartView { stateui_winui_divider_make() }
    }

    private init(_ make: () -> StateUIObjectRef?) {
        super.init { _ in make() }
    }
}
