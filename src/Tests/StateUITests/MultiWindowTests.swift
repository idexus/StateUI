// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Several windows, which is an ARRANGED LIST on the application.
//
// The root of every message is the Application, and its children are the
// windows - one for most applications, several for a desktop one. Opening a
// window is an append to the author's own state and closing it is a removal,
// the same protocol a navigation stack and a modal stack follow; what the
// AUTHOR owns here, and nothing else does, is identity (`.id()`) and folding a
// window the reader closed back into state (`onDestroying`).
//
// What the host does with the list - opens, closes, and never reopens what the
// platform took away - is next door, in the C# MultiWindowTests.

import Foundation
import StateUIWireProbe
import XCTest
@testable import StateUI

/// The window every application here opens with.
private struct MainWindow: Window {
    var id: AnyHashable?
    var title: String?

    var content: Page { MainPage() }
}

/// A window made from a VALUE - an inspector, a document, a workspace. The
/// three things that are the author's are all here: an id, an `onDestroying`
/// that folds the window back into the list, and whatever the window lends the
/// pages inside it.
private struct NamedWindow: Window {
    let name: String

    var id: AnyHashable?
    var environment: [AnyObject] = []

    /// Takes the window's own name out of the state that opened it.
    var close: ((String) -> Void)?

    var title: String? { name }
    var onDestroying: EventHandler? { close.map { close in { close(name) } } }

    var content: Page { InspectorPage(name: name) }
}

/// One window whose PAGE changes - a splash while something loads, then the
/// thing itself. The window never moves; only what is in it does.
private struct StudioWindow: Window {
    let ready: Bool

    var onCreated: EventHandler?

    var title: String? { "Studio" }

    var content: Page {
        if ready { return InspectorPage(name: "ready") }
        return MainPage()
    }
}

/// What an application with one window says, which is what every application
/// written before this said.
private struct SingleApp: Application {
    func createWindow() -> Window { MainWindow(title: "Main") }
}

/// An application the PLATFORM may ask for a window: the reader's *File ▸ New
/// Window* becomes one more document, exactly as a button in the interface
/// would have made one.
private struct AskedApp: Application {
    let documents: Binding<[String]>

    func createWindow() -> Window { MainWindow(title: "Main") }

    var onCreatingWindow: EventHandler? {
        {
            documents.wrappedValue.append("Untitled \(documents.wrappedValue.count + 1)")
        }
    }

    var windows: [Window] {
        [createWindow()] + documents.wrappedValue.map { name in
            NamedWindow(
                name: name,
                id: name,
                close: { gone in documents.wrappedValue.removeAll { $0 == gone } })
        }
    }
}

/// An application that is ASKED and says no - a document application that
/// will not open a second window while one is unsaved, say. It answers the
/// platform by describing the windows it already has.
private struct QuietApp: Application {
    let documents: Binding<[String]>

    func createWindow() -> Window { MainWindow(title: "Main") }

    var onCreatingWindow: EventHandler? {
        { /* Not now. */ }
    }

    var windows: [Window] {
        [createWindow()] + documents.wrappedValue.map { MainWindow(title: $0) }
    }
}

/// The pattern a document application opens with: a LAUNCHER, and one
/// workspace window per document that was chosen from it.
///
/// Two KINDS of window in one list - which is the question this answers, since
/// nothing in the library says a window list is homogeneous. Choosing a project
/// is one assignment: the launcher stops being described and the workspace
/// starts, in the same render. `File ▸ New Window` brings the launcher back.
private struct StudioApp: Application {
    let open: Binding<[String]>
    let picking: Binding<Bool>

    /// The context each workspace window seeds for every page inside it, so a
    /// page reads its project by TYPE rather than through initializers.
    let contexts: [String: Workspace]

    func createWindow() -> Window { MainWindow(title: "Start") }

    var onCreatingWindow: EventHandler? {
        { picking.wrappedValue = true }
    }

    var windows: [Window] {
        let launcher = picking.wrappedValue
            ? [MainWindow(id: "launcher", title: "Start")]
            : []

        return launcher + open.wrappedValue.map { project in
            NamedWindow(
                name: project,
                id: "project-\(project)",
                environment: [contexts[project]!],
                close: { gone in open.wrappedValue.removeAll { $0 == gone } })
        }
    }
}

/// What a workspace window lends every page in it.
private final class Workspace {
    let project: String

    init(project: String) {
        self.project = project
    }
}

/// A desktop application: one window that is always there, and one per
/// inspector the author's state holds.
private struct InspectorApp: Application {
    let inspectors: Binding<[String]>

    func createWindow() -> Window { MainWindow(title: "Main") }

    var windows: [Window] {
        [createWindow()] + inspectors.wrappedValue.map { name in
            NamedWindow(
                name: name,
                id: name,
                close: { gone in inspectors.wrappedValue.removeAll { $0 == gone } })
        }
    }
}

/// An application whose windows are ALL its documents - so closing the last
/// one leaves it describing none, which a Mac allows and a phone never sees.
private struct DocumentApp: Application {
    let documents: Binding<[String]>

    func createWindow() -> Window { MainWindow() }

    var windows: [Window] {
        documents.wrappedValue.map { NamedWindow(name: $0, id: $0) }
    }
}

private struct MainPage: ContentPage {
    var content: Element { label("main") }
}

private struct InspectorPage: ContentPage {
    let name: String

    var title: String? { name }
    var content: Element { label(name) }
}

final class MultiWindowTests: XCTestCase {
    /// The application node with whatever windows an application describes,
    /// built the way `Renderer.root` builds it.
    private func tree(_ application: Application) -> Node {
        var node = Node(type: .application, children: application.windows.map(\.body))

        if let creating = application.onCreatingWindow {
            node.addHandler(.creatingWindow, creating)
        }

        return node
    }

    // MARK: - The shape

    /// An application that says nothing about windows has the one it always
    /// had - and the message is rooted in the APPLICATION either way, so the
    /// host reads one shape whether there is one window or six.
    func testAnApplicationWithOneWindowIsRootedInTheApplication() throws {
        Renderer.shared.setApplication(SingleApp())

        let dump = WireProbe.dumpMessage(Renderer.shared.renderWire(baseline: 0))
        let lines = dump.split(separator: "\n").map(String.init)

        XCTAssertTrue(lines[1].hasPrefix("Application "), "the root is the application: \(lines[1])")
        XCTAssertTrue(lines[2].contains("Window "), "with the window under it: \(lines[2])")
        XCTAssertTrue(dump.contains("title: string \"Main\""))
    }

    /// The windows are the application's children, in the order it lists them.
    func testEveryWindowDescribedIsAChildInOrder() throws {
        let inspectors = State<[String]>(["colours", "layers"])
        let node = tree(InspectorApp(inspectors: inspectors.projectedValue)).built

        XCTAssertEqual(node.type, "Application")
        XCTAssertEqual(node.children.map { $0.props["title"] }, [
            .string("Main"), .string("colours"), .string("layers"),
        ])
    }

    /// An application may end up describing NO window - a document application
    /// whose last document was closed - and it says so with an arranged list
    /// that is empty, which is what closes the last window rather than this
    /// side inventing one to keep.
    func testAnApplicationCanEndUpDescribingNoWindowAtAll() {
        let documents = State<[String]>(["notes"])
        let renders = Renders()
        let application = DocumentApp(documents: documents.projectedValue)

        renders.render(tree(application))

        documents.wrappedValue = []
        let patch = renders.render(tree(application))

        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(patch.children.count, 0)
    }

    /// A window built from a value carries that value as its identity, which
    /// is what `ForEach` does for a row and what the host matches on.
    func testAWindowIsIdentifiedByTheValueItStandsFor() {
        let inspectors = State<[String]>(["colours"])
        let patch = Renders().render(tree(InspectorApp(inspectors: inspectors.projectedValue)))

        XCTAssertEqual(patch.children.map(\.id), [.auto(2), .manual("colours")])
    }

    // MARK: - The generation handshake

    /// The head names the GENERATION, and quoting it back is what earns a
    /// patch: a caller holding anything else - a first render, a host that
    /// failed halfway through applying the last message - is sent the whole
    /// tree instead. Both answers say which they are in the head, so the two
    /// sides cannot drift apart silently.
    func testQuotingTheGenerationEarnsAPatchAndAStaleNumberTheWholeTree() {
        Renderer.shared.setApplication(SingleApp())

        // A baseline of 0 says "I hold nothing". The very first render agrees
        // at zero and is complete all the same - there is nothing to have
        // changed since.
        let first = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))
        XCTAssertTrue(first.complete, "a caller with no tree is sent the whole of it")

        let patch = WireProbe.decodeMessage(
            Renderer.shared.renderWire(baseline: Int32(first.generation)))

        XCTAssertFalse(patch.complete, "the generations matched, so a patch is enough")
        XCTAssertEqual(
            patch.generation, first.generation + 1,
            "every render advances the generation the next caller must quote")

        // The number the first reply announced is stale now - what a host that
        // failed halfway through an apply is left holding.
        let resync = WireProbe.decodeMessage(
            Renderer.shared.renderWire(baseline: Int32(first.generation)))

        XCTAssertTrue(resync.complete, "a stale generation is answered with the whole tree")
    }

    // MARK: - Opening and closing

    /// Closing the MIDDLE window closes that one: the survivors keep their
    /// identities, so the last window's page is not moved into the one that
    /// went. This is what `.id()` buys, and the reason it is not optional.
    func testClosingTheMiddleWindowLeavesTheOthersWhereTheyWere() throws {
        let inspectors = State<[String]>(["colours", "layers"])
        let renders = Renders()
        let application = InspectorApp(inspectors: inspectors.projectedValue)

        renders.render(tree(application))

        inspectors.wrappedValue = ["layers"]
        let patch = renders.render(tree(application))

        XCTAssertTrue(patch.arranged, "the list is described because it changed")
        XCTAssertEqual(patch.children.map(\.id), [.auto(2), .manual("layers")])

        // The survivor rides along as a stub: it is where it was, and nothing
        // about it changed.
        XCTAssertTrue(try XCTUnwrap(patch.children.last).isEmpty)
    }

    /// A window whose OWN content changed is the only one the message speaks
    /// about - a second window is not redescribed because the first moved.
    func testAMessageAboutOneWindowNamesOnlyThatWindow() throws {
        let inspectors = State<[String]>(["colours"])
        let renders = Renders()
        let application = InspectorApp(inspectors: inspectors.projectedValue)

        renders.render(tree(application))

        inspectors.wrappedValue = ["layers"]
        let patch = renders.render(tree(application))

        // The main window is untouched; the inspector is a different one.
        XCTAssertEqual(patch.children.map(\.id), [.auto(2), .manual("layers")])
        XCTAssertTrue(try XCTUnwrap(patch.children.first).isEmpty)
        XCTAssertFalse(try XCTUnwrap(patch.children.last).isEmpty)
    }

    // MARK: - What the reader closed

    /// The report is the window's own `destroying`, and the author's handler is
    /// what folds it back: the next render describes one window fewer, which is
    /// what tells the host the window is meant to be gone.
    func testDestroyingFoldsTheWindowBackIntoTheState() throws {
        let inspectors = State<[String]>(["colours", "layers"])
        let renders = Renders()
        let application = InspectorApp(inspectors: inspectors.projectedValue)

        let patch = renders.render(tree(application))
        let colours = try XCTUnwrap(patch.children.first { $0.id == .manual("colours") })

        XCTAssertTrue(renders.fire(try XCTUnwrap(patch.children.last?.events?[.destroying])))
        XCTAssertEqual(inspectors.wrappedValue, ["colours"], "the window that reported is the one that left")

        let next = renders.render(tree(application))
        XCTAssertEqual(next.children.map(\.id), [.auto(2), colours.id])
    }

    /// The other way round - this side closed the window and the platform
    /// reports the destruction afterwards - needs no guard at all: a window
    /// that has left the tree has been FORGOTTEN, handlers and all, so the
    /// report quotes an id nothing answers to. Measured here rather than
    /// assumed, because an echo is what every other report protocol here had
    /// to be defended against.
    func testAReportForAWindowAlreadyGoneAnswersToNothing() throws {
        let inspectors = State<[String]>(["colours"])
        let renders = Renders()
        let application = InspectorApp(inspectors: inspectors.projectedValue)

        let patch = renders.render(tree(application))
        let destroying = try XCTUnwrap(patch.children.last?.events?[.destroying])

        inspectors.wrappedValue = []
        renders.render(tree(application))

        XCTAssertFalse(renders.fire(destroying), "the handler went with the window")
        XCTAssertEqual(inspectors.wrappedValue, [])
    }

    /// Each window's lifecycle handlers are its OWN: two windows listening to
    /// the same event answer under different ids, which is how the host reports
    /// the right one.
    func testEveryWindowHasItsOwnHandlerIds() throws {
        let inspectors = State<[String]>(["colours", "layers"])
        let patch = Renders().render(tree(InspectorApp(inspectors: inspectors.projectedValue)))

        let ids = patch.children.compactMap { $0.events?[.destroying] }

        XCTAssertEqual(ids.count, 2)
        XCTAssertNotEqual(ids[0], ids[1])
    }

    // MARK: - The platform asking for one

    /// The application's own handler, on the ROOT of the message - because what
    /// it answers with is a change to the window LIST, which belongs to no
    /// window in it.
    func testTheApplicationHearsThePlatformAskingForAWindow() throws {
        let documents = State<[String]>([])
        let application = AskedApp(documents: documents.projectedValue)

        let patch = Renders().render(tree(application))

        XCTAssertNotNil(
            patch.events?[.creatingWindow],
            "the application carries the handler the host quotes back")
    }

    /// And an application that does not answer says nothing - which is what
    /// tells the host to close the window the platform opened, rather than
    /// leaving it blank.
    func testAnApplicationThatDoesNotAnswerCarriesNoHandler() throws {
        let patch = Renders().render(tree(SingleApp()))

        XCTAssertNil(patch.events?[.creatingWindow])
    }

    /// Answering is an APPEND, and the window list is one longer for it: the
    /// same move a button in the interface would make, which is the whole point
    /// of the platform's request arriving as a handler rather than as a window.
    func testAnsweringOpensOneMoreWindow() async throws {
        let documents = State<[String]>([])
        let application = AskedApp(documents: documents.projectedValue)

        XCTAssertEqual(Renders().render(tree(application)).children.count, 1)

        let handler = try XCTUnwrap(tree(application).built.events[.creatingWindow])
        try await handler()

        XCTAssertEqual(documents.wrappedValue, ["Untitled 1"])
        XCTAssertEqual(Renders().render(tree(application)).children.count, 2)
    }

    /// And DECLINING is an answer too: the handler writes nothing, the tree
    /// still asks to be rendered, and the window list that message carries is
    /// what closes the blank window the reader asked for. Without the ask
    /// there is no message at all and that window stands there empty.
    func testDecliningStillAsksForTheMessageThatClosesTheWindow() async throws {
        let documents = State<[String]>([])

        Renderer.shared.setApplication(QuietApp(documents: documents.projectedValue))

        // Through the real describe rather than this file's copy of it: what
        // is under test is the handler the LIBRARY puts on the application.
        let asked = try XCTUnwrap(
            Renderer.shared.creatingWindowHandler,
            "the application hears the platform's request")

        _ = Renderer.shared.renderWire(baseline: 0)
        XCTAssertFalse(Renderer.shared.needsRender, "nothing is waiting to be drawn")

        try await asked()

        XCTAssertEqual(documents.wrappedValue, [], "the application described no window")
        XCTAssertTrue(Renderer.shared.needsRender, "and still answers the platform")
    }

    // MARK: - Two kinds of window, which is what a document application is

    /// A LAUNCHER and a workspace are two kinds of window in one list, and
    /// choosing a project is one assignment: the launcher stops being described
    /// and the workspace starts, in the same render.
    ///
    /// Nothing in the library says a window list is homogeneous - it is an
    /// array the author maps - so "start with a chooser, then work" needs no
    /// window type, no session and no router.
    func testAnApplicationCanStartWithAChooserAndThenOpenTheDocument() {
        let open = State<[String]>([])
        let picking = State(true)
        let renders = Renders()
        let application = StudioApp(
            open: open.projectedValue,
            picking: picking.projectedValue,
            contexts: ["Compiler": Workspace(project: "Compiler")])

        XCTAssertEqual(
            renders.render(tree(application)).children.map(\.id),
            [.manual("launcher")],
            "it opens on the chooser and nothing else")

        // What a row of the chooser does, and it is the whole move.
        open.wrappedValue = ["Compiler"]
        picking.wrappedValue = false

        let patch = renders.render(tree(application))

        XCTAssertTrue(patch.arranged)
        XCTAssertEqual(patch.children.map(\.id), [.manual("project-Compiler")])
    }

    /// And the workspace window LENDS its document to every page inside it, so
    /// a page reads the project it belongs to by type - which is the answer to
    /// threading a context through every initializer between the window and the
    /// view that wants it.
    func testAWindowCanSeedTheEnvironmentForEverythingInIt() throws {
        let open = State<[String]>(["Compiler"])
        let picking = State(false)
        let workspace = Workspace(project: "Compiler")
        let application = StudioApp(
            open: open.projectedValue,
            picking: picking.projectedValue,
            contexts: ["Compiler": workspace])

        let window = try XCTUnwrap(tree(application).built.children.first)
        let seeded = window.environments

        XCTAssertEqual(seeded.count, 1)
        XCTAssertIdentical(seeded.first?.object as? Workspace, workspace)
    }

    /// A SPLASH is a different question and has a different answer: one window
    /// whose PAGE changes, rather than one window replaced by another.
    ///
    /// Worth keeping apart, because replacing the window in the list really
    /// does close one and open another - a flash on a desktop, and the wrong
    /// thing entirely while an application is still starting up.
    func testALoadingScreenIsAPageChangeAndNotAWindowChange() {
        struct Starting: Application {
            let loading: Binding<Bool>

            func createWindow() -> Window {
                StudioWindow(ready: !loading.wrappedValue)
            }
        }

        let loading = State(true)
        let renders = Renders()
        let application = Starting(loading: loading.projectedValue)

        let first = renders.render(tree(application))
        let identity = try? XCTUnwrap(first.children.first).id

        loading.wrappedValue = false
        let patch = renders.render(tree(application))

        XCTAssertEqual(
            patch.children.first?.id, identity,
            "the same window throughout - nothing closes and nothing opens")
    }

    /// And what DRIVES the loading screen is the window's own `onCreated`,
    /// awaiting whatever it has to await - components fetched over the network,
    /// a database opened, a licence checked.
    ///
    /// The handler is `async` and runs between renders, so the work is written
    /// straight down; finishing it is one assignment, and the next render is
    /// what swaps the page. Nothing is subscribed, nothing is invalidated and
    /// the window never moves.
    func testTheLoadingScreenIsDrivenByTheWindowsOwnCreatedHandler() async throws {
        struct Starting: Application {
            let ready: Binding<Bool>
            let load: @Sendable () async throws -> Void

            func createWindow() -> Window {
                StudioWindow(ready: ready.wrappedValue) {
                    try await load()
                    ready.wrappedValue = true
                }
            }
        }

        let ready = State(false)
        let renders = Renders()
        let application = Starting(ready: ready.projectedValue) {
            try await Task.sleep(nanoseconds: 1_000_000)
        }

        let first = renders.render(tree(application))
        let identity = try XCTUnwrap(first.children.first).id

        // What the host does when the platform says the window is up.
        let created = try XCTUnwrap(tree(application).built.children.first?.events[.created])
        try await created()

        XCTAssertTrue(ready.wrappedValue)

        let patch = renders.render(tree(application))

        XCTAssertEqual(
            patch.children.first?.id, identity,
            "the same window - the loading screen was a PAGE, not a window")
    }

    // MARK: - A window is a place to keep things

    /// A window declared as a type may hold `@State` of its own, exactly as a
    /// page does - which is what makes "the arrangement lives on the window" a
    /// real answer rather than somewhere to thread bindings through.
    ///
    /// The window is a PLACEHOLDER in the tree, so the differ adopts its boxes
    /// across renders: a fresh window value on the next build reads the state
    /// the last one wrote, and nothing has to be lifted onto the application.
    func testAWindowKeepsStateOfItsOwnAcrossRenders() throws {
        struct CountingWindow: Window {
            @State private var opened = 0

            var title: String? { "\(opened)" }

            /// What the platform saying "the window is up" writes - the window's
            /// own state, written by the window's own handler.
            var onCreated: EventHandler? { { opened += 1 } }

            var content: Page { MainPage() }
        }

        struct CountingApp: Application {
            func createWindow() -> Window { CountingWindow() }
        }

        let renders = Renders()
        let application = CountingApp()

        let first = renders.render(tree(application))

        XCTAssertEqual(try XCTUnwrap(first.children.first).props[.title], .string("0"))

        XCTAssertTrue(
            renders.fire(try XCTUnwrap(first.children.first?.events?[.created])))

        let patch = renders.render(tree(application))

        XCTAssertEqual(
            try XCTUnwrap(patch.children.first).props[.title], .string("1"),
            "a window whose state was not adopted would have counted from zero again")
    }

    // MARK: - The contract the C# side reads

    /// Three windows opened and one closed, written down: the C# side applies
    /// these two files to a real application and opens and closes real MAUI
    /// windows from them.
    func testTheWindowsAreWrittenDown() throws {
        let inspectors = State<[String]>(["colours", "layers"])
        let application = InspectorApp(inspectors: inspectors.projectedValue)

        let differ = Differ()
        let dictionary = WireDictionary()
        let names = WireNames()

        let opened = differ.reconcile(nil, with: tree(application), describeAll: true)
        let first = Wire.encode(opened.patch, generation: 1, complete: true, dictionary: dictionary)

        try Fixtures.check(
            first,
            sidecar: WireProbe.dumpMessage(first, names: names),
            against: "windows/1-opens")

        inspectors.wrappedValue = ["layers"]

        let closed = differ.reconcile(opened.node, with: tree(application))
        let second = Wire.encode(closed.patch, generation: 2, dictionary: dictionary)

        try Fixtures.check(
            second,
            sidecar: WireProbe.dumpMessage(second, names: names),
            against: "windows/2-closes")
    }
}
