// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIUIKit
@_spi(Host) import StateUIConformance
import XCTest

/// A page that counts clicks and greets whoever types a name.
private struct Greeting: View {
    @State private var count = 0
    @State private var name = ""

    var body: some View {
        VStack {
            Text(name.isEmpty ? "Hello" : "Hello, \(name)")
            TextField($name).maximumLength(5)
            Button("Clicked \(count)").onClicked { count += 1 }
        }
        .title("Greeting")
    }
}

/// An application whose scene opens with a window of no kind and opens a note's window per number, which reads
/// what the scene keeps.
private struct KeptApplication: Application {
    var body: some Scene { KeptScene() }
}

private struct KeptScene: Scene {
    var body: some Scene {
        WindowGroup { Text("launch") }
        WindowGroup(WindowType("uikit.kept.note"), for: Int.self) { number in KeptNote(number: number.wrappedValue) }
    }
}

private struct KeptNote: View {
    let number: Int
    @State(sceneKey: SceneKey("uikit.section", of: Int.self)) private var section = 0

    var body: some View {
        VStack {
            Text("note \(number), section \(section)")
            Button("Three").onClicked { section = 3 }
        }
    }
}

/// The lines a log was handed.
private final class Logged: @unchecked Sendable {
    private(set) var lines: [String] = []
    func append(_ line: String) { lines.append(line) }
}

/// The runtime over UIKit: a window stands in the scene iOS connected, and what the user does there reaches the
/// application.
@MainActor
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

    /// A window closing in front brings back the one the user was in only where that one stands off the screen, under
    /// it: one standing on the screen beside it stays where and as big as it is - an iPad's windows.
    @MainActor
    func testAWindowClosingBringsBackOnlyOneOffTheScreen() {
        XCTAssertTrue(UIKitRenderer.bringsBack(closing: .foregroundActive, staying: .background), "under it")
        XCTAssertFalse(UIKitRenderer.bringsBack(closing: .foregroundActive, staying: .foregroundInactive), "beside it")
        XCTAssertFalse(UIKitRenderer.bringsBack(closing: .foregroundActive, staying: .foregroundActive), "beside it")
        XCTAssertFalse(UIKitRenderer.bringsBack(closing: .background, staying: .background), "nothing in front closes")
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

    /// Nothing renders before iOS connects the scene the application launches in; the window launch opens then
    /// stands in it, and nothing is asked of iOS - which a phone refuses.
    @MainActor
    func testTheFirstRenderWaitsForTheSceneTheApplicationLaunchesIn() throws {
        let logged = Logged()
        let log = UIKitRenderer.log
        UIKitRenderer.log = HostLog(host: "UIKit") { logged.append($0) }
        defer { UIKitRenderer.log = log }
        stateUIUseApp(OneWindowApplication { Greeting() })
        TestScene.scene?.session.userInfo = nil
        let host = UIKitRenderer(preferences: TestScene.preferences, reducesMotion: { true })
        defer { host.finish() }

        host.runtime.pump.turn()
        XCTAssertTrue(host.roster.windows.isEmpty, "nothing rendered before the scene")
        host.connect(try XCTUnwrap(TestScene.scene))

        XCTAssertEqual(host.roster.windows.count, 1)
        XCTAssertTrue(host.roster.windows.first?.1.window?.windowScene === TestScene.scene)
        XCTAssertEqual(logged.lines, [], "nothing asked of iOS")
    }

    /// A scene iOS kept comes back as the window it kept, in its place of the window launch opens, its StateUI
    /// scene opening with what it kept; as the scene keeps more, the record in the session follows.
    @MainActor
    func testASceneIOSKeptComesBackAsTheWindowItKept() throws {
        let scene = try XCTUnwrap(TestScene.scene)
        stateUIUseApp(KeptApplication())
        let kept = WindowRecord(identifier: "kept", kind: "uikit.kept.note", value: "7", kept: ["uikit.section": .number(2)])
        scene.session.userInfo = [UIKitRenderer.recordKey: kept.text]
        let host = UIKitRenderer(preferences: TestScene.preferences, reducesMotion: { true })
        host.ownsScenes = false
        defer {
            host.finish()
            scene.session.userInfo = nil
        }

        host.connect(scene)

        let (element, controller) = try XCTUnwrap(host.roster.windows.first)
        XCTAssertEqual(host.roster.windows.map(\.0.id), [.manual("uikit.kept.note 1")])
        XCTAssertTrue(controller.window?.windowScene === scene)
        XCTAssertEqual(element.first(type: .text)?.value(.text)?.string, "note 7, section 2")
        XCTAssertEqual(Self.record(in: scene)?.kind, "uikit.kept.note")
        XCTAssertEqual(Self.record(in: scene)?.value, "7")

        host.runtime.pump.dispatch(try XCTUnwrap(element.first(type: .button)?.handler(.clicked)))
        host.settle { Self.record(in: scene)?.kept == ["uikit.section": .number(3)] }
        XCTAssertEqual(Self.record(in: scene)?.kept, ["uikit.section": .number(3)])
    }

    /// A window iOS kept of a kind no scene declares now comes as a new window: iOS connected its scene, and the user
    /// is to see something in it.
    @MainActor
    func testAKeptWindowNoSceneDeclaresComesAsANewWindow() throws {
        let scene = try XCTUnwrap(TestScene.scene)
        stateUIUseApp(KeptApplication())
        scene.session.userInfo = [UIKitRenderer.recordKey: WindowRecord(identifier: "gone", kind: "uikit.gone").text]
        let host = UIKitRenderer(preferences: TestScene.preferences, reducesMotion: { true })
        host.ownsScenes = false
        defer {
            host.finish()
            scene.session.userInfo = nil
        }

        host.connect(scene)

        XCTAssertEqual(host.roster.windows.map(\.0.id), [.manual("window 1")])
        XCTAssertTrue(host.roster.windows.first?.1.window?.windowScene === scene)
        XCTAssertNil(Self.record(in: scene)?.kind)
    }

    /// A scene iOS lets go of in the background and connects again brings its window back - the same StateUI
    /// window, not one more.
    @MainActor
    func testASceneConnectedAgainBringsItsWindowBack() throws {
        let scene = try XCTUnwrap(TestScene.scene)
        let host = UIKitRenderer.running { Greeting() }
        defer { host.finish() }
        let (element, controller) = try XCTUnwrap(host.roster.windows.first)

        host.disconnect(scene)
        XCTAssertNil(controller.window)
        host.connect(scene)

        XCTAssertEqual(host.roster.windows.count, 1)
        XCTAssertTrue(host.roster.windows.first?.0 === element)
        XCTAssertTrue(controller.window?.windowScene === scene)
    }

    /// The record `scene`'s session keeps.
    @MainActor
    private static func record(in scene: UIWindowScene) -> WindowRecord? {
        (scene.session.userInfo?[UIKitRenderer.recordKey] as? String).flatMap(WindowRecord.init)
    }

    /// A picture asked for by no name - a menu entry's with no icon - is none, and nothing is said of it; one the
    /// application does not ship is said.
    @MainActor
    func testNoNameAsksForNoPicture() {
        let logged = Logged()
        let log = UIKitRenderer.log
        UIKitRenderer.log = HostLog(host: "UIKit") { logged.append($0) }
        defer { UIKitRenderer.log = log }

        XCTAssertNil(UIKitRenderer.image(named: ""))
        XCTAssertEqual(logged.lines, [])
        XCTAssertNil(UIKitRenderer.image(named: "nowhere.png"))
        XCTAssertEqual(logged.lines.count, 1)
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
        host.settle { host.views(UIKitTextView.self).first?.text != "Hello" }

        XCTAssertEqual(field.text, "Pawel")
        XCTAssertEqual(host.views(UIKitTextView.self).first?.text, "Hello, Pawel")
    }
}
