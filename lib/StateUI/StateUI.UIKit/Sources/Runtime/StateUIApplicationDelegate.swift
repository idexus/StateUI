// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The application's delegate: the host starts as the application does, and every scene iOS connects is one of the
/// host's. An application whose SDK asks for a delegate of its own subclasses it, calling `super` where it overrides,
/// and hands it to `StateUIUIKit.run(delegate:)`:
///
///     final class AppDelegate: StateUIApplicationDelegate {
///         override func application(
///             _ application: UIApplication,
///             didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
///         ) -> Bool {
///             Analytics.start()
///             return super.application(application, didFinishLaunchingWithOptions: options)
///         }
///     }
/// Design: docs/design/platforms/uikit/runtime.md#scenes
@MainActor
open class StateUIApplicationDelegate: UIResponder, UIApplicationDelegate {
    /// Starts the host as the application launches.
    open func application(
        _ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UIKitRenderer.shared.start()
        return true
    }

    /// Every scene iOS connects is one of the host's.
    open func application(
        _ application: UIApplication, configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = UIKitSceneDelegate.self
        return configuration
    }

    /// The main menu - on an iPad the menu bar - holds the menus of the page the user sees: a standard one as a
    /// section at the end of UIKit's own menu of its identity, one UIKit keeps none of where UIKit's would stand -
    /// View after Edit, Help after Window - and any other before Window.
    /// Design: docs/design/platforms/uikit/pages.md#menus
    override open func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }
        let renderer = UIKitRenderer.shared
        for (entry, menu) in zip(renderer.pageMenus, renderer.menuBar) {
            guard let standard = entry.standard else {
                builder.insertSibling(menu, beforeMenu: .window)
                continue
            }
            let identifier = UIKitMenus.identifier(standard)
            if builder.menu(for: identifier) != nil {
                builder.insertChild(UIMenu(options: .displayInline, children: menu.children), atEndOfMenu: identifier)
            } else if standard == .help {
                builder.insertSibling(menu, afterMenu: .window)
            } else if standard == .view, builder.menu(for: .edit) != nil {
                builder.insertSibling(menu, afterMenu: .edit)
            } else {
                builder.insertSibling(menu, beforeMenu: .window)
            }
        }
    }

    /// The user closed windows - swiped their scenes away: each window hears it.
    open func application(_ application: UIApplication, didDiscardSceneSessions sessions: Set<UISceneSession>) {
        sessions.forEach(UIKitRenderer.shared.closedByUser)
    }

    /// The application ends: every window hears it is going.
    open func applicationWillTerminate(_ application: UIApplication) {
        UIKitRenderer.shared.runtime.ending()
    }
}
#endif
