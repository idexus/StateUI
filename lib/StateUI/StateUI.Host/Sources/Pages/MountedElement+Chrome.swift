// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a page gives the chrome it stands under, the same on every host - a window's one chrome, or a header bar of
/// its own: its actions, its title view, its menus, and its bar's colors and title area.
/// Design: docs/design/host/pages.md#the-windows-chrome
extension MountedElement {
    /// This page's actions for its chrome: its own groups, and under a split view its part of the split view's one
    /// bar - the split view's groups and the other column's page's standing there; none where the page hides its bar.
    /// Design: docs/design/host/pages.md#a-pages-actions
    public var chromeActions: ChromeActions {
        guard value(.showsNavigationBar)?.bool != false else { return ChromeActions() }

        guard let (split, part) = splitBarPart else {
            return ChromeActions(ownGroups(as: .detail), part: nil, sidebarShown: true)
        }
        let other = (part == .sidebar ? split.arrangedChildren.dropFirst().first : split.arrangedChildren.first)?
            .visiblePage
        let around = split.slots.filter { $0.type == .toolbarGroup }.map {
            ChromeActions.Declared($0, depth: -1, declarersPart: .detail)
        }
        let others = other?.ownGroups(as: part == .sidebar ? .detail : .sidebar) ?? []
        return ChromeActions(around + ownGroups(as: part) + others, part: part, sidebarShown: split.sidebarIsVisible)
    }

    /// The groups this page's own tree declares, their part unsaid being `part`.
    private func ownGroups(as part: ToolbarPart) -> [ChromeActions.Declared] {
        declarations(.toolbarGroup).map { ChromeActions.Declared($0.element, depth: $0.depth, declarersPart: part) }
    }

    /// The split view whose bar this page stands under, and its part: the nearest around it up to its window or
    /// sheet, the sidebar's part for a page of its sidebar; nil where none stands around it.
    var splitBarPart: (split: MountedElement, part: ToolbarPart)? {
        var (child, each) = (self, parent)
        while let element = each, element.type != .window, element.type != .sheet {
            if element.type == .splitView {
                return (element, element.arrangedChildren.first === child ? .sidebar : .detail)
            }
            (child, each) = (element, element.parent)
        }
        return nil
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
        TextAndIcon.showsText(value(.showsText)?.bool, hasPicture: HostPicture(value(.icon)) != nil, byDefault: false)
    }

    /// The colors this element's bar is painted in, and what stands on it in: each the nearest declared on its path,
    /// itself included.
    /// Design: docs/design/host/pages.md#the-bar-a-path-declares
    public var barColors: (background: HostValue?, foreground: HostValue?) {
        (barValue(.barBackgroundColor), barValue(.barForegroundColor))
    }

    /// The color behind this element's bar's buttons, found as its bar's colors; nil for the host's own.
    public var barButtonBackground: HostValue? {
        barValue(.barButtonBackgroundColor)
    }

    /// How this element's bar's buttons stand, found as its bar's colors; `.system` where none is declared.
    public var toolbarStyle: ToolbarStyle {
        barValue(.toolbarStyle)?.enumeration.flatMap(ToolbarStyle.init(rawValue:)) ?? .system
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
