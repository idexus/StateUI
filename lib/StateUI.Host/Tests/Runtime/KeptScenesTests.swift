// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The scenes a host keeps for the application's next start, where the platform restores no windows.
@MainActor
final class KeptScenesTests: XCTestCase {
    /// The text reads back the scenes it was written from - each kind of value, a window with a value and one
    /// without, words holding a tab or a line's end - and the same scenes write the same text, their values by key.
    func testTheTextReadsBackTheScenesItHolds() {
        let scenes = KeptScenes(scenes: [
            KeptScenes.Scene(
                values: ["section": .number(2), "draft": .string("a\tb\nc"), "open": .bool(true)],
                windows: [KeptScenes.Window(kind: "note", value: "7"), KeptScenes.Window(kind: "fonts", value: nil)]),
            KeptScenes.Scene(),
        ])

        XCTAssertEqual(KeptScenes(scenes.text), scenes)
        XCTAssertEqual(scenes.text, """
            scene
            value\tdraft\tsa\\tb\\nc
            value\topen\tbtrue
            value\tsection\tn2.0
            window\tnote\t7
            window\tfonts
            scene

            """)
        XCTAssertEqual(KeptScenes("scene\nsomething\tnew\nvalue\tx\tq1\n").scenes, [KeptScenes.Scene()],
                       "a line that says nothing known is passed over")
        XCTAssertEqual(KeptScenes("").scenes, [])
    }

    /// The scenes a tree holds, each with the values kept for it and its windows of a kind of their own - the main
    /// one is no such window.
    func testTheScenesATreeHoldsAreKeptWithTheirWindows() {
        let runtime = HostRuntime.still()
        var root = HostPatch(id: .manual("application"), type: .application)
        var scene = HostPatch(id: .manual("1"), type: .scene)
        var note = HostPatch(id: .manual("note 1"), type: .window)
        note.properties = [.windowType: .name("note"), .windowValue: .string("7")]
        scene.children = .arranged([HostPatch(id: .manual("main"), type: .window), note])
        root.children = .arranged([scene])
        runtime.tree.apply(root, complete: true)

        XCTAssertEqual(
            KeptScenes(of: runtime.tree.root, values: ["1": ["section": .number(2)], "9": ["gone": .bool(true)]]),
            KeptScenes(scenes: [
                KeptScenes.Scene(values: ["section": .number(2)], windows: [KeptScenes.Window(kind: "note", value: "7")]),
            ]))
    }

    /// A scene kept comes back with its values before its first render, and is offered the windows it had open: the
    /// one it still declares opens for its value, and one it no longer declares is kept no more.
    func testAKeptSceneComesBackWithItsValuesAndWindows() throws {
        stateUIUseApp(KeptApplication())
        KeptApplication.sections = []
        let runtime = HostRuntime.still()
        let keeper = SceneKeeper()
        let kept = KeptScenes(scenes: [
            KeptScenes.Scene(
                values: ["kept.section": .number(2)],
                windows: [KeptScenes.Window(kind: "kept.note", value: "7"), KeptScenes.Window(kind: "gone", value: nil)]),
        ])

        keeper.restore(kept, in: runtime)
        let windows = try XCTUnwrap(runtime.tree.root).windows
        XCTAssertEqual(windows.count, 2, "the note came back; a kind the scene no longer declares did not")
        XCTAssertEqual(windows.last?.value(.windowValue)?.string, "7")
        XCTAssertEqual(KeptApplication.sections.first, 2, "the scene's value, read at its first render")
        XCTAssertEqual(KeptScenes(try XCTUnwrap(keeper.changed(root: runtime.tree.root))), KeptScenes(scenes: [
            KeptScenes.Scene(values: ["kept.section": .number(2)], windows: [KeptScenes.Window(kind: "kept.note", value: "7")]),
        ]))
        XCTAssertNil(keeper.changed(root: runtime.tree.root), "kept already")

        let scene = try XCTUnwrap(KeptScenes.scenes(of: runtime.tree.root).first)
        keeper.keep([.name(KeptScenes.key(of: scene)), .name("kept.section"), .number(3)])
        let text = try XCTUnwrap(keeper.changed(root: runtime.tree.root))
        XCTAssertEqual(KeptScenes(text).scenes.first?.values, ["kept.section": .number(3)])
    }

    /// With nothing kept, the application starts one scene; once no scene stands - the last one ended - nothing is
    /// kept again, so the next start finds the scenes as they stood.
    func testTheLastScenesEndKeepsTheScenesAsTheyStood() throws {
        stateUIUseApp(KeptApplication())
        let runtime = HostRuntime.still()
        let keeper = SceneKeeper()

        keeper.restore(KeptScenes(""), in: runtime)
        XCTAssertEqual(KeptScenes.scenes(of: runtime.tree.root).count, 1)
        XCTAssertNotNil(keeper.changed(root: runtime.tree.root), "the scene that stands is kept")
        XCTAssertNil(keeper.changed(root: nil), "no scene stands")
        XCTAssertNil(keeper.changed(root: runtime.tree.root), "and the scenes kept are the ones that stood")
    }
}

/// An application whose scene reads a kept section, and opens a note's window for a number.
private struct KeptApplication: Application {
    nonisolated(unsafe) static var sections: [Int] = []

    var scene: any Scene { KeptScene() }
}

private struct KeptScene: Scene {
    var windows: Windows {
        Windows({
            WindowGroup(WindowType("kept.note"), for: Int.self) { number in KeptNoteWindow(number: number.wrappedValue) }
        }, main: { KeptMainWindow() })
    }
}

private struct KeptMainWindow: Window {
    var page: any Page { KeptSectionPage() }
}

private struct KeptSectionPage: ContentView {
    @State(sceneKey: SceneKey("kept.section", of: Int.self)) private var section = 0

    var content: any View {
        KeptApplication.sections.append(section)
        return Label("section \(section)")
    }
}

private struct KeptNoteWindow: Window {
    let number: Int

    var page: any Page { Label("note \(number)") }
}
