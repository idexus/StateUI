// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The one chrome a window composes from what it shows, the same on every host: its title, the way back, and what its
/// visible path declares - the actions, what stands in the title's place, the title area, the bars' colours, the
/// menus - with the sidebar's toggle: elements and values a host turns into its toolkit's chrome.
/// Design: docs/design/host/pages.md#the-windows-chrome
@_spi(Host) @MainActor public struct WindowChrome {
    /// The title of the page that names the window (`titledPage`), else the window's; nil where neither names one,
    /// which leaves the host's own.
    public var title: String?

    /// The stack whose top page the way back takes, and the way back's words.
    public var back: (stack: MountedElement, title: String)?

    /// The actions the visible page's path declares, composed.
    public var actions = ChromeActions()

    /// What stands in the title's place: the title view the visible page's path declares.
    public var center: MountedElement?

    /// What the application says of itself in the bar, declared on the visible page's path; nil for none.
    public var titleArea: TitleArea?

    /// The bars' colour: the nearest declared on the visible page's path.
    public var background: HostValue?

    /// The colour of what stands on the bars: the nearest declared on the visible page's path.
    public var foreground: HostValue?

    /// The menus the visible page's path declares, composed.
    public var menus = ChromeMenus()

    /// The split view whose sidebar the chrome's toggle shows and hides: the one the window shows.
    public var sidebarToggle: MountedElement?

    /// The chrome of `window` showing `arrangement`.
    public init(window: MountedElement, arrangement: MountedElement?) {
        let page = arrangement?.visiblePage
        title = arrangement?.titledPage?.value(.title)?.string ?? window.value(.title)?.string
        back = arrangement?.visibleBackStack.map { stack in
            (stack, stack.children[stack.children.count - 2].value(.backButtonTitle)?.string ?? "Back")
        }
        if let page { actions = page.chromeActions }
        center = page?.chromeTitleView
        titleArea = page?.titleArea
        (background, foreground) = page?.barColors ?? (nil, nil)
        if let page { menus = page.chromeMenus }
        sidebarToggle = arrangement?.type == .splitView ? arrangement : nil
    }

    /// What the application says of itself in the bar: its name, the line under it, and its mark by name.
    public struct TitleArea: Equatable, Sendable {
        /// The title; nil where the bar says none.
        public let title: String?

        /// The line under the title; nil for none.
        public let subtitle: String?

        /// The picture beside the title, by name; nil for none.
        public let icon: String?

        /// An area saying `title`, `subtitle` and `icon`.
        public init(title: String?, subtitle: String?, icon: String?) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
        }
    }

    /// Whether the chrome shows what an element of `type` moves on a frame: a window's frame, an arrangement's bar
    /// colours - the chrome is composed again as they move.
    public static func follows(_ type: NodeType) -> Bool {
        followed.contains(type)
    }

    private static let followed: Set<NodeType> = [.window, .navigationStack, .tabView, .splitView, .modalStack]
}
