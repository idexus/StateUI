// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What is presented over the window, as Swift describes it.
//
// A modal stack is an array the author holds, exactly as a navigation path is,
// and it is an arrangement of that shape: the page it holds first, the sheets
// over it after, as the window's page. What each page's view says of it is in
// the message that brings it.
// Coming back there is one report, and it says how many are STILL presented -
// the sheet the user dragged down has already gone.
//
import XCTest
@_spi(Host) @testable import StateUI

/// What an application presents over itself. An enum, because the destination
/// is a `switch` and the compiler is what says every case has a page.
private enum Sheet: Hashable {
    case settings
    case about
}

/// The page underneath, which is what presents.
private struct HomePage: View {
    @Binding var sheets: [Sheet]

    var body: some View {
        Button("Settings")
            .onClicked { sheets.append(.settings) }
            .title("Home")
    }
}

/// A presented page. It carries its own way out, because a modal covers the
/// bars as well as the content and there is nothing else to close it with -
/// and its view says what it is called.
private struct SheetPage: View {
    @Binding var sheets: [Sheet]

    let name: String

    var body: some View {
        Button("Close")
            .onClicked { sheets.removeLast() }
            .title(name)
    }
}

/// The page of the window under test, over whatever state is lent to it.
private struct MainPage: View {
    let sheets: Binding<[Sheet]>

    /// The stack the window shows, for the one test that puts a navigation page
    /// under the sheets. Nil is the plain home page.
    var path: Binding<[Int]>?

    var body: some View {
        let sheets = sheets
        return ModalStack(sheets) {
            if let path {
                NavigationStack(path) {
                    HomePage(sheets: sheets)
                } destination: { _ in
                    HomePage(sheets: sheets)
                }
                .title("Diary")
            } else {
                HomePage(sheets: sheets)
            }
        } destination: { sheet in
            switch sheet {
            case .settings: SheetPage(sheets: sheets, name: "Settings")
            case .about: SheetPage(sheets: sheets, name: "About")
            }
        }
    }
}

final class ModalStackTests: XCTestCase {
    /// The session of the window under test, the same in each of its renders.
    private let session = WindowSession()

    /// The window under test, over whatever state is lent to it.
    private func window(_ sheets: Binding<[Sheet]>) -> Node {
        Node.window(MainPage(sheets: sheets), session: session)
    }

    // MARK: - What goes out

    /// A window with nothing presented shows the stack's own page alone - which
    /// is what tells the host to dismiss whatever it is still holding.
    func testAWindowWithNothingPresentedShowsTheStacksPageAlone() {
        let sheets = State<[Sheet]>([])

        let patch = Renders().settled(window(sheets.projectedValue))

        XCTAssertEqual(patch.children.map { $0.type.name }, ["ModalStack"])
        XCTAssertEqual(patch.children.first?.children.map(\.id), [.manual("root")])
    }

    /// One presented page is one child after the stack's own, and its identity
    /// carries its DEPTH as well as its value - the rule a navigation stack
    /// follows, for the reason a stack has it: two identical sheets are two
    /// pages.
    func testAPresentedPageIsAChildOfTheStackWearingItsDepth() {
        let sheets = State<[Sheet]>([.settings, .about])

        let stack = Renders().settled(window(sheets.projectedValue)).children.first
        let presented = stack?.children.dropFirst()

        XCTAssertEqual(presented?.map { $0.id }, [.manual("0/settings"), .manual("1/about")])
        XCTAssertEqual(presented?.map { $0.props["title"] }, [.string("Settings"), .string("About")])
    }

    /// Presenting is appending, and that is the whole of it: the tap on the
    /// page underneath writes the array, and the next render carries a page
    /// that was not there before - the stack was written once, and the window
    /// is what read the array.
    func testPresentingIsAppendingToTheArray() {
        let sheets = State<[Sheet]>([])
        let renders = Renders()

        let first = renders.settled(window(sheets.projectedValue))
        let button = first.children.first?.children.first?.children.first

        XCTAssertTrue(renders.fire(button?.events?["clicked"] ?? -1))
        XCTAssertEqual(sheets.wrappedValue, [.settings])

        let patch = renders.settled(
            window(sheets.projectedValue), changed: Renderer.shared.pendingChanges)
        let stack = patch.children.first { $0.type == "ModalStack" }

        XCTAssertEqual(stack?.arrangement, [.manual("root"), .manual("0/settings")], "presented over the stack's page")
    }

    /// And closing is the array getting shorter. The button is on the SHEET,
    /// which is where it has to be: a modal covers the bar the page underneath
    /// would have offered.
    func testClosingIsTheArrayGettingShorter() {
        let sheets = State<[Sheet]>([.settings])
        let renders = Renders()

        let first = renders.settled(window(sheets.projectedValue))
        let close = first.children.first { $0.type == "ModalStack" }?
            .children.last?.children.first

        XCTAssertTrue(renders.fire(close?.events?["clicked"] ?? -1))
        XCTAssertEqual(sheets.wrappedValue, [])

        let patch = renders.settled(
            window(sheets.projectedValue), changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(patch.children.first { $0.type == "ModalStack" }?.arrangement, [.manual("root")])
    }

    // MARK: - What comes back

    /// A native dismissal reports what survived, and the array is truncated to
    /// that depth.
    func testADismissalTruncatesTheArray() {
        let sheets = State<[Sheet]>([.settings])
        let renders = Renders()

        let patch = renders.settled(window(sheets.projectedValue))

        XCTAssertTrue(renders.fire(patch.children.first?.events?["popped"] ?? -1, with: [.number(0)]))
        XCTAssertEqual(sheets.wrappedValue, [])
    }

    /// Only the top one went: a report of one surviving over a stack of two
    /// leaves the first sheet presented.
    func testADismissalOfTheTopLeavesWhatIsUnderIt() {
        let sheets = State<[Sheet]>([.settings, .about])
        let renders = Renders()

        let patch = renders.settled(window(sheets.projectedValue))

        XCTAssertTrue(renders.fire(patch.children.first?.events?["popped"] ?? -1, with: [.number(1)]))
        XCTAssertEqual(sheets.wrappedValue, [.settings])
    }

    /// A report that would LENGTHEN the array is refused - it has been
    /// overtaken by something this side already did, and obeying it would put a
    /// dismissed sheet back on the screen.
    func testAReportThatWouldPresentSomethingAgainIsRefused() {
        let sheets = State<[Sheet]>([])
        let renders = Renders()

        let patch = renders.settled(window(sheets.projectedValue))

        XCTAssertTrue(renders.fire(patch.children.first?.events?["popped"] ?? -1, with: [.number(2)]))
        XCTAssertEqual(sheets.wrappedValue, [])
    }

    /// A payload of the wrong shape leaves the array alone.
    func testAValueOfTheWrongKindLeavesTheArrayAlone() {
        let sheets = State<[Sheet]>([.settings])
        let renders = Renders()

        let patch = renders.settled(window(sheets.projectedValue))

        XCTAssertTrue(renders.fire(patch.children.first?.events?["popped"] ?? -1, with: [.string("0")]))
        XCTAssertEqual(sheets.wrappedValue, [.settings])
    }

    // MARK: - The contract a host reads

    /// The whole thing: a window whose page is a modal stack holding a
    /// navigation stack, with two pages presented over all of it - as the
    /// message that brings them carries them.
    func testTwoPagesArePresentedOverTheWholeWindow() throws {
        let sheets = State<[Sheet]>([.settings, .about])
        let path = State<[Int]>([1])

        let window = Renders().settled(
            Node.window(MainPage(sheets: sheets.projectedValue, path: path.projectedValue), session: session))

        XCTAssertEqual(window.children.map(\.type), [.modalStack])
        XCTAssertEqual(window.eventNames, HostPatch.windowEvents)
        let modal = try XCTUnwrap(window.children.first)
        XCTAssertEqual(modal.eventNames, ["popped"])
        XCTAssertEqual(modal.arrangement, [.manual("root"), .manual("0/settings"), .manual("1/about")])
        XCTAssertEqual(modal.children.first?.type, .navigationStack)
        XCTAssertEqual(modal.children.first?.arrangement, [.manual("root"), .manual("0/1")])
        let presented = modal.children.dropFirst()
        XCTAssertEqual(presented.map { $0.props["title"] }, [.string("Settings"), .string("About")])
        XCTAssertTrue(presented.allSatisfy { $0.eventNames.isEmpty }, "a page hears what its view hears: nothing here")
    }
}
