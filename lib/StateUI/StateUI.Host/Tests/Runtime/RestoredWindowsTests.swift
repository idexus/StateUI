// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The windows a platform restores itself, taken by the tree the same way on every host that has one, and the values
/// each scene keeps.
@MainActor
final class RestoredWindowsTests: XCTestCase {
    override func tearDown() async throws {
        OpenScenes.shared.reset()
    }

    /// A record reads back from its text - with values of each kind and words holding a tab - and the same record
    /// writes the same text; a text naming no window is no record.
    func testARecordReadsBackFromItsText() {
        let note = WindowRecord(
            identifier: "n1", kind: "restored.note", value: "7",
            kept: ["open": .bool(true), "draft": .string("a\tb"), "section": .number(2)])
        let window = WindowRecord(identifier: "w1")

        XCTAssertEqual(WindowRecord(note.text), note)
        XCTAssertEqual(WindowRecord(window.text), window)
        XCTAssertEqual(note.text, """
            window\tn1
            kind\trestored.note
            value\t7
            kept\tdraft\tsa\\tb
            kept\topen\tbtrue
            kept\tsection\tn2.0

            """)
        XCTAssertNil(WindowRecord("kind\tnote\n"), "a text naming no window is no record")
    }

    /// The record of a window is what the tree says of it - its kind and its value - with the values its scene keeps.
    func testARecordIsWhatTheTreeSaysOfItsWindow() throws {
        let runtime = HostRuntime.still()
        var scene = HostPatch(id: .manual("1"), type: .scene)
        var note = HostPatch(id: .manual("restored.note 2"), type: .window)
        note.properties = [.windowType: .name("restored.note"), .windowValue: .string("7")]
        scene.children = .arranged([HostPatch(id: .manual("window 1"), type: .window), note])
        runtime.tree.apply(scene, complete: true)
        let windows = try XCTUnwrap(runtime.tree.root?.windows)

        XCTAssertEqual(
            windows.map { WindowRecord(of: $0, identifier: "x", kept: ["section": .number(2)]) },
            [
                WindowRecord(identifier: "x", kept: ["section": .number(2)]),
                WindowRecord(identifier: "x", kind: "restored.note", value: "7", kept: ["section": .number(2)]),
            ])
    }

    /// A window the platform restored comes in as its kind for its value, its scene's values landing where the
    /// scene opens with it - in the core and in the host's - and is the one the window of that kind and value takes;
    /// one of a kind no scene declares is refused - the host closes it.
    func testARestoredWindowComesInAsItsKindAndIsTakenByItsWindow() throws {
        stateUIUseApp(RestoredApplication())
        RestoredApplication.sections = []
        let runtime = HostRuntime.still()
        let restored = RestoredWindows<Shown>()
        var values = SceneValues()
        let (seven, tool, window, eight, about) = (Shown(), Shown(), Shown(), Shown(), Shown())
        let section: [String: HostValue] = ["restored.section": .number(2)]

        for (record, native) in [
            (WindowRecord(identifier: "n7", kind: "restored.note", value: "7", kept: section), seven),
            (WindowRecord(identifier: "t1", kind: "restored.tool", kept: section), tool),
            (WindowRecord(identifier: "n8", kind: "restored.note", value: "8", kept: section), eight),
            (WindowRecord(identifier: "w1", kept: ["restored.section": .number(5)]), window),
            (WindowRecord(identifier: "a1", kind: "restored.about"), about),
        ] {
            XCTAssertTrue(restored.accept(record, native: native, values: &values, in: runtime))
        }
        XCTAssertFalse(restored.accept(
            WindowRecord(identifier: "g1", kind: "restored.gone"), native: Shown(), values: &values, in: runtime))
        runtime.pump.turn()

        let windows = try XCTUnwrap(runtime.tree.root?.windows)
        XCTAssertEqual(windows.map(\.id), [
            .manual("restored.note 1"), .manual("restored.tool 2"), .manual("restored.note 3"), .manual("window 4"),
            .manual("restored.about 1"),
        ])
        let scene = try XCTUnwrap(windows[0].enclosing(type: .scene).map(SceneValues.key(of:)))
        XCTAssertEqual(RestoredApplication.sections.first, 2, "the scene's value, read at its first render")
        XCTAssertEqual(values[scene], section, "the values the scene opened with; a later window's are not its")

        XCTAssertTrue(restored.take(for: windows[2])?.native === eight)
        XCTAssertTrue(restored.take(for: windows[3])?.native === window)
        XCTAssertTrue(restored.take(for: windows[1])?.native === tool)
        XCTAssertTrue(restored.take(for: windows[0])?.native === seven)
        XCTAssertTrue(restored.take(for: windows[4])?.native === about)
        XCTAssertNil(restored.take(for: windows[0]), "taken once")
        XCTAssertTrue(restored.isEmpty)
    }

    /// Turns held for the platform's first window render nothing until it comes, so the scene a window the platform
    /// kept opens is built with what it kept.
    func testTheFirstRenderWaitsForThePlatformsFirstWindow() throws {
        stateUIUseApp(RestoredApplication())
        RestoredApplication.sections = []
        let runtime = HostRuntime.still()
        let restored = RestoredWindows<Shown>()
        var values = SceneValues()
        runtime.pump.waitsForFirstWindow = true

        runtime.pump.turn()
        XCTAssertNil(runtime.tree.root, "nothing rendered before the first window")

        XCTAssertTrue(restored.accept(
            WindowRecord(identifier: "w1", kept: ["restored.section": .number(2)]),
            native: Shown(), values: &values, in: runtime))
        runtime.pump.turn()

        XCTAssertEqual(try XCTUnwrap(runtime.tree.root?.windows).map(\.id), [.manual("window 1")])
        XCTAssertEqual(RestoredApplication.sections, [2], "built once, with what the scene kept")
    }

    /// The values each scene keeps, by the scene's key, as the act `persistSceneValue` carries them - nothing for an
    /// act that is not one - and as a scene opens with a window the platform kept: a scene known keeps its own.
    func testEachSceneKeepsItsValues() {
        var values = SceneValues()

        XCTAssertEqual(values.keep([.name("1"), .name("section"), .number(2)]), "1")
        XCTAssertEqual(values.keep([.name("1"), .name("draft"), .string("a")]), "1")
        XCTAssertEqual(values.keep([.name("2"), .name("section"), .number(5)]), "2")
        XCTAssertNil(values.keep([.name("1"), .name("section")]), "an act of no value")
        values.opened("3", keeping: [:])
        values.opened("3", keeping: ["section": .number(9)])
        values.opened("1", keeping: ["section": .number(9)])

        XCTAssertEqual(values["1"], ["section": .number(2), "draft": .string("a")])
        XCTAssertEqual(values["2"], ["section": .number(5)])
        XCTAssertEqual(values["3"], [:], "it opened keeping nothing")
        XCTAssertEqual(values["4"], [:])

        values.keep(only: ["2"])
        XCTAssertEqual(values["1"], [:], "a scene that ended keeps nothing")
        XCTAssertEqual(values["2"], ["section": .number(5)])
    }
}

/// What a test's window comes in.
private final class Shown {}

/// An application whose scene reads a kept section, opens a note per number and tools, beside an About scene.
private struct RestoredApplication: Application {
    nonisolated(unsafe) static var sections: [Int] = []

    var body: some Scene {
        RestoredScene()
        Window(WindowType("restored.about")) { Text("about") }
    }
}

private struct RestoredScene: Scene {
    var body: some Scene {
        WindowGroup { RestoredSectionPage() }
        WindowGroup(WindowType("restored.note"), for: Int.self) { number in Text("note \(number.wrappedValue)") }
        WindowGroup(WindowType("restored.tool")) { Text("tool") }
    }
}

private struct RestoredSectionPage: View {
    @State(sceneKey: SceneKey("restored.section", of: Int.self)) private var section = 0

    var body: some View {
        RestoredApplication.sections.append(section)
        return Text("section \(section)")
    }
}
