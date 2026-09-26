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
}
#endif
