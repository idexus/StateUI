// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The application's delegate: the host starts as the application does, and every scene iOS connects is one of the
/// host's.
/// Design: docs/design/platforms/uikit/runtime.md#scenes
@MainActor
final class UIKitApplicationDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UIKitRenderer.shared.start()
        return true
    }

    func application(
        _ application: UIApplication, configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = UIKitSceneDelegate.self
        return configuration
    }

    /// The main menu - on an iPad the menu bar - holds the menus of the page the user sees, before UIKit's Window
    /// menu.
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }
        for menu in UIKitRenderer.shared.menuBar { builder.insertSibling(menu, beforeMenu: .window) }
    }

    /// The user closed windows - swiped their scenes away: each window hears it.
    func application(_ application: UIApplication, didDiscardSceneSessions sessions: Set<UISceneSession>) {
        sessions.forEach(UIKitRenderer.shared.closedByUser)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        UIKitRenderer.shared.runtime.ending()
    }
}

/// A window scene iOS connects - at launch, or a window the user opens on an iPad - handed to the host, which shows
/// a StateUI scene's window in it.
@MainActor
final class UIKitSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        UIKitRenderer.shared.connect(scene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard let scene = scene as? UIWindowScene else { return }
        UIKitRenderer.shared.disconnect(scene)
    }

    func windowScene(_ scene: UIWindowScene, didUpdateEffectiveGeometry previous: UIWindowScene.Geometry) {
        UIKitRenderer.shared.environment.displayMoved(for: scene)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        (scene as? UIWindowScene).map { UIKitRenderer.shared.scene($0, movedTo: .active) }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        (scene as? UIWindowScene).map { UIKitRenderer.shared.scene($0, movedTo: .inactive) }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        (scene as? UIWindowScene).map { UIKitRenderer.shared.scene($0, movedTo: .inactive) }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        (scene as? UIWindowScene).map { UIKitRenderer.shared.scene($0, movedTo: .background) }
    }
}
#endif
