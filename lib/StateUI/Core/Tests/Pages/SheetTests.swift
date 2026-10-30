// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A sheet as the core writes it: a slot of the view presenting it, holding its page while it shows, closed as its
// state says - the user's dismissal written back, the view leaving written too.

import XCTest
@_spi(Host) @testable import StateUI

/// What a sheet presents of a value.
private struct Note: Hashable {
    let name: String
}

/// A view presenting a sheet while its state says so.
private struct Presenting: View {
    let editing: Proxy<Bool>

    var body: some View {
        Button("Edit")
            .sheet(isPresented: editing) {
                Text("Editor").title("Editor")
            }
    }
}

/// A view presenting a page of the note its state holds.
private struct PresentingANote: View {
    let note: Proxy<Note?>

    var body: some View {
        Text("Notes")
            .sheet(item: note) { note in
                Text(note.name).title(note.name)
            }
    }
}

/// A view presenting a stack of pages in its sheet.
private struct PresentingAStack: View {
    let shown: Binding<Bool>
    @State private var path: [Int] = []

    var body: some View {
        Text("Folders")
            .sheet(isPresented: shown) {
                NavigationStack($path) { Text("Inbox") } destination: { _ in Text("Mail") }
            }
    }
}

/// A sheet written on a group holding a branch.
private struct GroupPresenting: View {
    let shows: Binding<Bool>
    let wide: Binding<Bool>

    var body: some View {
        Group {
            if wide.wrappedValue {
                Text("Wide")
            } else {
                Text("Narrow")
            }
        }
        .sheet(isPresented: shows) {
            Text("Sheet")
        }
    }
}

/// A view standing while its state says so, presenting a sheet.
private struct Leaving: View {
    let stands: Binding<Bool>
    let editing: Binding<Bool>

    var body: some View {
        VStack {
            if stands.wrappedValue {
                Presenting(editing: editing.proxy)
            }
        }
    }
}

@MainActor
final class SheetTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// A proxy the host does not carry, whose writes the test reads back.
    private func binding<Value>(_ value: Value, _ written: @escaping (Value) -> Void) -> Proxy<Value> {
        var held = value
        return Proxy(get: { held }, set: { held = $0; written($0) })
    }

    /// A sheet is one slot of the view presenting it: while its state is false it holds no page, its state
    /// described - never carried by the host, as the view builds its page again; while true, the page its content
    /// makes.
    func testASheetHoldsItsPageWhileItShows() throws {
        let editing = State(wrappedValue: false)
        let hidden = Presenting(editing: editing.projectedValue.proxy).node.built
        let sheet = try XCTUnwrap(hidden.children.first { $0.type == .sheet })

        XCTAssertNil(sheet.driven[.isPresented], "described, not carried")
        XCTAssertEqual(sheet.props[.isPresented], .bool(false))
        XCTAssertTrue(sheet.children.isEmpty, "nothing built while it does not show")

        editing.wrappedValue = true
        let patch = Renders().render(Presenting(editing: editing.projectedValue.proxy).node)
        let shown = try XCTUnwrap(patch.subtree.first { $0.type == .sheet })
        XCTAssertEqual(shown.children.map(\.type), [.page])
        XCTAssertEqual(shown.children.first?.props[.title], .string("Editor"))
    }

    /// The user's dismissal writes false into a proxy the host does not carry.
    func testTheDismissalWritesFalseIntoIsPresented() throws {
        var written: [Bool] = []
        let renders = Renders()
        let patch = renders.render(Presenting(editing: binding(true) { written.append($0) }).node)
        let sheet = try XCTUnwrap(patch.subtree.first { $0.type == .sheet })

        XCTAssertEqual(sheet.props[.isPresented], .bool(true))
        XCTAssertTrue(renders.fire(try XCTUnwrap(sheet.events?[.isPresentedChanged]), with: [.bool(false)]))
        XCTAssertEqual(written, [false], "the dismissal written into the state")
    }

    /// A value presents the page its content makes of it, keyed by it; the user's dismissal writes nil.
    func testTheDismissalWritesNilIntoItem() throws {
        var written: [Note?] = []
        let renders = Renders()
        let patch = renders.render(PresentingANote(note: binding(Note(name: "Inbox")) { written.append($0) }).node)
        let sheet = try XCTUnwrap(patch.subtree.first { $0.type == .sheet })

        XCTAssertEqual(sheet.props[.isPresented], .bool(true))
        XCTAssertEqual(sheet.children.first?.props[.title], .string("Inbox"))
        XCTAssertTrue(renders.fire(try XCTUnwrap(sheet.events?[.isPresentedChanged]), with: [.bool(false)]))
        XCTAssertEqual(written, [nil], "the dismissal written into the state")
    }

    /// Another value presents another page, standing in the place of the first.
    func testAnotherItemIsAnotherPage() throws {
        let note = State<Note?>(wrappedValue: Note(name: "Inbox"))
        let first = try XCTUnwrap(PresentingANote(note: note.projectedValue.proxy).node.built.children.first { $0.type == .sheet })
        note.wrappedValue = Note(name: "Sent")
        let second = try XCTUnwrap(PresentingANote(note: note.projectedValue.proxy).node.built.children.first { $0.type == .sheet })

        XCTAssertNotEqual(first.children.first?.identity, second.children.first?.identity)
        let patch = Renders().render(PresentingANote(note: note.projectedValue.proxy).node)
        XCTAssertEqual(patch.subtree.first { $0.type == .sheet }?.children.first?.props[.title], .string("Sent"))
    }

    /// The view presenting a sheet leaves the tree: its sheet closes, and its state is written false.
    func testAViewLeavingClosesItsSheet() throws {
        let (stands, editing) = (State(wrappedValue: true), State(wrappedValue: true))
        let renders = Renders()
        _ = renders.settled(Leaving(stands: stands.projectedValue, editing: editing.projectedValue).node)

        stands.wrappedValue = false
        _ = renders.settled(
            Leaving(stands: stands.projectedValue, editing: editing.projectedValue).node,
            changed: Renderer.shared.pendingChanges)
        XCTAssertFalse(editing.wrappedValue, "the state says the sheet is closed")
    }

    /// A sheet written on a composed view stays as the view builds again - its state written by nothing: shown, it
    /// shows on.
    func testASheetOnAComposedViewStaysAsItBuildsAgain() throws {
        let (shows, wide) = (State(wrappedValue: false), State(wrappedValue: false))
        let renders = Renders()
        let view = { GroupPresenting(shows: shows.projectedValue, wide: wide.projectedValue).node }
        _ = renders.settled(view())

        shows.wrappedValue = true
        let shown = renders.settled(view(), changed: Renderer.shared.pendingChanges)
        _ = renders.settled(view(), changed: Renderer.shared.pendingChanges)
        XCTAssertTrue(shows.wrappedValue, "nothing closed it")
        XCTAssertEqual(shown.subtree.first { $0.type == .sheet }?.children.count, 1)
    }

    /// The same on a window's page, its branch flipping: shown, it shows on.
    func testASheetOnAWindowsPageShowsOnAsItsBranchFlips() throws {
        let (shows, wide) = (State(wrappedValue: false), State(wrappedValue: false))
        let session = WindowSession()
        let renders = Renders()
        let window = { Node.window(GroupPresenting(shows: shows.projectedValue, wide: wide.projectedValue), session: session) }
        _ = renders.settled(window())

        shows.wrappedValue = true
        let shown = renders.revisit(changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(shown.subtree.first { $0.type == .sheet }?.children.count, 1, "it shows its page")

        wide.wrappedValue = true
        _ = renders.revisit(changed: Renderer.shared.pendingChanges)
        XCTAssertTrue(shows.wrappedValue, "nothing closed it")
    }

    /// An arrangement stands as a sheet's page: its stack is presented, not left out.
    func testAStackStandsAsASheetsPage() throws {
        let patch = Renders().render(PresentingAStack(shown: State(wrappedValue: true).projectedValue).node)
        let sheet = try XCTUnwrap(patch.subtree.first { $0.type == .sheet })

        XCTAssertEqual(sheet.children.map(\.type), [.navigationStack])
    }
}
