// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The one chrome a window composes from what it shows, the same on every host: its title, the way back, the visible
/// page's actions, what stands in the title's place and beside it, the bars' colours, the page's menus and the
/// sidebar's toggle - elements and values a host turns into its toolkit's chrome.
/// Design: docs/design/host/pages.md#the-windows-chrome
@_spi(Host) @MainActor public struct WindowChrome {
    /// The visible page's title, else the window's; nil where neither names one, which leaves the host's own.
    public var title: String?

    /// The stack whose top page the way back takes, and the way back's words.
    public var back: (stack: MountedElement, title: String)?

    /// The visible page's actions on the chrome, by priority, then in the order written.
    public var primaryActions: [MountedElement] = []

    /// The visible page's actions behind the overflow, in the same order.
    public var overflowActions: [MountedElement] = []

    /// What stands at the chrome's leading edge: the title bar's leading content.
    public var leading: MountedElement?

    /// What stands in the title's place: the title bar's content, else the visible page's title view.
    public var center: MountedElement?

    /// What stands at the chrome's trailing edge: the title bar's trailing content.
    public var trailing: MountedElement?

    /// The bars' colour: the nearest stack's or tabbed view's around the visible page, else the title bar's.
    public var background: HostValue?

    /// The colour of what stands on the bars: the nearest stack's, else the title bar's.
    public var foreground: HostValue?

    /// The visible page's menu bar.
    public var menuBar: MountedElement?

    /// The split view whose sidebar the chrome's toggle shows and hides: the one the window shows.
    public var sidebarToggle: MountedElement?

    /// The chrome of `window` showing `arrangement`.
    public init(window: MountedElement, arrangement: MountedElement?) {
        let page = arrangement?.visiblePage
        let titleBar = window.children.first { $0.type == .titleBar }
        title = page?.value(.title)?.string ?? window.value(.title)?.string
        back = arrangement?.visibleBackStack.map { stack in
            (stack, stack.children[stack.children.count - 2].value(.backButtonTitle)?.string ?? "Back")
        }
        if let page { (primaryActions, overflowActions) = page.chromeActions }
        leading = titleBar?.slotContent(.leadingContent)
        center = titleBar?.slotContent(.content) ?? page?.slotContent(.titleView)
        trailing = titleBar?.slotContent(.trailingContent)
        (background, foreground) = (page ?? window).barColors
        menuBar = page?.children.first { $0.type == .menuBar }
        sidebarToggle = arrangement?.type == .splitView ? arrangement : nil
    }
}
