// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A window's sheets as every host shares them: the pages its views present, closed by the user onto their states.

@_spi(Host) import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

@MainActor
final class SheetsTests: XCTestCase {
    // Fresh states each test: a window going takes its sheets away and writes their states, as any view leaving.
    override func setUp() async throws {
        Sheets.editing = State(wrappedValue: true)
        Sheets.picking = State(wrappedValue: true)
        Sheets.note = State(wrappedValue: "Inbox")
        Sheets.stackPath = State(wrappedValue: [])
        stateUIUseApp(SheetsApplication())
    }

    /// The runtime of `SheetsApplication`, its window made and rendered.
    private func runtime() -> HostRuntime {
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        return runtime
    }

    /// The window of `runtime`.
    private func window(_ runtime: HostRuntime) throws -> MountedElement {
        try XCTUnwrap(runtime.tree.root?.first(type: .window))
    }

    /// The pages the window's sheets present, in the order they showed.
    private func shown(_ runtime: HostRuntime) throws -> [MountedElement] {
        runtime.tree.presentedSheets(in: try window(runtime))
    }

    /// The page of the last sheet holding the view `id`.
    private func page(holding id: String, in runtime: HostRuntime) throws -> MountedElement {
        try XCTUnwrap(try shown(runtime).last { $0.first(id: .manual(id)) != nil })
    }

    /// The window's sheets stand in the order they showed: one presented in a sheet over it, one presented beside
    /// over them both.
    func testTheSheetsStandInTheOrderTheyShowed() throws {
        let runtime = runtime()

        XCTAssertEqual(try shown(runtime).map { $0.parent?.id }, try [
            page(holding: "pick", in: runtime), page(holding: "picker", in: runtime), page(holding: "note", in: runtime),
        ].map { $0.parent?.id })
    }

    /// The user closing a sheet presented by a flag writes false into it; one presented by a value writes nil.
    func testTheUsersDismissalWritesFalseIntoIsPresentedAndNilIntoItem() throws {
        let runtime = runtime()
        let window = try window(runtime)

        runtime.goBack(.dismissSheets([try page(holding: "note", in: runtime)]), in: window)
        runtime.pump.turn()
        XCTAssertNil(Sheets.note.wrappedValue, "the value's sheet closed: nil")

        runtime.goBack(.dismissSheets([try page(holding: "picker", in: runtime)]), in: window)
        runtime.pump.turn()
        XCTAssertFalse(Sheets.picking.wrappedValue, "the flag's sheet closed: false")
        XCTAssertTrue(Sheets.editing.wrappedValue, "the sheet under it stays")
        XCTAssertEqual(try shown(runtime).count, 1)
    }

    /// A sheet closing takes the sheet presented in it away, and that one's state says so too.
    func testASheetClosingTakesItsNestedSheetAndWritesItsState() throws {
        let runtime = runtime()

        runtime.goBack(.dismissSheets([try page(holding: "pick", in: runtime)]), in: try window(runtime))
        runtime.pump.turn()

        XCTAssertFalse(Sheets.editing.wrappedValue)
        XCTAssertFalse(Sheets.picking.wrappedValue, "the sheet in it went, its state written false")
    }

    /// Sheets going together, the top first, each state written.
    func testSheetsGoingTogetherWriteEachState() throws {
        let runtime = runtime()
        let going = try [page(holding: "note", in: runtime), page(holding: "picker", in: runtime)]

        runtime.goBack(.dismissSheets(going), in: try window(runtime))
        runtime.pump.turn()

        XCTAssertNil(Sheets.note.wrappedValue)
        XCTAssertFalse(Sheets.picking.wrappedValue)
        XCTAssertTrue(Sheets.editing.wrappedValue)
    }

    /// What stands under a sheet is out of the user's sight, the top sheet's in it; with no sheet, the window's page
    /// is in sight again.
    func testWhatStandsUnderASheetIsOutOfSight() throws {
        let runtime = runtime()
        // The window's first button, in the tree's order before the sheets' own.
        let edit = { runtime.tree.root?.first(type: .button) }

        XCTAssertEqual(edit()?.standsInSight, false, "under the sheets")
        XCTAssertEqual(try page(holding: "note", in: runtime).first(id: .manual("note"))?.standsInSight, true, "the top one")
        XCTAssertEqual(try page(holding: "picker", in: runtime).first(id: .manual("picker"))?.standsInSight, false)

        Sheets.note.wrappedValue = nil
        Sheets.editing.wrappedValue = false
        runtime.pump.turn()
        XCTAssertEqual(edit()?.standsInSight, true, "no sheet over it")
    }

    /// A sheet presented later from a view of a group shows on through the renders after.
    func testASheetPresentedLaterShowsOn() throws {
        Sheets.editing = State(wrappedValue: false)
        stateUIUseApp(GroupSheetApplication())
        let runtime = runtime()
        XCTAssertEqual(try shown(runtime).count, 0)

        Sheets.editing.wrappedValue = true
        var counts: [Int] = []
        for _ in 0..<4 {
            runtime.pump.turn()
            counts.append(try shown(runtime).count)
        }
        XCTAssertEqual(counts, [1, 1, 1, 1])
        XCTAssertTrue(Sheets.editing.wrappedValue)
    }

    /// Back in a window takes the top sheet's own stack first, then the top sheet.
    func testTheWayBackTakesTheTopSheetsStackThenTheSheet() throws {
        Sheets.stackPath.wrappedValue = [1]
        stateUIUseApp(StackSheetApplication())
        let runtime = runtime()
        let presentation = WindowPresentation()
        let window = try window(runtime)
        _ = presentation.show(window, in: runtime.lifecycle)

        guard case .pop(let stack) = presentation.wayBack else { return XCTFail("the sheet's stack first") }
        XCTAssertEqual(stack.type, .navigationStack)
        Sheets.stackPath.wrappedValue = []
        runtime.pump.turn()
        _ = presentation.show(window, in: runtime.lifecycle)
        guard case .dismissSheets(let pages) = presentation.wayBack else { return XCTFail("then the top sheet") }
        XCTAssertEqual(pages.map(\.type), [.navigationStack])
    }
}

/// The states the sheets of `SheetsApplication` show by.
@MainActor
private enum Sheets {
    static var editing = State(wrappedValue: true)
    static var picking = State(wrappedValue: true)
    static var note = State<String?>(wrappedValue: "Inbox")
    static var stackPath = State<[Int]>(wrappedValue: [])
}

private struct SheetsApplication: Application {
    var body: some Scene {
        WindowGroup { SheetsPage() }
    }
}

/// A page presenting a sheet by a flag, a sheet in it by another, and beside them a sheet by a value - holding a
/// stack where it shows the stack's path.
private struct SheetsPage: View {
    var body: some View {
        VStack {
            Button("Edit")
                .sheet(isPresented: Sheets.editing.projectedValue) {
                    Button("Pick")
                        .id("pick")
                        .sheet(isPresented: Sheets.picking.projectedValue) {
                            Text("Picker").id("picker")
                        }
                }
            Text("Notes")
                .sheet(item: Sheets.note.projectedValue) { note in
                    Text(note).id("note")
                }
        }
    }
}

private struct GroupSheetApplication: Application {
    var body: some Scene {
        WindowGroup { GroupSheetPage() }
    }
}

/// A group of one box or another, presenting a sheet.
private struct GroupSheetPage: View {
    var body: some View {
        Group {
            if Sheets.picking.wrappedValue {
                Rectangle().fill(.steelBlue).id("first")
            } else {
                Text("Other")
            }
        }
        .sheet(isPresented: Sheets.editing.projectedValue) {
            Rectangle().fill(.firebrick).width(240).height(160).id("sheet")
        }
    }
}

private struct StackSheetApplication: Application {
    var body: some Scene {
        WindowGroup { StackSheetPage() }
    }
}

/// A page presenting a sheet that holds a stack, on the stack's path.
private struct StackSheetPage: View {
    var body: some View {
        Text("Folders")
            .sheet(isPresented: Sheets.editing.projectedValue) {
                NavigationStack(Sheets.stackPath.projectedValue) { Text("Folders root") } destination: { _ in
                    Text("Folder")
                }
            }
    }
}
