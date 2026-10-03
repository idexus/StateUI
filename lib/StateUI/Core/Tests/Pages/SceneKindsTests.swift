// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

extension WindowType {
    fileprivate static let editor = WindowType("kinds.editor")
    fileprivate static let inspector = WindowType("kinds.inspector")
    fileprivate static let preferences = WindowType("kinds.preferences")
    fileprivate static let fonts = WindowType("kinds.fonts")
    fileprivate static let gone = WindowType("kinds.gone")
}

/// A kind whose main window has no name, with a window beside it.
private struct NotesScene: Scene {
    @State(sceneKey: SceneKey("kinds.shade", of: String.self)) private var shade = "light"

    var body: some Scene {
        WindowGroup { Text("notes \(shade)") }
        Window(.fonts) { Text("fonts") }
    }
}

/// A kind of many sessions, named by its main window.
private struct EditorScene: Scene {
    var body: some Scene {
        WindowGroup(.editor) { Text("editor") }
    }
}

/// A kind of one session: its first window is a `Window`.
private struct InspectorScene: Scene {
    var body: some Scene {
        Window(.inspector) { Text("inspector") }
            .floatsOnTop(true)
    }
}

private struct ThreeKinds: Application {
    var body: some Scene {
        NotesScene()
        EditorScene()
        InspectorScene()
    }
}

private struct InspectorFirst: Application {
    var body: some Scene {
        InspectorScene()
        NotesScene()
    }
}

/// An application whose own body holds a window: one for the whole application.
private struct WithPreferences: Application {
    var body: some Scene {
        WindowGroup { Text("main") }
        Window(.preferences) { Text("preferences") }
    }
}

/// An application with several kinds of scene, each named by its main window.
final class SceneKindsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    override func tearDown() {
        Scenes.shared.reset()
        super.tearDown()
    }

    /// The application `made`, registered, and its tree as the renderer roots it.
    private func registered(_ made: @escaping @autoclosure () -> any Application) {
        Renderer.shared.setApplication(made())
    }

    private func tree() -> Node {
        Scenes.shared.tree(of: Renderer.shared.madeApplication()!)
    }

    private func texts(in patch: HostPatch) -> [String] {
        patch.subtree.filter { $0.type == .text }.compactMap { $0.props[.text]?.string }
    }

    private func refusal(_ call: () async throws -> Void) async -> WindowError? {
        do {
            try await call()
            return nil
        } catch {
            return error as? WindowError
        }
    }

    /// The first kind written opens at launch.
    func testTheFirstKindOpensAtLaunch() {
        registered(InspectorFirst())

        let patch = Renders().render(tree())

        XCTAssertEqual(patch.children.count, 1)
        XCTAssertEqual(texts(in: patch), ["inspector"])
    }

    /// Opening the main window of a kind opens a scene of it - another session each time for a kind of many - its
    /// main window carrying the kind.
    func testOpeningAKindsMainWindowOpensASceneOfIt() async throws {
        registered(ThreeKinds())
        Renders().render(tree())

        try await StandardEnvironment.application.openWindow(.editor)
        try await StandardEnvironment.application.openWindow(.editor)
        let patch = Renders().render(tree())

        XCTAssertEqual(patch.children.map { texts(in: $0) }, [["notes light"], ["editor"], ["editor"]])
        XCTAssertEqual(patch.children[1].children.first?.props[.windowType], .name("kinds.editor"))
        XCTAssertNil(patch.children[0].children.first?.props[.windowType], "the unnamed kind's main window")
    }

    /// File ▸ New opens the kind whose main window has no name, whichever kind is first.
    func testANewSceneIsOfTheUnnamedKind() async throws {
        registered(InspectorFirst())
        Renders().render(tree())

        try await StandardEnvironment.application.openScene()

        XCTAssertEqual(Renders().render(tree()).children.map { texts(in: $0) }, [["inspector"], ["notes light"]])
    }

    /// A kind of one session opens once; a kind no main window names is refused.
    func testAKindOfOneSessionOpensOnceAndAnUndeclaredOneNever() async throws {
        registered(ThreeKinds())
        Renders().render(tree())

        let first = await refusal { try await StandardEnvironment.application.openWindow(.inspector) }
        let second = await refusal { try await StandardEnvironment.application.openWindow(.inspector) }
        let undeclared = await refusal { try await StandardEnvironment.application.openWindow(.gone) }
        let beside = await refusal { try await StandardEnvironment.application.openWindow(.fonts) }

        XCTAssertNil(first)
        XCTAssertEqual(second, .alreadyOpen)
        XCTAssertEqual(undeclared, .undeclared(.gone))
        XCTAssertEqual(beside, .undeclared(.fonts), "a window beside a main one opens through its scene")
        XCTAssertEqual(Scenes.shared.list.count, 2)
    }

    /// A window in the application's body is a scene of one session: one for the whole application, its policies
    /// on its main window.
    func testAWindowInTheApplicationsBodyIsASceneOfOneSession() async throws {
        registered(WithPreferences())
        Renders().render(tree())

        try await StandardEnvironment.application.openWindow(.preferences)
        let again = await refusal { try await StandardEnvironment.application.openWindow(.preferences) }
        let patch = Renders().render(tree())

        XCTAssertEqual(again, .alreadyOpen)
        XCTAssertEqual(patch.children.map { texts(in: $0) }, [["main"], ["preferences"]])
        XCTAssertEqual(patch.children[1].children.map(\.id), [.manual("main")])
    }

    /// The main window of a scene of one session carries its kind and the policies written on it.
    func testAWindowAsTheMainOneCarriesItsKindAndPolicies() async throws {
        registered(ThreeKinds())
        Renders().render(tree())

        try await StandardEnvironment.application.openWindow(.inspector)
        let main = try XCTUnwrap(Renders().render(tree()).children[1].children.first)

        XCTAssertEqual(main.props[.windowType], .name("kinds.inspector"))
        XCTAssertEqual(main.props[.floatsOnTop], .bool(true))
        XCTAssertEqual(main.props[.hidesWhenInactive], .bool(false))
    }

    /// A scene the platform kept comes back as its kind, with its values; one of a kind the application no longer
    /// declares comes back as the unnamed kind, with nothing of what was kept.
    func testAKeptSceneComesBackAsItsKind() {
        registered(ThreeKinds())
        Scenes.shared.connected(restoring: [:], kind: .named(.editor))
        Scenes.shared.connected(restoring: ["kinds.shade": .string("dark")])
        Scenes.shared.connected(restoring: ["kinds.shade": .string("dark")], kind: .named(.gone))

        let patch = Renders().render(tree())

        XCTAssertEqual(patch.children.map { texts(in: $0) }, [["editor"], ["notes dark"], ["notes light"]])
    }

    /// The first window written in a scene with no `WindowGroup` is its main one, the rest beside it; a
    /// `WindowGroup` written after a `Window` is the main one, the window beside it.
    func testTheMainWindowIsTheGroupElseTheFirstWindow() {
        let single = InspectorScene().declaredWindows
        let grouped = NotesScene().declaredWindows

        XCTAssertTrue(single.oneSession)
        XCTAssertEqual(single.main.type, .inspector)
        XCTAssertFalse(grouped.oneSession)
        XCTAssertNil(grouped.main.type)
        XCTAssertEqual(grouped.groups.compactMap(\.type), [.fonts])
    }
}
