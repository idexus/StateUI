// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The one chrome a window composes from what it shows, the same on every host: its title and the line under it, the
/// way back, and what its visible path declares - the actions, what stands in the title's place, the bars' colors,
/// the menus - with the split view it stands over, its sidebar's toggle and the title area its sidebar's page names
/// the application with: elements and values a host turns into its toolkit's chrome.
/// Design: docs/design/host/pages.md#the-windows-chrome
@_spi(Host) @MainActor public struct WindowChrome {
    /// The title of the page that names the window (`titledPage`), else the window's; nil where neither names one,
    /// which leaves the host's own.
    public var title: String?

    /// Whether the chrome shows the title: false where the page naming the window says it shows none, which
    /// leaves the title naming the window to the system alone.
    public var showsTitle = true

    /// The line under the title: the subtitle of the page that names the window; nil for none.
    public var subtitle: String?

    /// The stack whose top page the way back takes, and the way back's words.
    public var back: (stack: MountedElement, title: String)?

    /// The actions the visible page declares, composed: under a split view, its bar's detail part.
    public var actions = ChromeActions()

    /// The actions in the sidebar's part of the split view's bar, from the sidebar's page; none while the sidebar is
    /// not shown, its part's then standing among `actions`, or where the window shows no split view.
    public var sidebarActions = ChromeActions()

    /// What stands in the title's place: the title view the visible page's path declares.
    public var center: MountedElement?

    /// What names the application over the split view's sidebar - its page's title area; nil where the window
    /// shows no split view.
    public var titleArea: TitleArea?

    /// The bars' color - their material as a host that blurs nothing paints it: the nearest declared on the visible
    /// page's path.
    public var background: HostValue?

    /// What the bars are made of: the nearest declared on the visible page's path; empty for the platform's own.
    public var material = HostMaterial(nil)

    /// The color of what stands on the bars: the nearest declared on the visible page's path.
    public var foreground: HostValue?

    /// The color behind the bars' buttons: the nearest declared on the visible page's path.
    public var buttonBackground: HostValue?

    /// The weight of the words on the bars' buttons: the nearest declared on the visible page's path; nil for the
    /// platform's own.
    public var buttonFontWeight: FontWeight?

    /// How the bars' buttons stand: the nearest declared on the visible page's path, `.system` where none is.
    public var toolbarStyle = ToolbarStyle.system

    /// The menus the visible page's path declares, composed.
    public var menus = ChromeMenus()

    /// The split view the window shows, whose bar the chrome is: its sidebar's part beside the detail's.
    public var splitView: MountedElement?

    /// Whether the chrome offers the toggle showing and hiding the split view's sidebar: where the window shows one
    /// that does not say it offers none.
    public var showsSidebarToggle = false

    /// The chrome of `window` showing `arrangement`.
    public init(window: MountedElement, arrangement: MountedElement?) {
        let page = arrangement?.visiblePage
        title = arrangement?.titledPage?.value(.title)?.string ?? window.value(.title)?.string
        showsTitle = arrangement?.titledPage?.value(.showsTitle)?.bool != false
        subtitle = arrangement?.titledPage?.barSubtitle
        back = arrangement?.visibleBackStack.map { stack in
            (stack, stack.children[stack.children.count - 2].value(.backButtonTitle)?.string ?? window.tree?.core.chromeWords.back ?? "")
        }
        if let page { actions = page.chromeActions }
        if let sidebar = arrangement?.sidebarPage { sidebarActions = sidebar.chromeActions }
        center = page?.chromeTitleView
        let area = arrangement?.sidebarPage?.titleArea(applicationName: window.tree?.core.applicationName ?? "")
        titleArea = area?.isEmpty == false ? area : nil
        (background, foreground) = page?.barColors ?? (nil, nil)
        material = page?.barMaterial ?? HostMaterial(nil)
        buttonBackground = page?.barButtonBackground
        buttonFontWeight = page?.barButtonFontWeight
        toolbarStyle = page?.toolbarStyle ?? .system
        if let page { menus = page.chromeMenus }
        splitView = arrangement?.type == .splitView ? arrangement : nil
        showsSidebarToggle = splitView?.offersSidebarToggle ?? false
    }

    /// What names the application in the chrome: a title, the line under it and a picture by name.
    public struct TitleArea: Equatable, Sendable {
        /// The title; nil where the bar says none.
        public let title: String?

        /// The line under the title; nil for none.
        public let subtitle: String?

        /// The picture beside the title; nil for none.
        public let icon: HostPicture?

        /// An area saying `title`, `subtitle` and `icon`.
        public init(title: String?, subtitle: String?, icon: HostPicture?) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
        }

        /// Whether the area says nothing.
        public var isEmpty: Bool { title == nil && subtitle == nil && icon == nil }
    }

    /// Whether the chrome shows what an element of `type` moves on a frame in `changed`: a window's frame, an
    /// arrangement's bar colors, a page's words on its bar - the chrome is composed again as they move.
    public static func follows(_ type: NodeType, changed: Set<Prop>) -> Bool {
        followed.contains(type) || type == .page && !changed.isDisjoint(with: pageValues)
    }

    private static let followed: Set<NodeType> = [.window, .navigationStack, .tabView, .splitView]

    /// What of a page the chrome shows - its title, the line under it and its picture, its way back, its bar and the
    /// back button's words: a change to one shows the chrome again, from a state too.
    public static let pageValues: Set<Prop> = [
        .title, .subtitle, .icon, .showsBackButton, .showsCloseButton, .backButtonTitle, .showsNavigationBar,
        .showsTitle,
    ]
}
