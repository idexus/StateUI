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
    /// A window's title, as its scene holds it.
    func windowHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        guard let window = renderer?.roster.windows.first(where: { $0.0 === element })?.1.window else {
            throw DriverCannot(reading: property, of: element)
        }
        switch property {
        case .title: return (window.windowScene?.title ?? "").propValue
        default: throw DriverCannot(reading: property, of: element)
        }
    }

    /// What a page or an arrangement of pages holds: its tab's title and picture where it stands on a tab, its bar,
    /// a tabbed view's tab and a split view's sidebar; nil for any other element.
    func pageHolds(_ property: Prop, _ element: MountedElement) throws -> HostValue? {
        guard NodeType.pageTypes.contains(element.type), let controller = (element.native as? UIKitElement)?.controller
        else { return nil }
        let onTab = controller.tabBarController != nil
        switch property {
        case .title where onTab: return (controller.tabBarItem.title ?? "").propValue
        case .icon where onTab: return controller.tabBarItem.image?.accessibilityIdentifier.map { .string($0) }
        case .title: return (controller.navigationItem.title ?? "").propValue
        case .hasBackButton: return (!controller.navigationItem.hidesBackButton).propValue
        case .hasNavigationBar:
            guard let navigation = controller.navigationController else { return nil }
            return (!navigation.isNavigationBarHidden).propValue
        case .currentPage:
            guard let tabs = controller as? UIKitTabBarController else { return nil }
            return tabs.selectedIndex.propValue
        case .isSidebarVisible:
            guard let split = controller as? UIKitSplitViewController else { return nil }
            return (split.isPresented ?? (split.displayMode != .secondaryOnly)).propValue
        case .barBackgroundColor:
            let appearance = (controller as? UINavigationController)?.topViewController?.navigationItem.standardAppearance
                ?? (controller as? UITabBarController).map { $0.tabBar.standardAppearance as UIBarAppearance }
            return appearance?.backgroundColor.map { Self.color($0).propValue }
        case .barForegroundColor:
            let appearance = (controller as? UINavigationController)?.topViewController?.navigationItem.standardAppearance
            let color = appearance?.titleTextAttributes[.foregroundColor] as? UIColor
            return color.map { Self.color($0).propValue }
        default:
            return nil
        }
    }

    /// The user's acts on pages: the way back a stack's bar offers, a tab chosen on the tab bar, an action taken on
    /// a page's bar.
    func performOnPages(_ act: UserAct, on element: MountedElement) throws {
        let native = element.native as? UIKitElement
        switch act {
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
        case .activate:
            let title = element.value(.text)?.string ?? ""
            guard let (action, enabled) = barActions().first(where: { $0.action.title == title }) else {
                throw DriverCannot(act, on: element)
            }
            // A button or an entry that cannot be taken sends nothing.
            if enabled { UIButton().sendAction(action) }
        default:
            throw DriverCannot(act, on: element)
        }
    }

    /// Every action on the bars the window shows - its buttons', and its overflow menus' entries - and whether the
    /// user can take it.
    private func barActions() -> [(action: UIAction, enabled: Bool)] {
        guard let window = renderer?.roster.windows.first?.1.window else { return [] }
        var found: [(action: UIAction, enabled: Bool)] = []
        func search(_ controller: UIViewController) {
            for item in controller.navigationItem.rightBarButtonItems ?? [] {
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
