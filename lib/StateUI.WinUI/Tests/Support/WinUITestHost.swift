// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

/// The smallest complete application around one page: one scene, one window.
struct OneWindowApplication: Application {
    let page: @Sendable () -> any Page

    var scene: any Scene { OneWindow(content: page) }
}

/// The window of a `OneWindowApplication`, its page built again each time the window is.
struct OneWindow: Window {
    let content: @Sendable () -> any Page

    var page: any Page { content() }
}

/// The test thread as WinUI's: WinUI embedded in it once, since no loop of WinUI's runs a test.
enum WinUITestHost {
    /// Makes the test thread hold WinUI elements, once.
    static func embed() {
        var callbacks = WinUICallbacks.table
        precondition(stateui_winui_embed(&callbacks) == 0, "WinUI could not stand on the test thread")
    }

    /// Runs the thread's messages for `seconds`: a window's first frame, and the layout WinUI asks for.
    static func pump(_ seconds: Double = 0.2) {
        stateui_winui_pump(seconds)
    }
}

extension XCTestCase {
    /// Runs `body` as the main actor's on the test thread, which holds WinUI: a drain makes it MainActor's first.
    func onUIThread(_ body: @MainActor () throws -> Void) rethrows {
        WinUITestHost.embed()
        _ = CoreLink().runJobs()
        try MainActor.assumeIsolated(body)
    }
}

extension WinUIRenderer {
    /// A host showing `page` in a window of its own, laid out; the host before it leaves, and its window closes.
    static func running(_ page: @escaping @Sendable () -> any Page) -> WinUIRenderer {
        shared?.tree.root?.leave()
        shared?.window?.close()

        stateUIUseApp(OneWindowApplication(page: page))
        let renderer = WinUIRenderer()
        shared = renderer
        renderer.show()
        WinUITestHost.pump()
        return renderer
    }

    /// Every view of `type` in the tree, in order.
    func views<Native: WinUIView>(_ type: Native.Type) -> [Native] {
        guard let root = tree.root else { return [] }
        return Self.views(type, in: root)
    }

    private static func views<Native: WinUIView>(_ type: Native.Type, in element: MountedElement) -> [Native] {
        let own = ((element.native as? WinUIElement)?.view as? Native).map { [$0] } ?? []
        return own + element.children.flatMap { views(type, in: $0) }
    }
}

extension WinUIButtonView {
    /// Presses the button as UI Automation does, then lets WinUI lay out what that changed.
    func invoke() {
        stateui_winui_button_invoke(handle)
        WinUITestHost.pump(0.05)
    }
}
