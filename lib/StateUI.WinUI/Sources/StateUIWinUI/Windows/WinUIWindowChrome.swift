// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a window's chrome shows, composed from the visible arrangement: the title or the title area its path
/// declares, the way back and the sidebar's toggle, the page's actions and those in overflow, its title view, the
/// bar's colours, and the page's menus beneath.
/// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
@MainActor
struct WinUIWindowChrome {
    var title = ""
    /// The application's name, line and mark its path declares, shown in the place of the title naming the window.
    var titleArea: WindowChrome.TitleArea?
    var back: WinUIToolbarAction?
    var sidebarToggle: (() -> Void)?
    var center: WinUIView?
    var actions: [WinUIToolbarAction] = []
    var overflow: [WinUIToolbarAction] = []
    var background: HostValue?
    var foreground: HostValue?
    var menuBar = WinUIMenu()

    /// While a sheet shows: its way back - its own stack's, else it going - and it going, which Escape asks.
    var sheet: (back: () -> Void, dismiss: () -> Void)?
}
