// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// What stands in a stack beside its controls, which the relay makes and nothing else sets.
/// Design: docs/design/host/layout.md#a-separator-in-a-stack
@MainActor
final class WinUIStackPartView: WinUIView {
    /// A separator in a stack: a panel holding the theme's divider line, one pixel thick both ways.
    static func separator() -> WinUIStackPartView {
        WinUIStackPartView { stateui_winui_separator_make() }
    }

    private init(_ make: () -> StateUIObjectRef?) {
        super.init { _ in make() }
    }
}
