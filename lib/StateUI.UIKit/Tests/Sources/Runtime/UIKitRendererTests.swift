// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
import XCTest

/// A page that counts clicks and greets whoever types a name.
private struct Greeting: ContentView {
    @Environment private var page: PageSession
    @State private var count = 0
    @State private var name = ""

    var content: any View {
        VStack {
            Label(name.isEmpty ? "Hello" : "Hello, \(name)")
            TextField($name).maximumLength(5)
            Button("Clicked \(count)").onClicked { count += 1 }
        }
        .onCreated { page.title = "Greeting" }
    }
}

/// The runtime over UIKit: a window stands in the scene iOS connected, and what the user does there reaches the
/// application.
final class UIKitRendererTests: XCTestCase {
    /// The StateUI window is a window of the scene iOS connected, and the page the user sees names the scene.
    @MainActor
    func testTheWindowStandsInTheSceneItsTitleTheScenes() throws {
        let host = UIKitRenderer.running { Greeting() }
        defer { host.finish() }
        host.settle { TestScene.scene?.title == "Greeting" }

        let window = try XCTUnwrap(host.roster.windows.first?.1.window)
        XCTAssertTrue(window.windowScene === TestScene.scene)
        XCTAssertFalse(window.isHidden)
        XCTAssertEqual(TestScene.scene?.title, "Greeting")
    }

    /// A window the host lets go of leaves the scene, which stays for whatever comes next.
    @MainActor
    func testAFinishedHostLeavesTheSceneAsItFoundIt() throws {
        let host = UIKitRenderer.running { Greeting() }
        let window = try XCTUnwrap(host.roster.windows.first?.1.window)
        host.finish()

        XCTAssertNil(window.windowScene)
        XCTAssertTrue(window.isHidden)
        XCTAssertNotEqual(TestScene.scene?.activationState, .unattached, "the scene stays connected")
    }

    /// A window the tree closes in a host whose windows share its one scene only leaves it: the scene, which would
    /// end the application on an iPad, stays.
    @MainActor
    func testAWindowClosedInASharedSceneLeavesTheSceneStanding() throws {
        let host = UIKitRenderer.running { Greeting() }
        defer { host.finish() }
        let session = try XCTUnwrap(TestScene.scene?.session)
        let (element, controller) = try XCTUnwrap(host.roster.windows.first)

        host.runtime.userClosed(element)
        host.settle { false }

        XCTAssertNil(controller.window?.windowScene, "the window left the scene")
        XCTAssertTrue(UIApplication.shared.openSessions.contains(session), "the scene's session stays open")
        XCTAssertNotEqual(TestScene.scene?.activationState, .unattached, "the scene stays connected")
    }

    /// A host that finished holds on to nothing it showed: its window, its pages' controllers and its views go.
    @MainActor
    func testAFinishedHostLeavesNothingAlive() throws {
        weak var window: UIWindow?
        weak var root: UIViewController?
        weak var field: UIView?
        autoreleasepool {
            let host = UIKitRenderer.running { Greeting() }
            window = host.roster.windows.first?.1.window
            root = window?.rootViewController
            field = host.views(UIKitTextFieldView.self).first
            host.finish()
        }
        let settled = Date(timeIntervalSinceNow: 0.3)
        while Date() < settled { RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02)) }

        XCTAssertNil(window, "the window")
        XCTAssertNil(root, "its root controller")
        XCTAssertNil(field, "a view it showed")
    }

    /// A tap on the button reaches its handler, and the page shows what it counted.
    @MainActor
    func testATapReachesTheButtonsHandler() throws {
        let host = UIKitRenderer.running { Greeting() }
        defer { host.finish() }

        try XCTUnwrap(host.views(UIKitButtonView.self).first).sendActions(for: .primaryActionTriggered)
        host.settle { host.views(UIKitButtonView.self).first?.configuration?.title == "Clicked 1" }

        XCTAssertEqual(host.views(UIKitButtonView.self).first?.configuration?.title, "Clicked 1")
    }

    /// Typed words land on the state the field is bound to, cut to the field's bound.
    @MainActor
    func testTypedWordsLandOnTheBoundStateCutToTheBound() throws {
        let host = UIKitRenderer.running { Greeting() }
        defer { host.finish() }
        let field = try XCTUnwrap(host.views(UIKitTextFieldView.self).first)

        field.text = "Pawel K."
        field.sendActions(for: .editingChanged)
        host.settle { host.views(UIKitLabelView.self).first?.text != "Hello" }

        XCTAssertEqual(field.text, "Pawel")
        XCTAssertEqual(host.views(UIKitLabelView.self).first?.text, "Hello, Pawel")
    }
}
