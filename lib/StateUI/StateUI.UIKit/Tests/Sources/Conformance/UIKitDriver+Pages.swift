// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// What the UIKit driver reads of windows and pages, and does to them: each from UIKit's own controllers - a window's
/// scene, a page's bar and tab item, a tab bar's choice, a split view's sidebar - and through their own paths.
/// Design: docs/design/platforms/uikit/conformance.md#what-the-driver-reads
extension UIKitDriver {
    /// A window's title, as its scene holds it, and its background.
    func windowHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        guard let window = renderer?.roster.windows.first(where: { $0.0 === element })?.1.window else {
            throw DriverCannot(reading: property, of: element)
        }
        switch property {
        case .title: return (window.windowScene?.title ?? "").propValue
        case .background: return window.backgroundColor.map { StandIns.material(painted: Self.color($0)).propValue }
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// What a page or an arrangement of pages holds: its tab's title and picture where it stands on a tab, its bar,
    /// a tabbed view's tab and a split view's sidebar; nil for any other element.
    func pageHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        if [.menuItem, .menuToggle].contains(element.type), let command = menuCommand(of: element) {
            switch property {
            case .text: return command.title.propValue
            case .icon: return command.image?.accessibilityIdentifier.map { .string($0) }
            case .isEnabled: return (!command.attributes.contains(.disabled)).propValue
            case .role: return (command.attributes.contains(.destructive) ? ActionRole.destructive : .normal).propValue
            case .isOn: return (command.state == .on).propValue
            case .accessibilityIdentifier: return command.accessibilityIdentifier.map { .string($0) }
            case .keyboardShortcut: return UIKitKeys.shortcut(of: command)?.propValue
            default: break
            }
        }
        if [.menuItem, .menuToggle, .toolbarButton, .toolbarToggle].contains(element.type),
           let action = menuAction(of: element) {
            switch property {
            case .keyboardShortcut where [.toolbarButton, .toolbarToggle].contains(element.type):
                return element.value(.keyboardShortcut)
            // A setting on the bar stands selected; one behind the overflow, checked.
            case .isOn where element.type == .toolbarToggle:
                return (barButton(answering: action)?.isSelected ?? (action.state == .on)).propValue
            case .text: return action.title.propValue
            case .icon: return action.image?.accessibilityIdentifier.map { .string($0) }
            case .isEnabled: return (!action.attributes.contains(.disabled)).propValue
            case .role: return (action.attributes.contains(.destructive) ? ActionRole.destructive : .normal).propValue
            case .isOn: return (action.state == .on).propValue
            case .accessibilityIdentifier: return action.accessibilityIdentifier.map { .string($0) }
            default: break
            }
        }
        if [.barBackground, .barForegroundColor].contains(property)
            || property == .subtitle && element.type == .page {
            return Self.barHolds(property, of: element)
        }
        guard NodeType.pageTypes.contains(element.type), let controller = (element.native as? UIKitElement)?.controller
        else { return nil }
        let onTab = controller.tabBarController != nil
        switch property {
        case .title where onTab: return (controller.tabBarItem.title ?? "").propValue
        case .icon where onTab: return controller.tabBarItem.image?.accessibilityIdentifier.map { .string($0) }
        case .title: return (controller.navigationItem.title ?? "").propValue
        case .showsBackButton: return (!controller.navigationItem.hidesBackButton).propValue
        case .showsCloseButton: return (Self.closeAction(on: controller) != nil).propValue
        // The bar shows the title where it holds no view in its place.
        case .showsTitle: return (controller.navigationItem.titleView == nil).propValue
        case .backButtonTitle: return controller.navigationItem.backButtonTitle?.propValue
        case .showsNavigationBar:
            guard let navigation = controller.navigationController else { return nil }
            return (!navigation.isNavigationBarHidden).propValue
        case .selectedTab:
            guard let tabs = controller as? UIKitTabBarController else { return nil }
            return tabs.selectedIndex.propValue
        case .showsSidebar:
            guard let split = controller as? UISplitViewController else { return nil }
            return (split.displayMode != .secondaryOnly).propValue
        case .showsSidebarToggle:
            guard let split = controller as? UISplitViewController else { return nil }
            return (split.displayModeButtonVisibility != .never).propValue
        case .sidebarOverlays:
            guard let split = controller as? UISplitViewController else { return nil }
            return (split.splitBehavior == .overlay).propValue
        case .sidebarBackground, .sidebarOverlayBackground:
            // The sidebar page's view in the place it stands; the other place's material as the split view says it.
            guard let split = controller as? UIKitSplitViewController else { return nil }
            guard split.overlays == (property == .sidebarOverlayBackground) else {
                return element.sidebarMaterial(over: !split.overlays).paint
            }
            let sidebar = (element.children.first?.native as? UIKitElement)?.controller
            return sidebar?.view.backgroundColor.map { Material.color(Self.color($0)).propValue }
        default:
            return nil
        }
    }

    /// What the bar an arrangement declares stands on: a tabbed view's tab bar, else the bar of the page it shows -
    /// its material, the color of its title, and the line under a page's title.
    private static func barHolds(_ property: Prop, of element: MountedElement) -> HostValue? {
        if let tabs = (element.native as? UIKitElement)?.controller as? UITabBarController {
            let appearance = tabs.tabBar.standardAppearance
            switch property {
            case .barBackground: return material(of: appearance)
            case .barForegroundColor:
                let words = appearance.stackedLayoutAppearance.selected.titleTextAttributes[.foregroundColor]
                return (words as? UIColor).map { color($0).propValue }
            default: break
            }
        }
        guard let item = (element.visiblePage?.native as? UIKitElement)?.controller?.navigationItem else { return nil }
        switch property {
        case .barBackground: return item.standardAppearance.flatMap(material(of:))
        case .barForegroundColor:
            return (item.standardAppearance?.titleTextAttributes[.foregroundColor] as? UIColor).map { color($0).propValue }
        case .subtitle: return item.subtitle.map { .string($0) }
        default: return nil
        }
    }

    /// What a bar's appearance stands on: UIKit's blur in one of its five thicknesses under its tint, else its color.
    private static func material(of appearance: UIBarAppearance) -> HostValue? {
        let tint = appearance.backgroundColor.map(color)
        guard let effect = appearance.backgroundEffect, let thickness = Blur.Thickness.allCases.first(where: {
            UIBlurEffect(style: UIKitBackdropView.style($0)).isEqual(effect)
        }) else { return tint?.propValue }
        let blur = Blur(thickness)
        return Material.blur(tint.map(blur.tint) ?? blur).propValue
    }

    /// The user's acts on pages: the way back a stack's bar offers, a tab chosen on the tab bar, an action taken on
    /// a page's bar.
    func performOnPages(_ act: UserAct, on element: MountedElement) throws {
        let native = element.native as? UIKitElement
        switch act {
        case .goBack where element.type == .window:
            try goBack(in: element)
        case .goBack:
            guard let navigation = native?.controller as? UIKitNavigationController, navigation.viewControllers.count > 1
            else { throw DriverCannot(act, on: element) }
            navigation.popViewController(animated: false)
        case .choose(let place):
            guard let tabs = native?.controller as? UIKitTabBarController, let shown = tabs.viewControllers,
                  shown.indices.contains(place)
            else { throw DriverCannot(act, on: element) }
            // As the tab bar does: the controller is asked, then shows the tab and says so.
            guard tabs.delegate?.tabBarController?(tabs, shouldSelect: shown[place]) ?? true else { return }
            tabs.selectedIndex = place
            tabs.delegate?.tabBarController?(tabs, didSelect: shown[place])
        case .toggle:
            // As the sidebar button UIKit puts on the detail's bar does - an item of UIKit's own, which the split view
            // hands out bare: the column shown where it is hidden, and hidden where it shows.
            guard let split = native?.controller as? UISplitViewController else { throw DriverCannot(act, on: element) }
            split.displayMode == .secondaryOnly ? split.show(.primary) : split.hide(.primary)
        case .activate:
            // The action UIKit holds for this item, found by its element's identifier - never by its words.
            guard let identifier = (element.native as? UIKitElement)?.actionIdentifier,
                  let (action, enabled) = barActions().first(where: { $0.action.identifier == identifier }) else {
                throw DriverCannot(act, on: element)
            }
            // A button or an entry that cannot be taken sends nothing.
            if enabled { UIButton().sendAction(action) }
        default:
            throw DriverCannot(act, on: element)
        }
    }

    /// The window's way back, as the user takes it: the top sheet swiped down, else the stack's back button.
    private func goBack(in window: MountedElement) throws {
        guard let controller = renderer?.roster.windows.first(where: { $0.0 === window })?.1 else {
            throw DriverCannot("go back in a window the host does not show")
        }
        guard let way = controller.presentation.wayBack else {
            throw DriverCannot("go back in a window offering no way back")
        }
        switch way {
        case .dismissSheets:
            // A user swipes a sheet down once UIKit shows it.
            let asked = controller.presentation.sheets.count
            if let root = controller.window?.rootViewController {
                for _ in 0..<150 {
                    guard Self.presented(over: root) < asked || root.transitionCoordinator != nil else { break }
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
                }
            }
            guard let root = controller.window?.rootViewController, let top = Self.topSheet(over: root),
                  let presentation = top.presentationController
            else { throw DriverCannot("go back from a sheet UIKit does not present") }
            top.presentingViewController?.dismiss(animated: false)
            presentation.delegate?.presentationControllerDidDismiss?(presentation)
        case .pop(let stack):
            try performOnPages(.goBack, on: stack)
        }
    }

    /// How many controllers stand presented over `root`, each over the one before.
    private static func presented(over root: UIViewController) -> Int {
        var count = 0
        var top = root.presentedViewController
        while let each = top {
            count += 1
            top = each.presentedViewController
        }
        return count
    }

    /// The close button's action on the bar over `controller`'s page; nil where it offers none.
    static func closeAction(on controller: UIViewController) -> UIAction? {
        controller.navigationItem.trailingItemGroups.flatMap(\.barButtonItems).lazy
            .compactMap(\.primaryAction).first { $0.identifier == UIKitPageChrome.closeIdentifier }
    }

    /// The controller presented last over `root`.
    private static func topSheet(over root: UIViewController) -> UIViewController? {
        var top = root.presentedViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }

    /// The bar's button whose action is `action`; nil for one behind an overflow.
    /// The menu a button on the bars the window shows opens, by its identifier.
    func barMenu(identified identifier: UIMenu.Identifier) -> UIMenu? {
        guard let window = renderer?.roster.windows.first?.1.window else { return nil }
        func search(_ controller: UIViewController) -> UIMenu? {
            let groups = controller.navigationItem.leadingItemGroups + controller.navigationItem.trailingItemGroups
            if let menu = groups.flatMap(\.barButtonItems).compactMap(\.menu).first(where: { $0.identifier == identifier }) {
                return menu
            }
            return controller.children.lazy.compactMap(search).first
        }
        return window.rootViewController.flatMap(search)
    }

    private func barButton(answering action: UIAction) -> UIBarButtonItem? {
        guard let window = renderer?.roster.windows.first?.1.window else { return nil }
        func search(_ controller: UIViewController) -> UIBarButtonItem? {
            let groups = controller.navigationItem.leadingItemGroups + controller.navigationItem.trailingItemGroups
            if let item = groups.flatMap(\.barButtonItems).first(where: { $0.primaryAction === action }) { return item }
            return controller.children.lazy.compactMap(search).first
        }
        return window.rootViewController.flatMap(search)
    }

    /// Every action on the bars the window shows - its buttons', and its overflow menus' entries - and whether the
    /// user can take it.
    private func barActions() -> [(action: UIAction, enabled: Bool)] {
        guard let window = renderer?.roster.windows.first?.1.window else { return [] }
        var found: [(action: UIAction, enabled: Bool)] = []
        func search(_ controller: UIViewController) {
            let groups = controller.navigationItem.leadingItemGroups + controller.navigationItem.trailingItemGroups
            for item in groups.flatMap(\.barButtonItems) {
                if let action = item.primaryAction { found.append((action, item.isEnabled)) }
                for case let entry as UIAction in item.menu?.children ?? [] {
                    found.append((entry, !entry.attributes.contains(.disabled)))
                }
            }
            controller.children.forEach(search)
        }
        window.rootViewController.map(search)
        return found
    }
}
