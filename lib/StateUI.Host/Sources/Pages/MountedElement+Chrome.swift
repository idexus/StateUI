// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a page gives the chrome it stands under, the same on every host - a window's one chrome, or a header bar of
/// its own: its actions, its title view, its menus, and its bar's colours and title area.
/// Design: docs/design/host/pages.md#the-windows-chrome
extension MountedElement {
    /// This page's actions for its chrome: the groups declared on its path, composed; none where the page hides
    /// its bar.
    /// Design: docs/design/host/pages.md#the-actions-of-a-path
    public var chromeActions: ChromeActions {
        guard value(.hasNavigationBar)?.bool != false else { return ChromeActions() }

        return ChromeActions(declared(.toolbarItems))
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
        (value(.icon)?.string ?? "").isEmpty || value(.showsText)?.bool == true
    }

    /// The colours this element's bar is painted in, and what stands on it in: each the nearest declared on its path,
    /// itself included.
    /// Design: docs/design/host/pages.md#the-bar-a-path-declares
    public var barColors: (background: HostValue?, foreground: HostValue?) {
        (barValue(.barBackgroundColor), barValue(.barForegroundColor))
    }

    /// What the application says of itself in this element's bar - its name, the line under it and its mark - each
    /// the nearest declared on its path; nil where none is. An empty line or picture is none.
    public var titleArea: WindowChrome.TitleArea? {
        let words = { (value: HostValue?) in value?.string.flatMap { $0.isEmpty ? nil : $0 } }
        let area = WindowChrome.TitleArea(
            title: words(barValue(.barTitle)), subtitle: words(barValue(.barSubtitle)), icon: words(barValue(.barIcon)))
        return area.title == nil && area.subtitle == nil && area.icon == nil ? nil : area
    }

    /// `member` of the bar: this element's own where it declares one, else the nearest arrangement's whose bar it
    /// wears - around it, and a sidebar's own split view.
    public func barValue(_ member: Prop) -> HostValue? {
        ([self] + barArrangements.reversed()).lazy.compactMap { $0.value(member) }.first
    }
}
