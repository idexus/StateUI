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
        return actions(on: .top)
    }

    /// This page's actions for the bar at its foot (`.toolbar(.bottom)`), by the rules of its top bar's.
    /// Design: docs/design/host/pages.md#a-pages-actions
    public var chromeBottomActions: ChromeActions {
        actions(on: .bottom)
    }

    /// This page's actions for the bar at `edge`.
    private func actions(on edge: ToolbarEdge) -> ChromeActions {
        let onEdge = { (declared: [ChromeActions.Declared]) in
            declared.filter { ($0.element.value(.barEdge).flatMap(ToolbarEdge.init(propValue:)) ?? .top) == edge }
        }
        guard let (split, part) = splitBarPart else {
            return ChromeActions(
                onEdge(arrangementsGroups(as: .detail) + ownGroups(as: .detail)), part: nil, sidebarShown: true)
        }
        let other = (part == .sidebar ? split.arrangedChildren.dropFirst().first : split.arrangedChildren.first)?
            .visiblePage
        let stacks = arrangementsGroups(as: part)
        let around = split.slots.filter { $0.type == .toolbarGroup }.map {
            ChromeActions.Declared($0, depth: -1 - stacks.count, declarersPart: .detail)
        }
        let others = other?.ownGroups(as: part == .sidebar ? .detail : .sidebar) ?? []
        return ChromeActions(
            onEdge(around + stacks + ownGroups(as: part) + others), part: part, sidebarShown: split.sidebarIsVisible)
    }

    /// The groups the stacks and tabs around this page declare for every page they show, their part unsaid being
    /// `part`: further out than the page's own, the outermost at the edge.
    /// Design: docs/design/host/pages.md#a-pages-actions
    private func arrangementsGroups(as part: ToolbarPart) -> [ChromeActions.Declared] {
        let arrangements = arrangementsAround.filter { $0.type == .navigationStack || $0.type == .tabView }
        return arrangements.enumerated().flatMap { index, arrangement in
            arrangement.slots.filter { $0.type == .toolbarGroup }.map {
                ChromeActions.Declared($0, depth: index - arrangements.count, declarersPart: part)
            }
        }
    }

    /// The groups this page's own tree declares, their part unsaid being `part`.
    private func ownGroups(as part: ToolbarPart) -> [ChromeActions.Declared] {
        declarations(.toolbarGroup).map { ChromeActions.Declared($0.element, depth: $0.depth, declarersPart: part) }
    }

    /// The split view whose bar this page stands under, and its part: the nearest around it up to its window or
    /// sheet, the sidebar's part for a page of its sidebar; nil where none stands around it.
    public var splitBarPart: (split: MountedElement, part: ToolbarPart)? {
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

    /// What stands at this page's foot: the bottom bar declared innermost on its path; nil where none, and for a page
    /// its stack or tabs do not show - a bar declared around the pages stands on the one shown, the one view in one
    /// place.
    public var chromeBottomBar: MountedElement? {
        guard isShownByItsArrangements else { return nil }
        return declared(.bottomBar).last?.element.children.lazy.compactMap(\.presentingElement).first
    }

    /// Whether every stack and tabs around this page show it: the top of each stack, the chosen tab.
    private var isShownByItsArrangements: Bool {
        var each = parent
        while let element = each, element.type != .window, element.type != .sheet {
            if element.type == .navigationStack || element.type == .tabView, element.visiblePage !== self { return false }
            each = element.parent
        }
        return true
    }

    /// How what scrolls under this page's bottom bar shows at its edge, as the bar declared innermost says.
    public var chromeBottomBarEdge: ScrollEdge {
        declared(.bottomBar).last?.element.value(.edge).flatMap(ScrollEdge.init(propValue:)) ?? .automatic
    }

    /// The menus this page's window shows on its menu bar while the page is shown, composed from its path.
    public var chromeMenus: ChromeMenus {
        ChromeMenus(declared(.menuBar))
    }

    /// Whether this action's words stand on its bar: beside its picture where it says so, and always where it has none.
    public var showsActionWords: Bool {
        TextAndIcon.showsText(value(.showsText)?.bool, hasPicture: HostPicture(value(.icon)) != nil, byDefault: false)
    }

    /// The colors this element's bar is painted in - its material as a host that blurs nothing paints it - and what
    /// stands on it in: each the nearest declared on its path, itself included.
    /// Design: docs/design/host/pages.md#the-bar-a-path-declares
    public var barColors: (background: HostValue?, foreground: HostValue?) {
        (barMaterial.painted, barValue(.barForegroundColor))
    }

    /// What this element's bar is made of, the nearest declared on its path; empty for the platform's own.
    /// Design: docs/design/host/pages.md#the-bar-a-path-declares
    public var barMaterial: HostMaterial {
        HostMaterial(barValue(.barBackground))
    }

    /// How this element's bar's buttons stand, found as its bar's colors; `.system` where none is declared.
    public var toolbarStyle: ToolbarStyle {
        barValue(.toolbarStyle)?.enumeration.flatMap(ToolbarStyle.init(rawValue:)) ?? .system
    }

    /// The room between this element's bar's groups, found as its bar's colors; nil for the host's own.
    public var toolbarSpacing: Double? {
        barValue(.toolbarSpacing)?.number
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

    /// The line under this page's title on its bar: its own subtitle; nil where it says none, or an empty one.
    /// Design: docs/design/host/pages.md#a-pages-title-area
    public var barSubtitle: String? {
        value(.subtitle)?.string.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// What this page's bar says where it names the application - a sidebar's page's: its title, else the
    /// application's `applicationName`; the line under it; and its picture.
    /// Design: docs/design/host/pages.md#a-pages-title-area
    public func titleArea(applicationName: String) -> WindowChrome.TitleArea {
        let title = barTitle(applicationName: applicationName)
        return WindowChrome.TitleArea(
            title: title.isEmpty ? nil : title, subtitle: barSubtitle, icon: HostPicture(value(.icon)))
    }

    /// `member` of the bar: this element's own where it declares one, else the nearest arrangement's whose bar it
    /// wears - around it, and a sidebar's own split view.
    public func barValue(_ member: Prop) -> HostValue? {
        ([self] + barArrangements.reversed()).lazy.compactMap { $0.value(member) }.first
    }
}
