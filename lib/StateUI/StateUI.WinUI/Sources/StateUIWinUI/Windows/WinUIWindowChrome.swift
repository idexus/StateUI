// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a window's chrome shows, composed from the visible arrangement: the title and the line under it, or the title
/// area its sidebar's page names the application with, the way back and the sidebar's toggle, the groups of actions at each edge and in overflow, its title view, the bar's
/// colors, the page's menus beneath, a sheet's way back and going, Escape - the way out in sight pressed - and a key
/// a view takes.
/// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
@MainActor
struct WinUIWindowChrome {
    var title = ""
    /// Whether the title bar shows the title; the window keeps it for the system all the same.
    var showsTitle = true
    var subtitle: String?
    var titleArea: WindowChrome.TitleArea?
    var back: WinUIToolbarAction?
    var sidebarToggle: (() -> Void)?
    var center: WinUIView?
    var leading: [[WinUIToolbarAction]] = []
    var trailing: [[WinUIToolbarAction]] = []
    var overflow: [WinUIToolbarAction] = []
    var background: HostValue?
    var foreground: HostValue?
    var menuBar = WinUIMenu()
    var sheet: (back: () -> Void, dismiss: () -> Void)?
    var escape: (() -> Bool)?
    var takeKey: ((KeyboardShortcut) -> Bool)?
}
