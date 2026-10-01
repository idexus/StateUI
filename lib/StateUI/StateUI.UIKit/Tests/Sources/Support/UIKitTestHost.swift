// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance

/// The scene every test's windows stand in: the first iOS connected to the runner's application.
@MainActor
enum TestScene {
    static var scene: UIWindowScene?

    /// Where the tests' hosts keep values, apart from the application's own.
    static let preferences = UserDefaults(suiteName: "StateUI.UIKitTests")!

    /// Forgets every value the tests' hosts kept.
    static func forgetWhatIsKept() {
        preferences.removePersistentDomain(forName: "StateUI.UIKitTests")
    }
}

extension UIKitRenderer {
    /// A host running the application whose only window shows what `page` builds, in the tests' scene, laid out;
    /// on `clock` where one is given.
    static func running(
        clock: TestClock? = nil, reducesMotion: Bool = false, preferences: UserDefaults = TestScene.preferences,
        _ page: @escaping @Sendable () -> any Page
    ) -> UIKitRenderer {
        running(clock: clock, reducesMotion: reducesMotion, preferences: preferences) {
            OneWindowApplication(page: page)
        }
    }

    /// A host running `application` in the tests' scene, laid out, its kept values read from `preferences` first,
    /// as a launch reads them.
    static func running(
        clock: TestClock? = nil, reducesMotion: Bool = false, preferences: UserDefaults = TestScene.preferences,
        application: @escaping @Sendable () -> any Application
    ) -> UIKitRenderer {
        stateUIUseApp(application())
        UIKitRenderer.resourceDirectory = Bundle.main.resourceURL?.appendingPathComponent("Images", isDirectory: true)
        let renderer = UIKitRenderer(
            clock: clock.map { clock in { clock.now } }, preferences: preferences, reducesMotion: { reducesMotion })
        renderer.ownsScenes = false
        renderer.hydratePersistentState()
        renderer.connect(TestScene.scene!)
        renderer.layOut()
        return renderer
    }

    /// Lays out every window as the display's next pass would.
    func layOut() {
        for (_, controller) in roster.windows {
            controller.window?.layoutIfNeeded()
        }
    }

    /// One display frame at the clock's time, as the display link gives one.
    func frame() {
        runtime.displayCycle.frame(now: frameClock.now())
    }

    /// Turns the main run loop until `done` holds: a handler resumed on the main queue runs there.
    func settle(until done: () -> Bool) {
        for _ in 0..<150 where !done() {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            runtime.pump.turn()
            layOut()
        }
    }

    /// Ends the host: its windows leave the tests' scene, which stays for the next, and its tree leaves. A sheet still
    /// moving in the scene would stop the next window's own from coming: every sheet goes first, and UIKit is let
    /// finish.
    func finish() {
        for (_, controller) in roster.windows {
            guard let root = controller.window?.rootViewController, root.presentedViewController != nil else { continue }
            root.dismiss(animated: false)
            for _ in 0..<100 where root.presentedViewController != nil || root.transitionCoordinator != nil {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
            }
        }
        roster.update(root: nil, make: { _ in fatalError("no window comes while finishing") }, close: { $0.hide() })
        runtime.tree.root?.leave()
        frameClock.stop()
        TestScene.scene.map(environment.stopFollowingTheme(of:))
    }

    /// Every view of `type` in the mounted tree, depth first.
    func views<Native: UIView>(_ type: Native.Type) -> [Native] {
        guard let root = runtime.tree.root else { return [] }
        return Self.views(type, in: root)
    }

    private static func views<Native: UIView>(_ type: Native.Type, in element: MountedElement) -> [Native] {
        let own = ((element.native as? UIKitElement)?.view as? Native).map { [$0] } ?? []
        return own + element.children.flatMap { views(type, in: $0) }
    }
}
