// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SheetContract` on a host: a page a view presents stands over the window, the page beneath hearing it stopped
/// showing, and one presented in it over it, whatever the window arranges beneath; it closes every way it can, each
/// written onto its state - the user's way back, the application's write, the view presenting it leaving, the sheet
/// holding it closing - by a flag and by a value alike.
@_spi(Host) public enum SheetTests: ConformanceFamily {
    public static let name = "Sheet"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aSheetStandsOverTheWindowAndOneInItOverIt", proves: [
                Covered(SheetContract.self), Covered(SheetContract.isPresented),
            ], needs: [Covered(PageContract.disappearing), Covered(ButtonContract.clicked)]) { s in
                let states = SheetStates()
                states.shows.wrappedValue = false
                states.inner.wrappedValue = false
                states.note.wrappedValue = nil
                s.start { SheetsPage(states: states) }

                try s.perform(.activate, on: s.element("present"))
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("outer")) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("outer")), true, "the sheet shown")
                s.expect(states.log.values.contains("beneath disappearing"), true, "the page beneath stopped showing")

                try s.perform(.activate, on: s.element("presentInner"))
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("inner")) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("inner")), true, "the one in it shown")
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("outer")), true, "over the first")
            },
            ConformanceCase("aSheetStandsOverAPageArrangedBeneathIt", proves: [
                Covered(SheetContract.self),
            ], needs: [Covered(SplitViewContract.self), Covered(NavigationStackContract.self)]) { s in
                let shows = State(wrappedValue: false)
                let (signedIn, path) = (State(wrappedValue: false), State(wrappedValue: [Int]()))
                s.start { ArrangedBeneath(shows: shows, signedIn: signedIn, path: path) }
                @MainActor func sheetReached() throws -> Bool {
                    shows.wrappedValue = true
                    try s.settle { try s.isShown("sheet") }
                    let sheet = try s.element("sheet")
                    // A sheet still entering its window - the platform's presentation - is waited for, not read as
                    // unreachable.
                    try s.settle { try s.reaches(sheet, at: Point(20, 20)) }
                    return try s.reaches(sheet, at: Point(20, 20))
                }

                // A sheet over the first page, taken away; the window arranged anew - a sidebar beside a stack -
                // and the next sheet over it; taken away, a page pushed, and the next over that.
                s.expect(try sheetReached(), true, "a sheet over the first page")
                shows.wrappedValue = false
                s.settle { (try? s.element("sheet")) == nil }
                signedIn.wrappedValue = true
                try s.settle { try s.isShown("inbox") }
                s.expect(try sheetReached(), true, "a sheet over the window arranged since")
                shows.wrappedValue = false
                s.settle { (try? s.element("sheet")) == nil }
                path.wrappedValue = [1]
                try s.settle { try s.isShown("pushed") }
                s.expect(try sheetReached(), true, "a sheet over a page pushed since")
            },
            ConformanceCase("theUsersWayBackClosesTheTopSheetOntoItsState", proves: [
                Covered(SheetContract.isPresented), Covered(SheetContract.isPresentedChanged),
            ], needs: [Covered(PageContract.appearing)]) { s in
                let states = SheetStates()
                s.start { SheetsPage(states: states) }
                let window = try s.element(ofType: WindowContract.nodeType)
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("note")) == true }

                try s.perform(.goBack, on: window)
                s.settle { states.note.wrappedValue == nil }
                s.expect(states.note.wrappedValue, nil, "the value's sheet on top went: nil")
                s.expect(states.shows.wrappedValue, true, "the sheets under it stay")

                try s.perform(.goBack, on: window)
                s.settle { !states.inner.wrappedValue }
                s.expect(states.inner.wrappedValue, false, "the flag's sheet went: false")

                states.log.values = []
                try s.perform(.goBack, on: window)
                s.settle { !states.shows.wrappedValue }
                s.expect(states.shows.wrappedValue, false, "and the last")
                s.settle { states.log.values.contains("beneath appearing") }
                s.expect(states.log.values.contains("beneath appearing"), true, "the page beneath shows again")
            },
            ConformanceCase("theApplicationClosesASheetByItsState", proves: [
                Covered(SheetContract.isPresented),
            ], needs: [Covered(TextContract.self)]) { s in
                let states = SheetStates()
                s.start { SheetsPage(states: states) }
                try s.settle { try s.isShown("note") }

                states.note.wrappedValue = nil
                s.settle { (try? s.element("note")) == nil }
                s.expect((try? s.element("note")) == nil, true, "the value's sheet gone with its value")

                states.shows.wrappedValue = false
                s.settle { (try? s.element("outer")) == nil }
                s.expect((try? s.element("outer")) == nil, true, "the flag's sheet gone with its flag")
            },
            ConformanceCase("aViewLeavingTakesItsSheetAway", proves: [
                Covered(SheetContract.isPresented),
            ], needs: [Covered(TextContract.self)]) { s in
                let states = SheetStates()
                s.start { SheetsPage(states: states) }
                try s.settle { try s.isShown("note") }

                states.presents.wrappedValue = false
                s.settle { (try? s.element("note")) == nil && (try? s.element("outer")) == nil }
                s.expect((try? s.element("outer")) == nil, true, "the sheets gone with the views presenting them")
                s.expect(states.shows.wrappedValue, false, "the flag written false")
                s.expect(states.note.wrappedValue, nil, "the value written nil")
            },
            ConformanceCase("aSheetClosingTakesTheSheetInIt", proves: [
                Covered(SheetContract.isPresented),
            ], needs: [Covered(TextContract.self)]) { s in
                let states = SheetStates()
                states.note.wrappedValue = nil
                s.start { SheetsPage(states: states) }
                try s.settle { try s.isShown("inner") }

                states.shows.wrappedValue = false
                s.settle { (try? s.element("inner")) == nil }
                s.expect((try? s.element("inner")) == nil, true, "the sheet in it gone with it")
                s.expect(states.inner.wrappedValue, false, "its flag written false")
            },
        ]
    }
}

/// What `SheetsPage` presents by, each sheet shown at the start - the outer, the one in it and the value's over them -
/// and what its page beneath heard.
@MainActor
final class SheetStates {
    let presents = State(wrappedValue: true)
    let shows = State(wrappedValue: true)
    let inner = State(wrappedValue: true)
    let note = State<String?>(wrappedValue: "Inbox")
    let log = Received<String>()
}

/// A page presenting a sheet by a flag, one in it by another flag, and beside them one by a value; saying when it
/// shows and when it stops.
struct SheetsPage: View {
    let states: SheetStates

    var body: some View {
        let states = self.states
        return VStack {
            Text("beneath")
            if states.presents.wrappedValue {
                Button("Present")
                    .onClicked { states.shows.wrappedValue = true }
                    .id("present")
                    .sheet(isPresented: states.shows.projectedValue) {
                        VStack {
                            Text("Outer").id("outer")
                            Button("Another")
                                .onClicked { states.inner.wrappedValue = true }
                                .id("presentInner")
                                .sheet(isPresented: states.inner.projectedValue) {
                                    Text("Inner").id("inner")
                                }
                        }
                    }
                Text("Notes")
                    .sheet(item: states.note.projectedValue) { note in
                        Text(note).id("note")
                    }
            }
        }
        .onAppearing { states.log.values.append("beneath appearing") }
        .onDisappearing { states.log.values.append("beneath disappearing") }
    }
}

/// A window of one stack or, once `signedIn`, of a sidebar beside another - the pages `path` lists pushed on it -
/// presenting a sheet while `shows`: each page a box filling it and the sheet a box, all a press can reach.
struct ArrangedBeneath: View {
    let shows: State<Bool>
    let signedIn: State<Bool>
    let path: State<[Int]>

    var body: some View {
        let signedIn = self.signedIn.wrappedValue
        return Group {
            if signedIn {
                SplitView {
                    Text("Sections")
                } detail: {
                    NavigationStack(path.projectedValue) {
                        Rectangle()
                            .fill(Color(hex: 0x0F766E))
                            .id("inbox")
                    } destination: { _ in
                        Rectangle()
                            .fill(Color(hex: 0xC2410C))
                            .id("pushed")
                    }
                }
                .showsSidebar(State(wrappedValue: true).projectedValue)
            } else {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    Rectangle()
                        .fill(Color(hex: 0x374151))
                        .id("first")
                } destination: { _ in
                    Text("Next")
                }
            }
        }
        .sheet(isPresented: shows.projectedValue) {
            Rectangle()
                .fill(Color(hex: 0x512BD4))
                .width(240)
                .height(160)
                .id("sheet")
        }
    }
}
