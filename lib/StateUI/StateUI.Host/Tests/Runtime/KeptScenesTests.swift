// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The scenes a host keeps for the application's next start, where the platform restores no windows.
@MainActor
final class KeptScenesTests: XCTestCase {
    override func tearDown() async throws {
        OpenScenes.shared.reset()
    }

    /// The text reads back the scenes it was written from - each kind of value, a window of the group with no name,
    /// one of a kind with a value and one without, words holding a tab or a line's end - and the same scenes write the
    /// same text, their values by key.
    func testTheTextReadsBackTheScenesItHolds() {
        let scenes = KeptScenes(scenes: [
            KeptScenes.Scene(
                values: ["section": .number(2), "draft": .string("a\tb\nc"), "open": .bool(true)],
                windows: [
                    KeptScenes.Window(kind: nil, value: nil), KeptScenes.Window(kind: "note", value: "7"),
                    KeptScenes.Window(kind: "fonts", value: nil),
                ]),
            KeptScenes.Scene(windows: [KeptScenes.Window(kind: "about", value: nil)]),
        ])

        XCTAssertEqual(KeptScenes(scenes.text), scenes)
        XCTAssertEqual(scenes.text, """
            scene
            value\tdraft\tsa\\tb\\nc
            value\topen\tbtrue
            value\tsection\tn2.0
            window
            window\tnote\t7
            window\tfonts
            scene
            window\tabout

            """)
        XCTAssertEqual(KeptScenes("scene\nsomething\tnew\nvalue\tx\tq1\n").scenes, [KeptScenes.Scene()],
                       "a line that says nothing known is passed over")
        XCTAssertEqual(KeptScenes("").scenes, [])
    }

    /// The scenes a tree holds, each with the values kept for it and every window of it, by its kind and its value.
    func testTheScenesATreeHoldsAreKeptWithTheirWindows() {
        let runtime = HostRuntime.still()
        var root = HostPatch(id: .manual("application"), type: .application)
        var scene = HostPatch(id: .manual("1"), type: .scene)
        var note = HostPatch(id: .manual("note 2"), type: .window)
        note.properties = [.windowType: .name("note"), .windowValue: .string("7")]
        scene.children = .arranged([HostPatch(id: .manual("window 1"), type: .window), note])
        var about = HostPatch(id: .manual("2"), type: .scene)
        var aboutWindow = HostPatch(id: .manual("about 1"), type: .window)
        aboutWindow.properties = [.windowType: .name("about")]
        about.children = .arranged([aboutWindow])
        root.children = .arranged([scene, about])
        runtime.tree.apply(root, complete: true)

        var values = SceneValues()
        values.keep([.name("1"), .name("section"), .number(2)])
        values.keep([.name("9"), .name("gone"), .bool(true)])

        XCTAssertEqual(
            KeptScenes(of: runtime.tree.root, values: values),
            KeptScenes(scenes: [
                KeptScenes.Scene(
                    values: ["section": .number(2)],
                    windows: [KeptScenes.Window(kind: nil, value: nil), KeptScenes.Window(kind: "note", value: "7")]),
                KeptScenes.Scene(windows: [KeptScenes.Window(kind: "about", value: nil)]),
            ]))
    }

    /// A scene kept comes back with its windows, each connected as its kind for its value, the scene's values landing
    /// before its first render; a window of a kind no scene declares is kept no more.
    func testAKeptSceneComesBackWithItsValuesAndWindows() throws {
        stateUIUseApp(KeptApplication())
        KeptApplication.sections = []
        let runtime = HostRuntime.still()
        let keeper = SceneKeeper()
        let kept = KeptScenes(scenes: [
            KeptScenes.Scene(
                values: ["kept.section": .number(2)],
                windows: [
                    KeptScenes.Window(kind: nil, value: nil), KeptScenes.Window(kind: "kept.note", value: "7"),
                    KeptScenes.Window(kind: "gone", value: nil),
                ]),
            KeptScenes.Scene(windows: [KeptScenes.Window(kind: "kept.about", value: nil)]),
        ])

        keeper.restore(kept, in: runtime)
        let scenes = SceneValues.scenes(of: runtime.tree.root)
        XCTAssertEqual(scenes.map { $0.windows.map(\.id) }, [
            [.manual("window 1"), .manual("kept.note 2")], [.manual("kept.about 1")],
        ], "the windows came back; a kind no scene declares did not")
        XCTAssertEqual(KeptApplication.sections.first, 2, "the scene's value, read at its first render")
        XCTAssertEqual(KeptScenes(try XCTUnwrap(keeper.changed(root: runtime.tree.root))), KeptScenes(scenes: [
            KeptScenes.Scene(
                values: ["kept.section": .number(2)],
                windows: [KeptScenes.Window(kind: nil, value: nil), KeptScenes.Window(kind: "kept.note", value: "7")]),
            KeptScenes.Scene(windows: [KeptScenes.Window(kind: "kept.about", value: nil)]),
        ]))
        XCTAssertNil(keeper.changed(root: runtime.tree.root), "kept already")

        let scene = try XCTUnwrap(scenes.first)
        keeper.keep([.name(SceneValues.key(of: scene)), .name("kept.section"), .number(3)])
        let text = try XCTUnwrap(keeper.changed(root: runtime.tree.root))
        XCTAssertEqual(KeptScenes(text).scenes.first?.values, ["kept.section": .number(3)])
    }

    /// With nothing kept, the window launch opens comes as the platform's first, so the next new window is one more;
    /// once no scene stands - the last one ended - nothing is kept again, so the next start finds the scenes as they
    /// stood.
    func testTheLastScenesEndKeepsTheScenesAsTheyStood() throws {
        stateUIUseApp(KeptApplication())
        let runtime = HostRuntime.still()
        let keeper = SceneKeeper()

        keeper.restore(KeptScenes(""), in: runtime)
        XCTAssertEqual(SceneValues.scenes(of: runtime.tree.root).map { $0.windows.map(\.id) }, [[.manual("window 1")]])
        runtime.connectWindow()
        runtime.pump.turn()
        XCTAssertEqual(
            SceneValues.scenes(of: runtime.tree.root).map { $0.windows.map(\.id) },
            [[.manual("window 1"), .manual("window 2")]], "a new window is one more")
        XCTAssertNotNil(keeper.changed(root: runtime.tree.root), "the scene that stands is kept")
        XCTAssertNil(keeper.changed(root: nil), "no scene stands")
        XCTAssertNil(keeper.changed(root: runtime.tree.root), "and the scenes kept are the ones that stood")
    }
}

/// An application whose scene reads a kept section and opens a note's window for a number, beside an About scene.
private struct KeptApplication: Application {
    nonisolated(unsafe) static var sections: [Int] = []

    var body: some Scene {
        KeptScene()
        Window(WindowType("kept.about")) { Text("about") }
    }
}

private struct KeptScene: Scene {
    var body: some Scene {
        WindowGroup { KeptSectionPage() }
        WindowGroup(WindowType("kept.note"), for: Int.self) { number in Text("note \(number.wrappedValue)") }
    }
}

private struct KeptSectionPage: View {
    @State(sceneKey: SceneKey("kept.section", of: Int.self)) private var section = 0

    var body: some View {
        KeptApplication.sections.append(section)
        return Text("section \(section)")
    }
}
