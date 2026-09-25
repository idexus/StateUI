// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One action a page's header bar performs for the page.
@MainActor
struct GTKToolbarAction {
    let title: String

    /// The picture the button shows in place of its title, by file name; nil for the title.
    var icon: String? = nil
    let isEnabled: Bool
    let perform: () -> Void

    /// Whether two actions draw the same button. What an action performs is taken again on every composition.
    func draws(like other: GTKToolbarAction) -> Bool {
        title == other.title && icon == other.icon && isEnabled == other.isEnabled
    }
}

/// What a page's header bar shows: the page's title or its title view, the page's actions, the overflow behind the
/// bar's menu, whether the bar shows at all and whether it offers the way back.
@MainActor
struct GTKPageChrome {
    var title = ""
    var titleView: GTKView?
    var actions: [GTKToolbarAction] = []
    var overflow: [GTKToolbarAction] = []
    var showsBar = true
    var offersBack = true

    /// What the bar is painted in, and what stands on it in; nil for the platform's.
    var barBackground: HostValue?
    var barForeground: HostValue?

    /// The split view's sidebar, where this page's header bar offers its toggle - the detail's: whether it shows,
    /// and what turns it.
    var sidebar: (shows: Bool, toggle: () -> Void)?
}
