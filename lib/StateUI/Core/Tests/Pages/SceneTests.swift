// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An application's SCENES - each declared once, standing at most once, its
// windows sharing its state - and what the tree says about them: which scenes
// stand, which windows each has open, what every window is known by, what each
// session is told and does, and what a platform hands over and keeps.

import XCTest
@_spi(Host) @testable import StateUI

private extension WindowType {
    static let fonts = WindowType("fonts")
    static let note = WindowType("note")
    static let document = WindowType("document")
    static let about = WindowType("about")
}

private extension SceneKey {
    static let shade = SceneKey("shade", of: String.self)
}

/// What a scene shares with every window of it.
private final class Palette {
    @State var accent = "violet"
}

/// The scene's accent, as a view reads it.
private struct Accent: View {
    @Environment private var palette: Palette

    var body: some View { Text(palette.accent) }
}

/// A studio window: the scene's accent and the value it keeps, and a button for each thing a test does from inside
/// it - through the application's session, which is in the environment of everything.
private struct Home: View {
    @Environment private var palette: Palette
    @Environment(\.application) private var application
    @Binding var shade: String

    var body: some View {
        VStack {
            Accent()
            Text(shade)
            Button("teal").onClicked { palette.accent = "teal" }
            Button("new").onClicked { try await application.openWindow() }
            Button("fonts").onClicked { try await application.openWindow(.fonts) }
            Button("note").onClicked { try await application.openWindow(.note) }
            Button("document").onClicked { try await application.openWindow(.document, value: 42) }
            Button("about").onClicked { try await application.openWindow(.about) }
            Button("dusk").onClicked { shade = "dusk" }
        }
    }
}

/// A page showing the scene's accent.
private struct Showing: View {
    var body: some View { Accent() }
}

/// A page that says which document its window is for, and makes the window about another.
private struct Retargeting: View {
    @Binding var number: Int

    var body: some View {
        VStack {
            Text("Document \(number)")
            Button("seven").onClicked { number = 7 }
        }
    }
}

/// A page with nothing on it.
private struct Blank: View {
    var body: some View { Text("blank") }
}

/// A studio: its palette and a value it keeps, shared by every window of it - studio windows, one fonts window,
/// notes, and a window per document.
private struct StudioScene: Scene {
    @State private var palette = Palette()
    @State(sceneKey: .shade) private var shade = "light"

    var body: some Scene {
        WindowGroup { Home(shade: $shade) }
            .environment(palette)
        Window(.fonts) { Showing() }
            .hidesWhenInactive(true)
            .floatsOnTop(true)
            .environment(palette)
        WindowGroup(.note) { Showing() }
            .environment(palette)
        WindowGroup(.document, for: Int.self) { $number in Retargeting(number: $number) }
            .environment(palette)
    }
}

/// The studio, and an About window of its own - a scene with no state.
private struct Studio: Application {
    var body: some Scene {
        StudioScene()
        Window(.about) { Blank() }
    }
}

/// An application whose body is one window.
private struct Alone: Application {
    var body: some Scene { WindowGroup { Blank() } }
}

/// An application whose first scene has no unnamed group: launch opens the unnamed group's, wherever it stands.
private struct AboutFirst: Application {
    var body: some Scene {
        Window(.about) { Blank() }
        StudioScene()
    }
}

/// An application with no unnamed group at all: launch opens the first window the first scene declares.
private struct Unnamed: Application {
    var body: some Scene {
        WindowGroup(.note) { Blank() }
        Window(.about) { Blank() }
    }
}

/// A page that says loading is over.
private struct Waiting: View {
    @Binding var loading: Bool

    var body: some View { Button("ready").onClicked { loading = false } }
}

/// A scene whose window is one thing and then another.
private struct Starting: Scene {
    @State private var loading = true

    var body: some Scene {
        WindowGroup {
            if loading {
                Waiting(loading: $loading)
            } else {
                Blank()
            }
        }
    }
}

private struct StartingApp: Application {
    var body: some Scene { Starting() }
}

/// A page counting with state of its own.
private struct Counting: View {
    @State private var opened = 0

    var body: some View {
        VStack {
            Text("\(opened)")
            Button("more").onClicked { opened += 1 }
        }
    }
}

private struct CountingApp: Application {
    var body: some Scene { WindowGroup { Counting() } }
}

/// A page that names its window and sizes it as it comes into the tree, and renames it on a press - through the
/// window's session.
private struct Naming: View {
    @Environment(\.window) private var window

    var body: some View {
        VStack {
            Button("rename").onClicked { window.title = "Renamed" }
        }
        .onCreated {
            window.title = "Named"
            window.width = 640
        }
    }
}

private struct NamingApp: Application {
    var body: some Scene { WindowGroup { Naming() } }
}

/// A page that says how many scenes stand and which windows its own has open.
private struct Listing: View {
    @Environment(\.application) private var application
    @Environment(\.scene) private var scene

    var body: some View {
        VStack {
            Text("\(application.scenes.count) scenes")
            Text(scene.windows.map(\.key).joined(separator: ", "))
        }
    }
}

private struct ListingApp: Application {
    var body: some Scene {
        WindowGroup { Listing() }
        Window(.about) { Blank() }
    }
}

final class SceneTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        start(Studio())
    }

    override func tearDown() {
        OpenScenes.shared.reset()
        super.tearDown()
    }

    /// Registers `application`, as a host's head does: its scenes are what its body declares.
    private func start(_ application: @escaping @autoclosure () -> any Application) {
        Renderer.shared.setApplication(application())
    }

    /// The application's tree, the way `Renderer.root` builds it.
    private func tree() -> Node {
        OpenScenes.shared.tree(of: Renderer.shared.madeApplication()!)
    }

    private var application: ApplicationSession { StandardEnvironment.application }

    /// The scene of number `id`.
    private func scene(_ id: String) throws -> SceneRecord {
        try XCTUnwrap(OpenScenes.shared.list.first { $0.id == id })
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
        let own = patch.type == .text ? [patch.props[.text]?.string].compactMap { $0 } : []
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

    /// The ROOT is the application and its children the scenes that stand; launch opens one window of the
    /// unnamed group, in its scene.
    func testTheApplicationHoldsItsScenesAndASceneItsWindows() {
        let patch = Renders().render(tree())

        XCTAssertEqual(patch.type, .application)
        XCTAssertEqual(patch.children.map(\.type), [.scene])
        XCTAssertEqual(patch.children.map(\.id), [.manual("1")])
        XCTAssertEqual(patch.children[0].children.map(\.type), [.window])
        XCTAssertEqual(patch.children[0].children.map(\.id), [.manual("window 1")])
    }

    /// An application whose body is one window is a scene of that window.
    func testAnApplicationOfOneWindowIsASceneOfIt() {
        start(Alone())
        let patch = Renders().render(tree())

        XCTAssertEqual(patch.children.map(\.type), [.scene])
        XCTAssertEqual(patch.children[0].children.map(\.id), [.manual("window 1")])
        XCTAssertEqual(texts(in: patch.children[0].children[0]), ["blank"])
    }

    /// Launch opens the unnamed group's window wherever its scene stands among the scenes - and, with no unnamed
    /// group, the first window the first scene declares.
    func testLaunchOpensTheUnnamedGroupsWindow() {
        start(AboutFirst())
        XCTAssertEqual(texts(in: Renders().render(tree())), ["violet", "light"])

        start(Unnamed())
        let patch = Renders().render(tree())
        XCTAssertEqual(patch.children[0].children.map(\.id), [.manual("note 1")])
    }

    /// And the render is rooted the same way on the real road.
    func testTheRenderIsRootedInTheApplication() throws {
        start(Alone())

        let dump = PatchDump.text(Renderer.shared.renderHost(baseline: 0).root)
        let lines = dump.split(separator: "\n").map(String.init)

        let application = try XCTUnwrap(lines.firstIndex { $0.contains("Application ") })
        let scene = try XCTUnwrap(lines.firstIndex { $0.contains("Scene ") })
        let window = try XCTUnwrap(lines.firstIndex { $0.contains("Window ") })

        XCTAssertEqual(application, 0, "the root is the application:\n\(dump)")
        XCTAssertLessThan(application, scene, "with a scene under it:\n\(dump)")
        XCTAssertLessThan(scene, window, "and its window under that:\n\(dump)")
    }

    // MARK: - A scene stands once

    /// Every window of a scene SHARES ITS STATE: the palette one window changes is what every other window of the
    /// scene shows.
    func testEveryWindowOfASceneSharesItsState() throws {
        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("new", in: first))))
        let two = renders.renderFromScratch(tree())
        XCTAssertEqual(two.children.map { $0.children.map(\.id) }, [[.manual("window 1"), .manual("window 2")]])

        let second = try XCTUnwrap(two.children.first?.children.last)
        XCTAssertTrue(renders.fire(try XCTUnwrap(button("teal", in: second))))
        let whole = renders.renderFromScratch(tree())

        XCTAssertEqual(whole.children.first?.children.map { texts(in: $0).first }, ["teal", "teal"])
    }

    /// A window opens IN THE SCENE THAT DECLARES IT, which stands once: the studio's fonts and notes open in the
    /// studio, and About opens a scene of its own the first time it is asked for, and none after.
    func testAWindowOpensInTheSceneThatDeclaresIt() async throws {
        Renders().render(tree())

        try await application.openWindow(.fonts)
        try await application.openWindow(.note)
        try await application.openWindow(.about)
        let again = await refusal { try await self.application.openWindow(.about) }

        XCTAssertEqual(again, .alreadyOpen)
        XCTAssertEqual(OpenScenes.shared.list.map(\.id), ["1", "2"])
        XCTAssertEqual(try scene("1").windows.map(\.key), ["window 1", "fonts 2", "note 3"])
        XCTAssertEqual(try scene("2").windows.map(\.key), ["about 1"])
    }

    // MARK: - What the application opens

    /// A `Window` opens once, a window for a value once a value, and a group makes one more each time it is
    /// asked: File ▸ New's unnamed one, and a kind's.
    func testAWindowOpensOnceAndAGroupMakesOneMoreEachTime() async throws {
        Renders().render(tree())

        let fonts = await refusal { try await self.application.openWindow(.fonts) }
        let fontsAgain = await refusal { try await self.application.openWindow(.fonts) }
        let document = await refusal { try await self.application.openWindow(.document, value: 42) }
        let documentAgain = await refusal { try await self.application.openWindow(.document, value: 42) }
        try await application.openWindow(.document, value: 7)
        try await application.openWindow(.note)
        try await application.openWindow(.note)
        try await application.openWindow()

        XCTAssertNil(fonts)
        XCTAssertEqual(fontsAgain, .alreadyOpen)
        XCTAssertNil(document)
        XCTAssertEqual(documentAgain, .alreadyOpen)
        XCTAssertEqual(
            try scene("1").windows.map(\.key),
            ["window 1", "fonts 2", "document 3", "document 4", "note 5", "note 6", "window 7"])
    }

    /// What cannot open is said BY NAME: a kind no scene declares, a value a group is not for, and a window not
    /// open to close.
    func testWhatCannotOpenIsSaidByName() async {
        Renders().render(tree())

        let palette = WindowType("palette")

        let undeclared = await refusal { try await self.application.openWindow(palette) }
        let valueForOne = await refusal { try await self.application.openWindow(.fonts, value: 3) }
        let noValue = await refusal { try await self.application.openWindow(.document) }
        let otherType = await refusal { try await self.application.openWindow(.document, value: "x") }
        let notOpen = await refusal { try await self.application.closeWindow(.fonts) }

        XCTAssertEqual(undeclared, .undeclared(palette))
        XCTAssertEqual(valueForOne, .wrongValue(.fonts))
        XCTAssertEqual(noValue, .wrongValue(.document))
        XCTAssertEqual(otherType, .wrongValue(.document))
        XCTAssertEqual(notOpen, .notOpen)
    }

    /// A phone and a page in a browser open no window beside their own: a second one is refused as unsupported,
    /// while a desktop opens it.
    func testAPhoneOrAPageOpensNoSecondWindow() async {
        Renders().render(tree())
        let was = (StandardEnvironment.device.info.formFactor, StandardEnvironment.device.info.platform)
        defer {
            (StandardEnvironment.device.info.formFactor, StandardEnvironment.device.info.platform) = was
        }

        for (formFactor, platform, refused) in [
            (FormFactor.phone, "iOS", WindowError.unsupported), (.desktop, "Web", .unsupported), (.desktop, "macOS", nil),
        ] {
            StandardEnvironment.device.info.formFactor = formFactor
            StandardEnvironment.device.info.platform = platform
            let refusal = await refusal { try await self.application.openWindow(.note) }
            XCTAssertEqual(refusal, refused, "\(formFactor) on \(platform)")
        }
    }

    // MARK: - A scene ends with its last window

    /// A scene ENDS WITH ITS LAST WINDOW, its state with it: the next window of it opens a fresh scene.
    @MainActor
    func testASceneEndsWithItsLastWindow() async throws {
        let renders = Renders()
        let first = renders.render(tree())
        XCTAssertTrue(renders.fire(try XCTUnwrap(button("teal", in: first))))

        try await application.openWindow(.fonts)
        try await application.closeWindow(.fonts)
        XCTAssertEqual(OpenScenes.shared.list.map(\.id), ["1"], "a window left: the scene stands")

        try await scene("1").windowSession("window 1").close()
        XCTAssertTrue(OpenScenes.shared.list.isEmpty)

        try await application.openWindow()
        let fresh = renders.renderFromScratch(tree())
        XCTAssertEqual(fresh.children.map(\.id), [.manual("2")])
        XCTAssertEqual(texts(in: fresh).first, "violet", "a fresh scene, its state from the start")
    }

    /// A scene's session closes every window of it, ending it - and once it has ended, its sessions and its
    /// windows' answer that they are no open scene's, whoever still holds them.
    func testASceneSessionClosesEveryWindowOfIt() async throws {
        Renders().render(tree())
        try await application.openWindow(.fonts)

        let ending = try scene("1")
        let fonts = ending.windowSession("fonts 2")
        try await ending.session.close()

        XCTAssertTrue(OpenScenes.shared.list.isEmpty)
        let closingOne = await refusal { try await fonts.close() }
        let closingScene = await refusal { try await ending.session.close() }
        XCTAssertEqual(closingOne, .noScene)
        XCTAssertEqual(closingScene, .noScene)
    }

    /// The application lists the scenes that stand and a scene its windows, in opening order, each the very
    /// session the scene or the window holds - and nothing for a scene that has ended.
    func testTheApplicationListsItsScenesAndASceneItsWindows() async throws {
        start(ListingApp())
        Renders().render(tree())

        try await application.openWindow()
        try await application.openWindow(.about)

        let first = try scene("1")
        XCTAssertEqual(application.scenes.map(\.id), ["1", "2"])
        XCTAssertTrue(application.scenes.first === first.session)
        XCTAssertEqual(first.session.windows.map(\.key), ["window 1", "window 2"])
        XCTAssertTrue(first.session.windows.last === first.windowSession("window 2"))

        let ending = try scene("2").session
        try await ending.close()

        XCTAssertEqual(application.scenes.map(\.id), ["1"])
        XCTAssertTrue(ending.windows.isEmpty)
        XCTAssertTrue(SceneSession().windows.isEmpty)
    }

    /// And a view that shows them is built again as a window or a scene opens - the lists being read like any
    /// state - in the window that stood before.
    func testAViewShowingTheListsIsBuiltAgainAsTheyMove() async throws {
        start(ListingApp())
        let renders = Renders()
        XCTAssertEqual(texts(in: renders.render(tree())), ["1 scenes", "window 1"])

        try await application.openWindow()
        let opened = renders.render(tree(), changed: Renderer.shared.pendingChanges)
        let standing = try XCTUnwrap(opened.at(.manual("1"), .manual("window 1")))
        XCTAssertEqual(texts(in: standing), ["window 1, window 2"], "the label that changed, in the window that stood")

        try await application.openWindow(.about)
        let another = renders.render(tree(), changed: Renderer.shared.pendingChanges)
        let first = try XCTUnwrap(another.at(.manual("1"), .manual("window 1")))
        XCTAssertEqual(texts(in: first), ["2 scenes"])
    }

    // MARK: - What a window's session says

    /// A window's session IS what its properties are: written as the window comes into the tree, and again later,
    /// each lands on the window node.
    func testAWindowsSessionIsWhatItsPropertiesAre() throws {
        start(NamingApp())
        let renders = Renders()
        let first = renders.render(tree())

        // `.onCreated` ran after that render, so the next one carries it.
        let named = renders.render(tree(), changed: Renderer.shared.pendingChanges)
        let window = try XCTUnwrap(named.children.first?.children.first)

        XCTAssertEqual(window.props[.title], .string("Named"))
        XCTAssertEqual(window.props[.width], .number(640))

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("rename", in: first))))

        let renamed = renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(renamed.children.first?.children.first?.props[.title], .string("Renamed"))
    }

    /// A window's phase follows the events its platform window raises.
    func testAWindowsPhaseFollowsItsPlatformWindow() throws {
        let renders = Renders()
        let window = try XCTUnwrap(renders.render(tree()).children.first?.children.first)
        let session = try scene("1").windowSession("window 1")

        XCTAssertEqual(session.phase, .created)

        XCTAssertTrue(renders.fire(try XCTUnwrap(window.events?[.activated])))
        XCTAssertEqual(session.phase, .activated)

        XCTAssertTrue(renders.fire(try XCTUnwrap(window.events?[.stopped])))
        XCTAssertEqual(session.phase, .stopped)

        XCTAssertTrue(renders.fire(try XCTUnwrap(window.events?[.resumed])))
        XCTAssertEqual(session.phase, .resumed)
    }

    /// A window's session closes the window it is, and a second close says it is not open.
    func testAWindowsSessionClosesItsWindow() async throws {
        Renders().render(tree())
        try await application.openWindow(.fonts)

        let studio = try scene("1")
        try await studio.windowSession("fonts 2").close()
        XCTAssertEqual(studio.windows.map(\.key), ["window 1"])

        let again = await refusal { try await studio.windowSession("fonts 2").close() }
        XCTAssertEqual(again, .notOpen)
    }

    /// A window's session is the same one for as long as the window is open, and goes with it.
    func testAWindowsSessionLastsAsLongAsItsWindow() async throws {
        let renders = Renders()
        renders.render(tree())

        let studio = try scene("1")
        try await application.openWindow(.fonts)
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        let open = studio.windowSession("fonts 2")
        renders.render(tree())
        XCTAssertTrue(studio.windowSession("fonts 2") === open)

        try await application.closeWindow(.fonts)
        renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertFalse(studio.windowSession("fonts 2") === open)
    }

    /// No application says what its session holds. One declared with a style sheet of its own compiles - a property
    /// is a property - and does NOTHING, which is the one failure this library refuses; so the sources are read for
    /// one, the README and the gallery's listings included.
    func testNoApplicationSaysWhatItsSessionHolds() throws {
        // What an application is told through its session.
        let held: [(kind: String, names: [String])] = [
            ("Application", ["styles", "motion", "persistentKeys"]),
        ]

        var files = [SourceTree.repository.appendingPathComponent("README.md")]

        let apps = SourceTree.repository.appendingPathComponent("apps")

        for path in try SourceTree.files(under: apps, entering: SourceTree.entersSources)
        where path.hasSuffix(".swift") {
            files.append(apps.appendingPathComponent(path))
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
            "an application says what its session holds - write it on the session, in its init:\n" +
            found.joined(separator: "\n"))
    }

    /// The direct members of every type declared a `kind` - `View`, `Application` - as text: what stands one level
    /// inside its braces, nested types left out.
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

    // MARK: - What a window carries

    /// A window for a value is known by its kind and a number of its own, and carries its kind, its value and its
    /// policies as the host writes them down.
    func testAWindowForAValueCarriesItsKindAndItsValue() throws {
        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("document", in: first))))

        let whole = renders.renderFromScratch(tree())
        let document = try XCTUnwrap(whole.children[0].children.last)

        XCTAssertEqual(document.id, .manual("document 2"))
        XCTAssertEqual(document.props[.windowType], .name("document"))
        XCTAssertEqual(document.props[.windowValue], .string("42"))
        XCTAssertEqual(document.props[.hidesWhenInactive], .bool(false))
        XCTAssertEqual(document.props[.floatsOnTop], .bool(false))
        XCTAssertEqual(texts(in: document), ["Document 42"])
    }

    /// A window of the unnamed group carries no kind and no value - only its policies.
    func testAWindowOfTheUnnamedGroupCarriesNoKind() throws {
        let window = try XCTUnwrap(Renders().render(tree()).children[0].children.first)

        XCTAssertNil(window.props[.windowType])
        XCTAssertNil(window.props[.windowValue])
        XCTAssertEqual(window.props[.hidesWhenInactive], .bool(false))
        XCTAssertEqual(window.props[.floatsOnTop], .bool(false))
    }

    /// A window writing its own binding stays THE SAME WINDOW, now about another value - which is also what the
    /// host now writes down.
    func testAWindowWritingItsOwnValueStaysTheSameWindow() throws {
        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("document", in: first))))

        let opened = renders.renderFromScratch(tree())
        XCTAssertTrue(renders.fire(try XCTUnwrap(button("seven", in: opened))))

        let whole = renders.renderFromScratch(tree())
        let document = try XCTUnwrap(whole.children[0].children.last)

        XCTAssertEqual(document.id, .manual("document 2"))
        XCTAssertEqual(document.props[.windowValue], .string("7"))
        XCTAssertEqual(texts(in: document), ["Document 7"])
    }

    /// Closed by value, a window leaves its scene - and a second close says it is not open.
    func testClosingAWindowByItsValue() async throws {
        Renders().render(tree())

        let opened = await refusal { try await self.application.openWindow(.document, value: 42) }
        let closed = await refusal { try await self.application.closeWindow(.document, value: 42) }
        let again = await refusal { try await self.application.closeWindow(.document, value: 42) }

        XCTAssertNil(opened)
        XCTAssertNil(closed)
        XCTAssertEqual(again, .notOpen)
        XCTAssertEqual(try scene("1").windows.map(\.key), ["window 1"])
    }

    /// Whether a window hides while another scene is in front, and whether it floats on top, rides it.
    func testAWindowThatHidesOrFloatsSaysSo() throws {
        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("fonts", in: first))))

        let whole = renders.renderFromScratch(tree())

        XCTAssertEqual(whole.children[0].children.last?.props[.hidesWhenInactive], .bool(true))
        XCTAssertEqual(whole.children[0].children.last?.props[.floatsOnTop], .bool(true))
    }

    // MARK: - What the host reports

    /// The user closing a window takes it out of its scene, by its key - a report about a window already gone
    /// changes nothing - and the last one takes the scene.
    func testTheUserClosingAWindowTakesItOut() throws {
        let renders = Renders()
        let first = renders.render(tree())
        let closed = try XCTUnwrap(first.children[0].events?[.windowClosed])

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("fonts", in: first))))
        XCTAssertEqual(try scene("1").windows.map(\.key), ["window 1", "fonts 2"])

        XCTAssertTrue(renders.fire(closed, with: [.string("fonts 2")]))
        XCTAssertTrue(renders.fire(closed, with: [.string("fonts 2")]))
        XCTAssertEqual(try scene("1").windows.map(\.key), ["window 1"])

        XCTAssertTrue(renders.fire(closed, with: [.string("window 1")]))
        XCTAssertTrue(OpenScenes.shared.list.isEmpty)
    }

    /// A platform window comes in as its kind: the first, with no kind, is the window launch opened; one more with
    /// no kind is another of the unnamed group; a kept one of a kind opens in the scene declaring it, a scene
    /// opening first where none stands; one of a kind no scene declares, or a value that does not read, is refused.
    func testAPlatformWindowComesInAsItsKind() {
        XCTAssertEqual(HostBoundary.connectWindow(), "1")
        XCTAssertEqual(HostBoundary.connectWindow(), "1")
        XCTAssertEqual(HostBoundary.connectWindow(kind: "fonts"), "1")
        XCTAssertEqual(HostBoundary.connectWindow(kind: "document", value: "42"), "1")
        XCTAssertEqual(HostBoundary.connectWindow(kind: "about"), "2")
        XCTAssertNil(HostBoundary.connectWindow(kind: "palette"))
        XCTAssertNil(HostBoundary.connectWindow(kind: "document", value: "not a number"))

        let patch = Renders().render(tree())

        XCTAssertEqual(
            patch.children.map { $0.children.map(\.id) },
            [[.manual("window 1"), .manual("window 2"), .manual("fonts 3"), .manual("document 4")],
             [.manual("about 1")]])
    }

    /// A kept window of another kind coming first takes the place of the window launch opens: what the platform
    /// kept is what stands.
    func testAKeptWindowOfAnotherKindTakesTheLaunchWindowsPlace() {
        XCTAssertNotNil(HostBoundary.connectWindow(kind: "about"))

        let patch = Renders().render(tree())

        XCTAssertEqual(patch.children.map { $0.children.map(\.id) }, [[.manual("about 1")]])
    }

    /// A window refused coming first leaves the launch window waiting, for the platform's next first window to take.
    func testARefusedWindowLeavesTheLaunchWindowWaiting() {
        XCTAssertNil(HostBoundary.connectWindow(kind: "palette"))
        XCTAssertNil(HostBoundary.connectWindow(kind: "document", value: "not a number"))
        XCTAssertEqual(HostBoundary.connectWindow(), "1")

        let patch = Renders().render(tree())

        XCTAssertEqual(patch.children.map { $0.children.map(\.id) }, [[.manual("window 1")]])
    }

    // MARK: - What a scene keeps

    /// A value a scene kept comes back WITH ITS FIRST WINDOW, from the scene's first build; a scene's later
    /// windows find the scene standing.
    func testAValueASceneKeptComesBackWithItsFirstWindow() {
        HostBoundary.connectWindow(restoring: ["shade": .string("dark")])
        HostBoundary.connectWindow(kind: "fonts", restoring: ["shade": .string("ignored")])

        let patch = Renders().render(tree())

        XCTAssertEqual(texts(in: patch.children[0].children[0]).prefix(2), ["violet", "dark"])
    }

    /// A value written is kept FOR THE SCENE IT WAS WRITTEN IN - one act per key, naming the scene.
    func testAValueASceneKeepsIsKeptForThatScene() throws {
        let renders = Renders()
        let first = renders.render(tree())
        _ = OpenScenes.shared.takeSaves()

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("dusk", in: first))))

        let saves = OpenScenes.shared.takeSaves()

        XCTAssertEqual(saves.map(\.act), [.persistSceneValue])
        XCTAssertEqual(saves.first?.arguments, [.name("1"), .name("shade"), .string("dusk")])
    }

    // MARK: - A window and the view it shows

    /// A window may show one thing and then another, and it stays ONE WINDOW - the platform's window keeps standing
    /// while what is in it changes.
    func testAWindowStaysOneWindowWhateverItShows() throws {
        start(StartingApp())
        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertTrue(renders.fire(try XCTUnwrap(button("ready", in: first))))

        let changed = renders.render(tree(), changed: Renderer.shared.pendingChanges)
        XCTAssertFalse(
            changed.subtree.contains { [.scene, .window].contains($0.type) && $0.replace },
            "the window and its scene are not made anew - the platform's window keeps standing")
        XCTAssertTrue(changed.subtree.contains { $0.replace }, "what the window shows is")

        let whole = renders.renderFromScratch(tree())
        XCTAssertEqual(whole.children[0].children.map(\.id), [.manual("window 1")])
        XCTAssertEqual(texts(in: whole.children[0].children[0]), ["blank"])
    }

    /// The view a window shows keeps `@State` of its own across renders, the way a page does.
    func testTheViewAWindowShowsKeepsStateOfItsOwnAcrossRenders() throws {
        start(CountingApp())
        let renders = Renders()
        let first = renders.render(tree())

        XCTAssertEqual(texts(in: first), ["0"])
        XCTAssertTrue(renders.fire(try XCTUnwrap(button("more", in: first))))

        let patch = renders.render(tree(), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(
            texts(in: patch), ["1"],
            "a view whose state was not adopted would have counted from zero again")
    }

    // MARK: - The generation handshake

    /// The head names the GENERATION, and quoting it back is what earns a patch: a caller holding anything else is
    /// sent the whole tree instead.
    func testQuotingTheGenerationEarnsAPatchAndAStaleNumberTheWholeTree() {
        start(Alone())

        let first = Renderer.shared.renderHost(baseline: 0)
        XCTAssertTrue(first.complete, "a caller with no tree is sent the whole of it")

        let patch = Renderer.shared.renderHost(baseline: first.generation)

        XCTAssertFalse(patch.complete, "the generations matched, so a patch is enough")
        XCTAssertEqual(patch.generation, first.generation + 1)

        let resync = Renderer.shared.renderHost(baseline: first.generation)

        XCTAssertTrue(resync.complete, "a stale generation is answered with the whole tree")
    }

    // MARK: - The contract a host reads

    /// Two scenes, every window named on its own session, and then one window closed - what a host applies to a
    /// real application.
    func testTwoScenesAndTheirWindowsAsAHostReadsThem() async throws {
        try await application.openWindow(.fonts)
        try await application.openWindow(.about)

        try scene("1").windowSession("window 1").title = "Studio"
        try scene("1").windowSession("fonts 2").title = "Fonts"
        try scene("2").windowSession("about 1").title = "About"

        let differ = Differ()

        let opened = differ.reconcile(nil, with: tree(), describeAll: true)
        let (studio, fonts, about) = (ElementID.manual("window 1"), ElementID.manual("fonts 2"), ElementID.manual("about 1"))
        let sceneEvents = ["activated", "deactivated", "stopped", "windowClosed"]
        let windowEvents = ["activated", "created", "deactivated", "destroying", "resumed", "stopped"]

        XCTAssertEqual(opened.patch.arrangement, [.manual("1"), .manual("2")])
        XCTAssertEqual(opened.patch.at(.manual("1"))?.arrangement, [studio, fonts])
        XCTAssertEqual(opened.patch.at(.manual("2"))?.arrangement, [about])
        XCTAssertEqual(opened.patch.at(.manual("1"))?.eventNames, sceneEvents)
        XCTAssertEqual(opened.patch.at(.manual("2"))?.eventNames, sceneEvents)

        // Every window named on its own session, its lifetime its own handlers.
        XCTAssertEqual(opened.patch.at(.manual("1"), studio)?.props, [
            "title": .string("Studio"), "floatsOnTop": .bool(false), "hidesWhenInactive": .bool(false),
        ])
        XCTAssertEqual(opened.patch.at(.manual("1"), fonts)?.props, [
            "title": .string("Fonts"), "windowType": .name("fonts"),
            "floatsOnTop": .bool(true), "hidesWhenInactive": .bool(true),
        ])
        XCTAssertEqual(opened.patch.at(.manual("2"), about)?.props, [
            "title": .string("About"), "windowType": .name("about"),
            "floatsOnTop": .bool(false), "hidesWhenInactive": .bool(false),
        ])
        for path in [[.manual("1"), studio], [.manual("1"), fonts], [.manual("2"), about]] as [[ElementID]] {
            XCTAssertEqual(opened.patch.at(path)?.eventNames, windowEvents)
        }

        try await application.closeWindow(.fonts)

        // The window closed: the scene's arrangement without it, and nothing else said.
        let closed = differ.reconcile(
            opened.node, with: tree(), changed: Renderer.shared.pendingChanges).patch
        XCTAssertEqual(closed.at(.manual("1"))?.arrangement, [studio])
        XCTAssertFalse(
            closed.subtree.contains { !$0.props.isEmpty || $0.events != nil },
            "a window leaving is its scene's arrangement alone")
    }
}
