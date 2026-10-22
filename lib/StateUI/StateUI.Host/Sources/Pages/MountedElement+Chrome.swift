// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a page gives the chrome it stands under, the same on every host - a window's one chrome, or a header bar of
/// its own: its actions, its title view, its menus, and its bar's colors and title area.
/// Design: docs/design/host/pages.md#the-windows-chrome
extension MountedElement {
    /// This page's actions for its chrome: the groups declared on its path, composed; none where the page hides
    /// its bar.
    /// Design: docs/design/host/pages.md#the-actions-of-a-path
    public var chromeActions: ChromeActions {
        guard value(.showsNavigationBar)?.bool != false else { return ChromeActions() }

        return ChromeActions(declared(.toolbarItemGroup))
    }

    /// What stands in this page's title place: the title view declared innermost on its path; nil where none.
    public var chromeTitleView: MountedElement? {
        declared(.titleView).last?.element.children.lazy.compactMap(\.presentingElement).first
    }

    /// The menus this page's window shows on its menu bar while the page is shown, composed from its path.
    public var chromeMenus: ChromeMenus {
        ChromeMenus(declared(.menuBar))
    }

    /// Whether this action's words stand on its bar: beside its picture where it says so, and always where it has none.
    public var showsActionWords: Bool {
        HostPicture(value(.icon)) == nil || value(.showsText)?.bool == true
    }

    /// The colors this element's bar is painted in, and what stands on it in: each the nearest declared on its path,
    /// itself included - a sheet's path ending at the modal stack showing it.
    /// Design: docs/design/host/pages.md#the-bar-a-path-declares
    public var barColors: (background: HostValue?, foreground: HostValue?) {
        (barLook(.barBackgroundColor), barLook(.barForegroundColor))
    }

    /// The color behind this element's bar's buttons, found as its bar's colors; nil for the host's own.
    public var barButtonBackground: HostValue? {
        barLook(.barButtonBackgroundColor)
    }

    /// How this element's bar's buttons stand, found as its bar's colors; `.system` where none is declared.
    public var toolbarStyle: ToolbarStyle {
        barLook(.toolbarStyle)?.enumeration.flatMap(ToolbarStyle.init(rawValue:)) ?? .system
    }

    /// `member` of how the bar looks: the nearest declared on its path, a sheet's path ending at the modal stack
    /// showing it.
    private func barLook(_ member: Prop) -> HostValue? {
        barValue(member) ?? sheetsModalStack?.value(member)
    }

    /// The tabbed views this arrangement of pages shows, itself first where it is one, through its pages and the
    /// arrangements in them: each wears the colors of the bar on its path, so a window's chrome shown again paints
    /// them again - a theme or a state moving those colors reaches no tabbed view any other way.
    /// Design: docs/design/host/pages.md#the-bar-a-path-declares
    public var tabViewsShown: [MountedElement] {
        var shown: [MountedElement] = type == .tabView ? [self] : []
        for child in children where NodeType.pageTypes.contains(child.type) { shown += child.tabViewsShown }
        return shown
    }

    /// What the application says of itself in this element's bar - its name, the line under it and its mark - each
    /// the nearest declared on its path; nil where none is. An empty line or picture is none.
    public var titleArea: WindowChrome.TitleArea? {
        let words = { (value: HostValue?) in value?.string.flatMap { $0.isEmpty ? nil : $0 } }
        let area = WindowChrome.TitleArea(
            title: words(barValue(.barTitle)), subtitle: words(barValue(.barSubtitle)), icon: HostPicture(barValue(.barIcon)))
        return area.title == nil && area.subtitle == nil && area.icon == nil ? nil : area
    }

    /// `member` of the bar: this element's own where it declares one, else the nearest arrangement's whose bar it
    /// wears - around it, and a sidebar's own split view.
    public func barValue(_ member: Prop) -> HostValue? {
        ([self] + barArrangements.reversed()).lazy.compactMap { $0.value(member) }.first
    }
}
