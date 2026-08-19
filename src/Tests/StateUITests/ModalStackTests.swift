// What is presented over the window, as Swift describes it.
//
// A modal stack is an array the author holds, exactly as a navigation path is,
// and it rides as a list of pages under one wrapper node beside the window's
// own page. Coming back there is one report, and it says how many are STILL
// presented - the sheet the reader dragged down has already gone.
//
// What the renderer does with it is next door, in the C# ModalStackTests.

import StateUIWireProbe
import XCTest
@testable import StateUI

/// What an application presents over itself. An enum, because the destination
/// is a `switch` and the compiler is what says every case has a page.
private enum Sheet: Hashable {
    case settings
    case about
}

/// The page underneath, which is what presents.
private struct HomePage: ContentPage {
    @Binding var sheets: [Sheet]

    var title: String? { "Home" }

    var content: Element {
        Button("Settings").onClicked { sheets.append(.settings) }
    }
}

/// A presented page. It carries its own way out, because a modal covers the
/// bars as well as the content and there is nothing else to close it with.
private struct SheetPage: ContentPage {
    @Binding var sheets: [Sheet]

    let name: String

    var title: String? { name }
    var modalPresentationStyle: UIModalPresentationStyle? { .pageSheet }

    var content: Element {
        Button("Close").onClicked { sheets.removeLast() }
    }
}

/// The window under test, over whatever state is lent to it.
private struct TestWindow: Window {
    let sheets: Binding<[Sheet]>

    /// The stack the window shows, for the one test that puts a navigation page
    /// under the sheets. Nil is the plain home page.
    var path: Binding<[Int]>?

    var title: String?

    var modalStack: ModalStack? {
        ModalStack(sheets) { sheet in
            switch sheet {
            case .settings: SheetPage(sheets: sheets, name: "Settings")
            case .about: SheetPage(sheets: sheets, name: "About")
            }
        }
    }

    var content: Page {
        guard let path else { return HomePage(sheets: sheets) }

        return NavigationPage(path) {
            HomePage(sheets: sheets)
        } destination: { _ in
            HomePage(sheets: sheets)
        }
        .title("Diary")
    }
}

/// The window under test, over whatever state is lent to it.
private func window(_ sheets: Binding<[Sheet]>) -> Window {
    TestWindow(sheets: sheets)
}

final class ModalStackTests: XCTestCase {
    // MARK: - What goes out

    /// A window with nothing presented still says so: the list is there and it
    /// is empty, which is what tells the host to dismiss whatever it is still
    /// holding.
    func testAWindowWithNothingPresentedCarriesAnEmptyList() {
        let sheets = State<[Sheet]>([])

        let node = window(sheets.projectedValue).body.built

        XCTAssertEqual(node.children.map { $0.type.name }, ["ContentPage", "ModalStack"])
        XCTAssertEqual(node.children.last?.children.count, 0)
    }

    /// One presented page is one child of the list, and its identity carries
    /// its DEPTH as well as its value - the rule a navigation stack follows,
    /// for the reason a stack has it: two identical sheets are two pages.
    func testAPresentedPageIsAChildOfTheListWearingItsDepth() {
        let sheets = State<[Sheet]>([.settings, .about])

        let list = window(sheets.projectedValue).body.built.children.last

        XCTAssertEqual(list?.children.map { $0.id }, ["0/settings", "1/about"])
        XCTAssertEqual(list?.children.map { $0.built.props["title"] },
                       [.string("Settings"), .string("About")])
    }

    /// Presenting is appending, and that is the whole of it: the tap on the
    /// page underneath writes the array, and the next render carries a page
    /// that was not there before.
    func testPresentingIsAppendingToTheArray() {
        let sheets = State<[Sheet]>([])
        let renders = Renders()

        let first = renders.render(window(sheets.projectedValue).body)
        let button = first.children.first?.children.first

        XCTAssertTrue(renders.fire(button?.events?["clicked"] ?? -1))
        XCTAssertEqual(sheets.wrappedValue, [.settings])

        let patch = renders.render(window(sheets.projectedValue).body)
        let list = patch.children.first { $0.type == "ModalStack" }

        XCTAssertEqual(list?.children.map { $0.id }, [.manual("0/settings")])
    }

    /// And closing is the array getting shorter. The button is on the SHEET,
    /// which is where it has to be: a modal covers the bar the page underneath
    /// would have offered.
    func testClosingIsTheArrayGettingShorter() {
        let sheets = State<[Sheet]>([.settings])
        let renders = Renders()

        let first = renders.render(window(sheets.projectedValue).body)
        let close = first.children.first { $0.type == "ModalStack" }?
            .children.first?.children.first

        XCTAssertTrue(renders.fire(close?.events?["clicked"] ?? -1))
        XCTAssertEqual(sheets.wrappedValue, [])

        let patch = renders.render(window(sheets.projectedValue).body)

        XCTAssertEqual(patch.children.first { $0.type == "ModalStack" }?.children.count, 0)
    }

    /// The style a page is drawn with is the PAGE's own property, not the
    /// stack's - so a sheet knows what it looks like wherever it is presented
    /// from, and a page pushed onto a navigation stack simply carries a
    /// property nothing reads.
    func testHowAPageIsPresentedIsThePagesOwnProperty() {
        let sheets = State<[Sheet]>([.settings])

        let sheet = window(sheets.projectedValue).body.built.children.last?.children.first

        XCTAssertEqual(sheet?.built.props["modalPresentationStyle"], .enumeration(3), "pageSheet")
    }

    /// A page the library CONSTRUCTS says the same thing by modifier, which is
    /// the shape of a sheet on iOS: a whole navigation stack presented as a
    /// card, with a bar and a way out of its own.
    func testAConstructedPageSaysItByModifier() {
        let path = State<[Int]>([])

        let node = NavigationPage(path.projectedValue) {
            SheetPage(sheets: State<[Sheet]>([]).projectedValue, name: "Settings")
        } destination: { _ in
            SheetPage(sheets: State<[Sheet]>([]).projectedValue, name: "Deeper")
        }
        .modalPresentationStyle(.formSheet)
        .body
        .built

        XCTAssertEqual(node.props["modalPresentationStyle"], .enumeration(1), "formSheet")
    }

    // MARK: - What comes back

    /// The reader's own way out - an iOS sheet dragged down, Android's system
    /// back. The payload is what SURVIVED, and the array is truncated to it.
    func testADismissalTruncatesTheArray() {
        let sheets = State<[Sheet]>([.settings])
        let renders = Renders()

        let patch = renders.render(window(sheets.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["modalPopped"] ?? -1, with: [.number(0)]))
        XCTAssertEqual(sheets.wrappedValue, [])
    }

    /// Only the top one went: a report of one surviving over a stack of two
    /// leaves the first sheet presented.
    func testADismissalOfTheTopLeavesWhatIsUnderIt() {
        let sheets = State<[Sheet]>([.settings, .about])
        let renders = Renders()

        let patch = renders.render(window(sheets.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["modalPopped"] ?? -1, with: [.number(1)]))
        XCTAssertEqual(sheets.wrappedValue, [.settings])
    }

    /// A report that would LENGTHEN the array is refused - it has been
    /// overtaken by something this side already did, and obeying it would put a
    /// dismissed sheet back on the screen.
    func testAReportThatWouldPresentSomethingAgainIsRefused() {
        let sheets = State<[Sheet]>([])
        let renders = Renders()

        let patch = renders.render(window(sheets.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["modalPopped"] ?? -1, with: [.number(2)]))
        XCTAssertEqual(sheets.wrappedValue, [])
    }

    /// A payload of the wrong shape leaves the array alone.
    func testAValueOfTheWrongKindLeavesTheArrayAlone() {
        let sheets = State<[Sheet]>([.settings])
        let renders = Renders()

        let patch = renders.render(window(sheets.projectedValue).body)

        XCTAssertTrue(renders.fire(patch.events?["modalPopped"] ?? -1, with: [.string("0")]))
        XCTAssertEqual(sheets.wrappedValue, [.settings])
    }

    // MARK: - The contract the C# side reads

    /// The whole thing, written down: a window whose page is a navigation
    /// stack, with two pages presented over all of it.
    func testTheModalStackIsWrittenDown() throws {
        let sheets = State<[Sheet]>([.settings, .about])
        let path = State<[Int]>([1])
        let differ = Differ()

        let tree = TestWindow(
            sheets: sheets.projectedValue,
            path: path.projectedValue,
            title: "StateUI").body

        let result = differ.reconcile(nil, with: tree)
        let bytes = Wire.encode(result.patch, generation: 1, dictionary: WireDictionary())

        try Fixtures.check(
            bytes,
            sidecar: WireProbe.dumpMessage(bytes, names: WireNames()),
            against: "pages/ModalStack")
    }
}
