// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A window scene iOS connects - at launch, or a window the user opens on an iPad - handed to the host, which shows
/// a StateUI scene's window in it.
@MainActor
final class UIKitSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        UIKitRenderer.shared.connect(scene)
        UIKitRenderer.shared.openLinks(options.urlContexts.map(\.url.absoluteString).sorted(), in: scene)
    }

    /// The system asks the scene to open links - a scheme the application's head registers.
    func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
        guard let scene = scene as? UIWindowScene else { return }
        UIKitRenderer.shared.openLinks(contexts.map(\.url.absoluteString).sorted(), in: scene)
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
