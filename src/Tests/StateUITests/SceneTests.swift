// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An application's windows are its SCENES - one per session, each a main
// window and the windows it opens beside it - and this is what the tree says
// about them: which scenes are open, what each has open, what every window is
// known by, what each session is told and does, and what the host writes down
// for the system to restore. What the host does with it is next door, in the
// C# SceneTests.

import StateUIWireProbe
import XCTest
@_spi(Host) @testable import StateUI

private extension WindowType {
    static let fonts = WindowType("fonts")
    static let document = WindowType("document")
}

private extension SceneKey {
    static let shade = SceneKey("shade", of: String.self)
}

/// What a session shares with every window of it.
private final class Palette {
    @State var accent = "violet"
}

/// The session's accent, as a view reads it.
private struct Accent: ContentView {
    @Environment private var palette: Palette

    var content: any View { Label(palette.accent) }
}

/// The session's main page: its accent and the value it keeps, and a button
/// for each thing a test does from inside the scene - through the scene's
/// session, which is in the environment of everything in it.
private struct Home: ContentPage {
    @Environment private var palette: Palette
    @Environment private var scene: SceneSession
    @Binding var shade: String

    var content: any View {
        VStack {
            Accent()
            Label(shade)
            Button("teal").onClicked { palette.accent = "teal" }
            Button("fonts").onClicked { try await scene.openWindow(.fonts) }
            Button("document").onClicked { try await scene.openWindow(.document, value: 42) }
            Button("dusk").onClicked { shade = "dusk" }
        }
    }
}

/// The session's main window.
private struct MainWindow: Window {
    @Binding var shade: String

    var page: any Page { Home(shade: $shade) }
}

/// A page showing the session's accent.
private struct Showing: ContentPage {
    var content: any View { Accent() }
}

/// The one fonts window a session may open.
private struct FontsWindow: Window {
    var page: any Page { Showing() }
}

/// A page that says which document its window is for, and makes the window
/// about another.
private struct Retargeting: ContentPage {
    @Binding var number: Int

    var content: any View {
        VStack {
            Label("Document \(number)")
            Button("seven").onClicked { number = 7 }
        }
    }
}

/// A window per document number.
private struct DocumentWindow: Window {
    @Binding var number: Int

    var page: any Page { Retargeting(number: $number) }
}

/// A session: its own palette, a value it keeps, a group of one and a group
/// per value.
private struct Session: Scene {
    @State private var palette = Palette()
    @State(sceneKey: .shade) private var shade = "light"

    var windows: Windows {
        Windows {
            WindowGroup(.fonts) { FontsWindow() }
                .autoHide(true)
                .floatsOnTop(true)
            WindowGroup(.document, for: Int.self) { $number in DocumentWindow(number: $number) }
        } main: {
            MainWindow(shade: $shade)
        }
        .environment(palette)
    }
}

private struct Studio: Application {
    var scene: any Scene { Session() }
}

/// A page with nothing on it.
private struct Blank: ContentPage {
    var content: any View { Label("blank") }
}

/// A window and nothing else.
private struct PlainWindow: Window {
    var page: any Page { Blank() }
}

/// An application whose scene is a window alone.
private struct Alone: Application {
    var scene: any Scene { PlainWindow() }
}

/// A page that says loading is over.
private struct Waiting: ContentPage {
    @Binding var loading: Bool

    var content: any View { Button("ready").onClicked { loading = false } }
}

/// What shows while a session is getting ready.
private struct LoadingWindow: Window {
    @Binding var loading: Bool

    var page: any Page { Waiting(loading: $loading) }
}

/// A session whose main window is one thing and then another.
private struct Starting: Scene {
    @State private var loading = true

    var windows: Windows {
        Windows {
        } main: {
            if loading {
                LoadingWindow(loading: $loading)
            } else {
                PlainWindow()
            }
        }
    }
}

private struct StartingApp: Application {
    var scene: any Scene { Starting() }
}

/// A page showing what its window counted, and counting one more.
private struct Counting: ContentPage {
    @Binding var opened: Int

    var content: any View {
        VStack {
            Label("\(opened)")
            Button("more").onClicked { opened += 1 }
        }
    }
}

/// A window holding state of its own.
private struct CountingWindow: Window {
    @State private var opened = 0

    var page: any Page { Counting(opened: $opened) }
}

private struct CountingApp: Application {
    var scene: any Scene { CountingWindow() }
}

/// A page that names its window and sizes it as it comes into the tree, and
/// renames it on a press - through the window's session.
private struct Naming: ContentPage {
    @Environment private var window: WindowSession

    var content: any View {
        VStack {
            Button("rename").onClicked { window.title = "Renamed" }
        }
        .onCreated {
            window.title = "Named"
            window.width = 640
        }
    }
}

private struct NamingWindow: Window {
    var page: any Page { Naming() }
}

private struct NamingApp: Application {
    var scene: any Scene { NamingWindow() }
}

/// A page that says how many scenes are open and what its own has open.
private struct Listing: ContentPage {
    @Environment private var application: ApplicationSession
    @Environment private var scene: SceneSession

    var content: any View {
        VStack {
            Label("\(application.scenes.count) scenes")
            Label(scene.windows.map(\.key).joined(separator: ", "))
        }
    }
}

private struct ListingWindow: Window {
    var page: any Page { Listing() }
}

/// A scene whose page counts, with a group of one beside it.
private struct ListingScene: Scene {
    var windows: Windows {
        Windows {
            WindowGroup(.fonts) { PlainWindow() }
        } main: {
            ListingWindow()
        }
    }
}

private struct ListingApp: Application {
    var scene: any Scene { ListingScene() }
}

final class SceneTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Scenes.shared.reset()
        Renderer.shared.clearInvalidation()
    }

    override func tearDown() {
        Scenes.shared.reset()
        super.tearDown()
    }

    /// The application's tree, the way `Renderer.root` builds it.
    private func tree(_ application: Application = Studio()) -> Node {
        Scenes.shared.tree(of: application)
    }

    /// Two scenes, the way the platform hands them over: the first window is
    /// the scene the application started with, the second one more.
    private func twoScenes() {
        Scenes.shared.connected(restoring: [:])
        Scenes.shared.connected(restoring: [:])
    }

    /// The handler of the button with a caption, anywhere under a patch.
    private func button(_ caption: String, in patch: HostPatch) -> Int? {
        if patch.type == .button, patch.props[.text] == .string(caption) {
            return patch.events?[.clicked]
        }

        return patch.children.lazy.compactMap { self.button(caption, in: $0) }.first
    }

    /// Every label's text under a patch, in walk order.
    private func texts(in patch: HostPatch) -> [String] {
        let own = patch.type == .label ? [patch.props[.text]?.string].compactMap { $0 } : []
        return own + patch.children.flatMap { texts(in: $0) }
    }

    /// What a call threw, as a window error - nothing where it did not throw.
    private func refusal(_ call: () async throws -> Void) async -> WindowError? {
        do {
            try await call()
            return nil
        } catch {
            return error as? WindowError
        }
    }

    // MARK: - The shape

    /// The ROOT is the application, its children are its scenes, and a scene's
    /// first child is its main window - one shape, whatever the application
    /// declares.
    func testTheApplicationHoldsItsScenesAndASceneItsWindows() {
        let patch = Renders().render(tree())

        XCTAssertEqual(patch.type, .application)
        XCTAssertEqual(patch.children.map(\.type), [.scene])
        XCTAssertEqual(patch.children.map(\.id), [.manual("1")])
        XCTAssertEqual(patch.children[0].children.map(\.type), [.window])
        XCTAssertEqual(patch.children[0].children.map(\.id), [.manual("main")])
    }

    /// A window alone is a scene of one window - which is what an application
    /// with nothing to open beside its window writes.
    func testAWindowAloneIsASceneOfOneWindow() {
        let patch = Renders().render(tree(Alone()))

        XCTAssertEqual(patch.children.map(\.type), [.scene])
        XCTAssertEqual(patch.children[0].children.map(\.id), [.manual("main")])
        XCTAssertEqual(texts(in: patch.children[0].children[0]), ["blank"])
    }

    /// And the message is rooted the same way on the real road.
    func testTheMessageIsRootedInTheApplication() throws {
        Renderer.shared.setApplication(Alone())

        let dump = WireProbe.dumpMessage(Renderer.shared.renderWire(baseline: 0))
        let lines = dump.split(separator: "\n").map(String.init)

        let application = try XCTUnwrap(lines.firstIndex { $0.contains("Application ") })
        let scene = try XCTUnwrap(lines.firstIndex { $0.contains("Scene ") })
        let window = try XCTUnwrap(lines.firstIndex { $0.contains("Window ") })

        XCTAssertEqual(application, 1, "the root is the application:\n\(dump)")
        XCTAssertLessThan(application, scene, "with a scene under it:\n\(dump)")
        XCTAssertLessThan(scene, window, "and its window under that:\n\(dump)")
    }

    // MARK: - A scene is a session

    /// Every scene has STATE OF ITS OWN: the palette one session changes is
    /// that session's, and the other goes on showing its own.
    func testEverySceneHasStateOfItsOwn() throws {
        twoScenes()

        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("teal", in: first.children[1]))))

        let whole = renders.renderFromScratch(tree())

        XCTAssertEqual(texts(in: whole.children[0]), ["violet", "light"])
        XCTAssertEqual(texts(in: whole.children[1]), ["teal", "light"])
    }

    /// A window OPENS IN THE SCENE WHOSE SESSION OPENED IT, and reads that
    /// scene's context - the one the session offered its windows.
    func testAWindowOpensInTheSceneWhoseSessionOpenedIt() throws {
        twoScenes()

        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("teal", in: first.children[1]))))
        XCTAssertTrue(renders.fire(try XCTUnwrap(button("fonts", in: first.children[1]))))

        let whole = renders.renderFromScratch(tree())

        XCTAssertEqual(whole.children[0].children.map(\.id), [.manual("main")])
        XCTAssertEqual(
            whole.children[1].children.map(\.id), [.manual("main"), .manual("fonts 1")])
        XCTAssertEqual(texts(in: whole.children[1].children[1]), ["teal"])
    }

    // MARK: - What a scene's session says

    /// Opening a window that is open is REFUSED, and says so.
    func testOpeningAWindowThatIsOpenIsRefused() async {
        Renders().render(tree())

        let scene = Scenes.shared.list[0].session
        let first = await refusal { try await scene.openWindow(.fonts) }
        let second = await refusal { try await scene.openWindow(.fonts) }

        XCTAssertNil(first)
        XCTAssertEqual(second, .alreadyOpen)
    }

    /// What the scene cannot open is said BY NAME: a kind it does not declare,
    /// a value the group is not for, a window not open to close, and a session
    /// that is no open scene's at all.
    func testWhatASceneCannotOpenIsSaidByName() async {
        Renders().render(tree())

        let scene = Scenes.shared.list[0].session
        let palette = WindowType("palette")

        let undeclared = await refusal { try await scene.openWindow(palette) }
        let valueForOne = await refusal { try await scene.openWindow(.fonts, value: 3) }
        let noValue = await refusal { try await scene.openWindow(.document) }
        let otherType = await refusal { try await scene.openWindow(.document, value: "x") }
        let notOpen = await refusal { try await scene.closeWindow(.fonts) }

        XCTAssertEqual(undeclared, .undeclared(palette))
        XCTAssertEqual(valueForOne, .wrongValue(.fonts))
        XCTAssertEqual(noValue, .wrongValue(.document))
        XCTAssertEqual(otherType, .wrongValue(.document))
        XCTAssertEqual(notOpen, .notOpen)

        // The session a view outside every scene reads.
        let nowhere = await refusal { try await SceneSession().openWindow(.fonts) }
        XCTAssertEqual(nowhere, .noScene)
    }

    /// Another session is the APPLICATION's to open.
    func testTheApplicationOpensAnotherScene() async throws {
        try await StandardEnvironment.application.openScene()

        XCTAssertEqual(Scenes.shared.list.map(\.id), ["1", "2"])
        XCTAssertEqual(
            Renders().render(tree()).children.map(\.id),
            [.manual("1"), .manual("2")])
    }

    /// A scene's session closes the scene - and once it has ended, the
    /// session answers that it is no open scene's, whoever still holds it.
    func testASceneSessionEndsItsScene() async throws {
        twoScenes()
        Renders().render(tree())

        let ending = Scenes.shared.list[1]

        try await ending.session.openWindow(.fonts)
        try await ending.session.close()

        XCTAssertEqual(Scenes.shared.list.map(\.id), ["1"])

        let after = await refusal { try await ending.session.openWindow(.document, value: 1) }
        XCTAssertEqual(after, .noScene)
    }

    /// A window's session answers that its scene has ended, whoever still
    /// holds the scene - the way the scene's own session does.
    func testAWindowOfAnEndedSceneSaysSo() async throws {
        twoScenes()
        Renders().render(tree())

        let ending = Scenes.shared.list[1]
        try await ending.session.openWindow(.fonts)

        let fonts = ending.windowSession("fonts 1")
        let main = ending.windowSession(SceneElement.mainKey)
        try await ending.session.close()

        let closingOne = await refusal { try await fonts.close() }
        let closingMain = await refusal { try await main.close() }

        XCTAssertEqual(closingOne, .noScene)
        XCTAssertEqual(closingMain, .noScene)
    }

    /// The application lists its scenes' sessions and a scene its windows' -
    /// the main one first - each the very session the scene or the window
    /// holds, and nothing for a scene that has ended.
    func testTheApplicationListsItsScenesAndASceneItsWindows() async throws {
        twoScenes()
        Renders().render(tree(ListingApp()))

        let first = Scenes.shared.list[0]
        try await first.session.openWindow(.fonts)

        XCTAssertEqual(StandardEnvironment.application.scenes.map(\.id), ["1", "2"])
        XCTAssertTrue(StandardEnvironment.application.scenes[0] === first.session)
        XCTAssertEqual(first.session.windows.map(\.key), ["main", "fonts 1"])
        XCTAssertTrue(first.session.windows[1] === first.windowSession("fonts 1"))

        let ending = Scenes.shared.list[1].session
        try await ending.close()

        XCTAssertEqual(StandardEnvironment.application.scenes.map(\.id), ["1"])
        XCTAssertTrue(ending.windows.isEmpty)
        XCTAssertTrue(SceneSession().windows.isEmpty)
    }

    /// And a view that shows them is built again as a window or a scene opens -
    /// the lists being read like any state.
    func testAViewShowingTheListsIsBuiltAgainAsTheyMove() async throws {
        let renders = Renders()
        XCTAssertEqual(texts(in: renders.render(tree(ListingApp()))), ["1 scenes", "main"])

        try await Scenes.shared.list[0].session.openWindow(.fonts)

        let opened = renders.render(
            tree(ListingApp()), changed: Renderer.shared.pendingChanges)
        XCTAssertTrue(texts(in: opened).contains("main, fonts 1"), "\(texts(in: opened))")

        try await StandardEnvironment.application.openScene()

        let another = renders.render(
            tree(ListingApp()), changed: Renderer.shared.pendingChanges)
        XCTAssertTrue(texts(in: another.children[0]).contains("2 scenes"), "\(texts(in: another))")
    }

    // MARK: - What a window's session says

    /// A window's session IS what its properties are: written as the window
    /// comes into the tree, and again later, each lands on the window node.
    func testAWindowsSessionIsWhatItsPropertiesAre() throws {
        let renders = Renders()
        let first = renders.render(tree(NamingApp()))

        // `.onCreated` ran after that render, so the next one carries it.
        let named = renders.render(tree(NamingApp()), changed: Renderer.shared.pendingChanges)
        let window = try XCTUnwrap(named.children.first?.children.first)

        XCTAssertEqual(window.props[.title], .string("Named"))
        XCTAssertEqual(window.props[.width], .number(640))

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("rename", in: first))))

        let renamed = renders.render(tree(NamingApp()), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(renamed.children.first?.children.first?.props[.title], .string("Renamed"))
    }

    /// A window's phase follows the events its platform window raises.
    func testAWindowsPhaseFollowsItsPlatformWindow() throws {
        let renders = Renders()
        let main = try XCTUnwrap(renders.render(tree()).children.first?.children.first)
        let session = Scenes.shared.list[0].windowSession(SceneElement.mainKey)

        XCTAssertEqual(session.phase, .created)

        XCTAssertTrue(renders.fire(try XCTUnwrap(main.events?[.activated])))
        XCTAssertEqual(session.phase, .activated)

        XCTAssertTrue(renders.fire(try XCTUnwrap(main.events?[.stopped])))
        XCTAssertEqual(session.phase, .stopped)

        XCTAssertTrue(renders.fire(try XCTUnwrap(main.events?[.resumed])))
        XCTAssertEqual(session.phase, .resumed)
    }

    /// A window's session closes the window it is - and a main window's, its
    /// scene with it.
    func testAWindowsSessionClosesItsWindow() async throws {
        Renders().render(tree())

        let scene = Scenes.shared.list[0]
        try await scene.session.openWindow(.fonts)

        try await scene.windowSession("fonts 1").close()
        XCTAssertTrue(scene.windows.isEmpty)

        let again = await refusal { try await scene.windowSession("fonts 1").close() }
        XCTAssertEqual(again, .notOpen)

        try await scene.windowSession(SceneElement.mainKey).close()
        XCTAssertTrue(Scenes.shared.list.isEmpty)
    }

    /// A window's session is the same one for as long as the window is open,
    /// and goes with it.
    func testAWindowsSessionLastsAsLongAsItsWindow() async throws {
        let renders = Renders()
        renders.render(tree())

        let scene = Scenes.shared.list[0]
        try await scene.session.openWindow(.fonts)
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        let open = scene.windowSession("fonts 1")
        renders.render(tree())
        XCTAssertTrue(scene.windowSession("fonts 1") === open)

        try await scene.session.closeWindow(.fonts)
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertFalse(scene.windowSession("fonts 1") === open)
    }

    /// No application, window or page says what its session holds. One
    /// declared with a `title`, a size, a style sheet or a lifecycle handler of
    /// its own compiles - a property is a property - and does NOTHING, which is
    /// the one failure this library refuses; so the sources are read for one,
    /// the README and the gallery's listings included.
    func testNoApplicationWindowOrPageSaysWhatItsSessionHolds() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // StateUITests
            .deletingLastPathComponent()    // Tests
            .deletingLastPathComponent()    // src
            .deletingLastPathComponent()    // the repository

        // A page's are read off its session, so a value added there is looked
        // for here the day it arrives.
        let pageSession = try String(
            contentsOf: root.appendingPathComponent("src/StateUI/Sources/Types/PageSession.swift"),
            encoding: .utf8)

        let onPage = pageSession.split(separator: "\n").compactMap { line -> String? in
            guard let declared = line.range(of: "@State public var \\w+", options: .regularExpression)
            else { return nil }

            return line[declared].split(separator: " ").last.map(String.init)
        }

        XCTAssertTrue(onPage.contains("title"), "PageSession's values were not found to look for")

        // What each kind of type is told through its session, by the names it
        // could once answer them under.
        let held: [(kind: String, names: [String])] = [
            ("Application", ["styles", "motion", "persistentKeys", "persistentStorage"]),
            ("Window", [
                "title", "x", "y", "width", "height",
                "minimumWidth", "minimumHeight", "maximumWidth", "maximumHeight",
                "isMaximizable", "isMinimizable", "titleBar", "modalStack", "environment",
                "onCreated", "onActivated", "onDeactivated", "onStopped", "onResumed", "onDestroying",
            ]),
            ("ContentPage", onPage + [
                "onAppearing", "onDisappearing", "onNavigatedTo", "onNavigatingFrom", "onNavigatedFrom",
            ]),
        ]

        var files = [root.appendingPathComponent("README.md")]

        for folder in ["apps", "src"] {
            let walk = FileManager.default.enumerator(
                at: root.appendingPathComponent(folder), includingPropertiesForKeys: nil)

            while let url = walk?.nextObject() as? URL {
                let path = url.path.replacingOccurrences(of: "\\", with: "/")

                if path.contains("/.build/") || path.contains("/bin/") || path.contains("/obj/") {
                    continue
                }

                if url.pathExtension == "swift" || url.pathExtension == "template" {
                    files.append(url)
                }
            }
        }

        var found: [String] = []

        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)

            for (kind, names) in held {
                for body in bodies(of: kind, in: text) {
                    for name in names
                    where body.range(of: "\\bvar \(name)\\s*:", options: .regularExpression) != nil {
                        found.append("\(file.lastPathComponent): \(kind) with var \(name)")
                    }
                }
            }
        }

        XCTAssertTrue(
            found.isEmpty,
            "a type says what its session holds - write it on the session, in " +
            ".onCreated or a handler, or watch its phase:\n" +
            found.joined(separator: "\n"))
    }

    /// The direct members of every type declared a `kind` - `Window`,
    /// `ContentPage`, `Application` - as text: what stands one level inside
    /// its braces, nested types left out.
    private func bodies(of kind: String, in text: String) -> [String] {
        var bodies: [String] = []
        var search = text.startIndex

        while let header = text.range(
            of: "(struct|class)\\s+\\w+\\s*:[^{]*\\{",
            options: .regularExpression,
            range: search..<text.endIndex) {
            search = header.upperBound

            guard text[header].range(of: "[:,]\\s*\(kind)\\s*[,{]", options: .regularExpression) != nil
            else { continue }

            var depth = 1
            var index = header.upperBound
            var direct = ""

            while index < text.endIndex, depth > 0 {
                let character = text[index]

                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                } else if depth == 1 {
                    direct.append(character)
                }

                index = text.index(after: index)
            }

            bodies.append(direct)
        }

        return bodies
    }

    // MARK: - A window per value

    /// A window for a value is known by its kind and a number of its own, and
    /// carries its kind and its value as the host writes them down.
    func testAWindowForAValueCarriesItsKindAndItsValue() throws {
        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("document", in: first))))

        let whole = renders.renderFromScratch(tree())
        let document = try XCTUnwrap(whole.children[0].children.last)

        XCTAssertEqual(document.id, .manual("document 1"))
        XCTAssertEqual(document.props[.windowType], .name("document"))
        XCTAssertEqual(document.props[.windowValue], .string("42"))
        XCTAssertEqual(document.props[.autoHide], .bool(false))
        XCTAssertEqual(document.props[.floatsOnTop], .bool(false))
        XCTAssertEqual(texts(in: document), ["Document 42"])
    }

    /// A window writing its own binding stays THE SAME WINDOW, now about
    /// another value - which is also what the host now writes down.
    func testAWindowWritingItsOwnValueStaysTheSameWindow() throws {
        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("document", in: first))))

        let opened = renders.renderFromScratch(tree())
        XCTAssertTrue(renders.fire(try XCTUnwrap(button("seven", in: opened))))

        let whole = renders.renderFromScratch(tree())
        let document = try XCTUnwrap(whole.children[0].children.last)

        XCTAssertEqual(document.id, .manual("document 1"))
        XCTAssertEqual(document.props[.windowValue], .string("7"))
        XCTAssertEqual(texts(in: document), ["Document 7"])
    }

    /// Closed by value, a window leaves its scene - and a second close says it
    /// is not open.
    func testClosingAWindowByItsValue() async {
        Renders().render(tree())

        let scene = Scenes.shared.list[0].session
        let opened = await refusal { try await scene.openWindow(.document, value: 42) }
        let closed = await refusal { try await scene.closeWindow(.document, value: 42) }
        let again = await refusal { try await scene.closeWindow(.document, value: 42) }

        XCTAssertNil(opened)
        XCTAssertNil(closed)
        XCTAssertEqual(again, .notOpen)
        XCTAssertTrue(Scenes.shared.list[0].windows.isEmpty)
    }

    /// Whether a group's windows hide while another scene is in front, and
    /// whether they float on top, rides each window of it.
    func testAWindowThatHidesOrFloatsSaysSo() throws {
        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("fonts", in: first))))

        let whole = renders.renderFromScratch(tree())

        XCTAssertEqual(whole.children[0].children.last?.props[.autoHide], .bool(true))
        XCTAssertEqual(whole.children[0].children.last?.props[.floatsOnTop], .bool(true))
    }

    // MARK: - What the host reports

    /// The reader closing a window takes it out of its scene, by its key - and
    /// a report about a window already gone changes nothing.
    func testTheReaderClosingAWindowTakesItOut() throws {
        let renders = Renders()
        let first = renders.render(tree())
        let closed = try XCTUnwrap(first.children[0].events?[.windowClosed])

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("fonts", in: first))))
        XCTAssertEqual(Scenes.shared.list[0].windows.map(\.key), ["fonts 1"])

        XCTAssertTrue(renders.fire(closed, with: [.string("fonts 1")]))
        XCTAssertTrue(Scenes.shared.list[0].windows.isEmpty)

        XCTAssertTrue(renders.fire(closed, with: [.string("fonts 1")]))
        XCTAssertTrue(Scenes.shared.list[0].windows.isEmpty)
    }

    /// The system restoring a window at launch puts it back - once, and only
    /// where the scene declares its kind and its text reads as the value.
    func testTheSystemRestoringAWindowPutsItBack() throws {
        let renders = Renders()
        let restored = try XCTUnwrap(renders.render(tree()).children[0].events?[.windowRestored])

        renders.fire(restored, with: [.string("document"), .string("42")])
        renders.fire(restored, with: [.string("document"), .string("42")])
        renders.fire(restored, with: [.string("fonts")])
        renders.fire(restored, with: [.string("palette")])
        renders.fire(restored, with: [.string("document"), .string("not a number")])

        XCTAssertEqual(Scenes.shared.list[0].windows.map(\.key), ["document 1", "fonts 2"])
        XCTAssertEqual(Scenes.shared.list[0].windows.first?.value, AnyHashable(42))
    }

    /// A scene's main window going ends the scene, and every window beside it
    /// with it.
    func testTheMainWindowGoingEndsItsScene() throws {
        twoScenes()

        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(first.children[1].events?[.destroying])))
        XCTAssertEqual(Scenes.shared.list.map(\.id), ["1"])
    }

    /// The platform's first window is the scene the application started
    /// with; every one after it is a scene more.
    func testThePlatformsFirstWindowIsTheSceneTheApplicationStartedWith() {
        Scenes.shared.connected(restoring: [:])
        XCTAssertEqual(Scenes.shared.list.map(\.id), ["1"])

        Scenes.shared.connected(restoring: [:])
        XCTAssertEqual(Scenes.shared.list.map(\.id), ["1", "2"])
    }

    // MARK: - What a scene keeps

    /// A value a scene kept comes back WITH IT, from the scene's first build -
    /// and a scene that kept nothing starts from the value written beside the
    /// state.
    func testAValueASceneKeptComesBackWithIt() {
        Scenes.shared.connected(restoring: ["shade": .string("dark")])
        Scenes.shared.connected(restoring: [:])

        let patch = Renders().render(tree())

        XCTAssertEqual(texts(in: patch.children[0]), ["violet", "dark"])
        XCTAssertEqual(texts(in: patch.children[1]), ["violet", "light"])
    }

    /// A value written is kept FOR THE SCENE IT WAS WRITTEN IN - one act per
    /// key, naming the scene.
    func testAValueASceneKeepsIsKeptForThatScene() throws {
        twoScenes()

        let renders = Renders()
        let first = renders.render(tree())
        _ = Scenes.shared.takeSaves()

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("dusk", in: first.children[1]))))

        let saves = Scenes.shared.takeSaves()

        XCTAssertEqual(saves.map(\.act), [.persistSceneValue])
        XCTAssertEqual(saves.first?.arguments, [.name("2"), .name("shade"), .string("dusk")])
    }

    // MARK: - The main window

    /// The main window may be one thing and then another, and it stays ONE
    /// WINDOW - the platform's window keeps standing while what is in it
    /// changes.
    func testTheMainWindowStaysOneWindowWhateverItIsWrittenAs() throws {
        let renders = Renders()
        let first = renders.render(tree(StartingApp()))

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("ready", in: first))))

        let whole = renders.renderFromScratch(tree(StartingApp()))

        XCTAssertEqual(whole.children[0].children.map(\.id), [.manual("main")])
        XCTAssertEqual(texts(in: whole.children[0].children[0]), ["blank"])
    }

    /// A window declared as a type keeps `@State` of its own across renders,
    /// the way a page does.
    func testAWindowKeepsStateOfItsOwnAcrossRenders() throws {
        let renders = Renders()
        let first = renders.render(tree(CountingApp()))

        XCTAssertEqual(texts(in: first), ["0"])
        XCTAssertTrue(renders.fire(try XCTUnwrap(button("more", in: first))))

        let patch = renders.render(tree(CountingApp()), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(
            texts(in: patch), ["1"],
            "a window whose state was not adopted would have counted from zero again")
    }

    // MARK: - The generation handshake

    /// The head names the GENERATION, and quoting it back is what earns a
    /// patch: a caller holding anything else is sent the whole tree instead.
    func testQuotingTheGenerationEarnsAPatchAndAStaleNumberTheWholeTree() {
        Renderer.shared.setApplication(Alone())

        let first = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))
        XCTAssertTrue(first.complete, "a caller with no tree is sent the whole of it")

        let patch = WireProbe.decodeMessage(
            Renderer.shared.renderWire(baseline: Int32(first.generation)))

        XCTAssertFalse(patch.complete, "the generations matched, so a patch is enough")
        XCTAssertEqual(patch.generation, first.generation + 1)

        let resync = WireProbe.decodeMessage(
            Renderer.shared.renderWire(baseline: Int32(first.generation)))

        XCTAssertTrue(resync.complete, "a stale generation is answered with the whole tree")
    }

    // MARK: - The contract the C# side reads

    /// Two scenes, the first with a window beside its main one, every window
    /// named on its own session, and then that window closed - written down
    /// for the C# side to apply to a real application.
    func testTheScenesAreWrittenDown() throws {
        twoScenes()
        Scenes.shared.list[0].windows = [OpenedWindow(type: .fonts, serial: 1, value: nil, text: nil)]

        Scenes.shared.list[0].windowSession(SceneElement.mainKey).title = "Studio"
        Scenes.shared.list[0].windowSession("fonts 1").title = "Fonts"
        Scenes.shared.list[1].windowSession(SceneElement.mainKey).title = "Studio 2"

        let differ = Differ()
        let dictionary = WireDictionary()
        let names = WireNames()

        let opened = differ.reconcile(nil, with: tree(), describeAll: true)
        let first = Wire.encode(opened.patch, generation: 1, complete: true, dictionary: dictionary)

        try Fixtures.check(
            first,
            sidecar: WireProbe.dumpMessage(first, names: names),
            against: "scenes/1-opens")

        Scenes.shared.list[0].windows = []

        let closed = differ.reconcile(
            opened.node, with: tree(), changed: Renderer.shared.pendingChanges)
        let second = Wire.encode(closed.patch, generation: 2, dictionary: dictionary)

        try Fixtures.check(
            second,
            sidecar: WireProbe.dumpMessage(second, names: names),
            against: "scenes/2-closes")
    }
}
