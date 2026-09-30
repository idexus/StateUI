// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a page gives the chrome it stands under, the same on every host - a window's one chrome, or a header bar of
/// its own: its actions, its title view, and the colours of its bar.
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

    /// Whether this action's words stand on its bar: beside its picture where it says so, and always where it has none.
    public var showsActionWords: Bool {
        (value(.icon)?.string ?? "").isEmpty || value(.showsText)?.bool == true
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
