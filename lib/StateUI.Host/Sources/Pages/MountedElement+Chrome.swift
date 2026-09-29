// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a page gives the chrome it stands under, the same on every host - a window's one chrome, or a header bar of
/// its own: its actions, and the colours of its bar.
/// Design: docs/design/host/pages.md#the-windows-chrome
extension MountedElement {
    /// This page's actions for its chrome, by priority, then in the order written, those placed in the overflow apart;
    /// none where the page hides its bar.
    public var chromeActions: (primary: [MountedElement], overflow: [MountedElement]) {
        guard value(.hasNavigationBar)?.bool != false,
              let items = children.first(where: { $0.type == .toolbarItems })?.children.filter({ $0.type == .toolbarItem })
        else { return ([], []) }

        let ordered = items.enumerated().sorted {
            let left = $0.element.value(.priority)?.number ?? 0
            let right = $1.element.value(.priority)?.number ?? 0
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
        let overflows = { (item: MountedElement) in
            item.value(.placement)?.enumeration == ToolbarItemPlacement.overflow.rawValue
        }
        return (ordered.filter { !overflows($0) }, ordered.filter(overflows))
    }

    /// The colours this element's bar is painted in: the nearest stack's or tabbed view's around it, itself included,
    /// and what stands on the bar in, the nearest stack's - else its window's title bar's.
    public var barColors: (background: HostValue?, foreground: HostValue?) {
        var background: HostValue?
        var foreground: HostValue?
        var each: MountedElement? = self
        while let element = each, background == nil || foreground == nil {
            switch element.type {
            case .navigationStack:
                background = background ?? element.value(.barBackgroundColor)
                foreground = foreground ?? element.value(.barForegroundColor)
            case .tabbedView:
                background = background ?? element.value(.barBackgroundColor)
            case .window:
                let titleBar = element.children.first { $0.type == .titleBar }
                background = background ?? titleBar?.value(.background)
                foreground = foreground ?? titleBar?.value(.barForegroundColor)
            default:
                break
            }
            each = element.parent
        }
        return (background, foreground)
    }
}
