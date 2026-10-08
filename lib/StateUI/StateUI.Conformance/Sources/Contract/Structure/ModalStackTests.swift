// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `ModalStackContract` on a host: a page presented stands over the window, the page beneath hearing it stopped
/// showing; one presented from it stands over it; the user's way back takes the top one away, and the stack hears
/// how many remain.
@_spi(Host) public enum ModalStackTests: ConformanceFamily {
    public static let name = "ModalStack"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPresentedPageStandsOverTheWindow", proves: [
                Covered(ModalStackContract.self), Covered(PageContract.disappearing),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let log = Received<String>()
                let sheets = State(wrappedValue: [Int]())
                s.start { sheetsOver(SheetsPage(sheets: sheets, log: log), sheets) }

                try s.perform(.activate, on: s.element("present"))
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("sheet1")) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("sheet1")), true, "the sheet shown")
                s.expect(log.values.contains("beneath disappearing"), true, "the page beneath stopped showing")

                try s.perform(.activate, on: s.element("another1"))
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("sheet2")) == true }
                s.expect(sheets.wrappedValue, [1, 2], "one over the other")
            },
            ConformanceCase("aSheetStandsOverAPageArrangedBeneathIt", proves: [
                Covered(ModalStackContract.self),
            ], needs: [Covered(SplitViewContract.self), Covered(NavigationStackContract.self)]) { s in
                let sheets = State(wrappedValue: [Int]())
                let (signedIn, path) = (State(wrappedValue: false), State(wrappedValue: [Int]()))
                s.start { ArrangedBeneath(sheets: sheets, signedIn: signedIn, path: path) }
                let shown = { (id: String) in
                    (try? s.element(id)).flatMap { try? s.held(VisualElementContract.isVisible, on: $0) } == true
                }
                @MainActor func sheetReached() throws -> Bool {
                    sheets.wrappedValue = [1]
                    s.settle { shown("sheet") }
                    let sheet = try s.element("sheet")
                    // A sheet still entering its window - the platform's presentation, an iPad's slower - is waited
                    // for, not read as unreachable.
                    s.settle(for: 5) { (try? s.reaches(sheet, at: Point(20, 20))) == true }
                    return try s.reaches(sheet, at: Point(20, 20))
                }

                // A sheet over the first page, taken away; the window arranged anew - a sidebar beside a stack -
                // and the next sheet over it; taken away, a page pushed, and the next over that.
                s.expect(try sheetReached(), true, "a sheet over the first page")
                sheets.wrappedValue = []
                s.settle { (try? s.element("sheet")) == nil }
                signedIn.wrappedValue = true
                s.settle { shown("root") }
                s.expect(try sheetReached(), true, "a sheet over the window arranged since")
                sheets.wrappedValue = []
                s.settle { (try? s.element("sheet")) == nil }
                path.wrappedValue = [1]
                s.settle { shown("pushed") }
                s.expect(try sheetReached(), true, "a sheet over a page pushed since")
            },
            ConformanceCase("theUsersWayBackTakesTheTopPageAway", proves: [
                Covered(ModalStackContract.self), Covered(ModalStackContract.popped), Covered(PageContract.appearing),
            ]) { s in
                let log = Received<String>()
                let sheets = State(wrappedValue: [1, 2])
                s.start { sheetsOver(SheetsPage(sheets: sheets, log: log), sheets) }
                let window = try s.element(ofType: WindowContract.nodeType)
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("sheet2")) == true }

                try s.perform(.goBack, on: window)
                s.settle { sheets.wrappedValue == [1] }
                s.expect(sheets.wrappedValue, [1], "the top one gone")

                log.values = []
                try s.perform(.goBack, on: window)
                s.settle { sheets.wrappedValue.isEmpty }
                s.expect(sheets.wrappedValue, [], "and the last")
                s.settle { log.values.contains("beneath appearing") }
                s.expect(log.values.contains("beneath appearing"), true, "the page beneath shows again")
            },
        ]
    }
}

/// `page` under the numbered sheets `sheets` lists, each able to present the next.
func sheetsOver(_ page: SheetsPage, _ sheets: State<[Int]>) -> ModalStack {
    ModalStack(sheets.projectedValue) {
        page
    } destination: { number in
        VStack {
            Text("On sheet \(number)").id("sheet\(number)")
            Button("Another").onClicked { sheets.wrappedValue.append(number + 1) }.id("another\(number)")
        }
    }
}

/// A window of one page or, once `signedIn`, of a sidebar beside a navigation stack - the pages `path` lists
/// pushed on it - under the sheets `sheets` lists: each page a box filling it and each sheet a box, all a press can
/// reach.
struct ArrangedBeneath: View {
    let sheets: State<[Int]>
    let signedIn: State<Bool>
    let path: State<[Int]>

    var body: some View {
        let signedIn = self.signedIn.wrappedValue
        return ModalStack(sheets.projectedValue) {
            if signedIn {
                SplitView(State(wrappedValue: true).projectedValue) {
                    Text("Sections")
                } detail: {
                    NavigationStack(path.projectedValue) {
                        ColorBox(Color("#0F766E")).id("root")
                    } destination: { _ in
                        ColorBox(Color("#C2410C")).id("pushed")
                    }
                }
            } else {
                ColorBox(Color("#374151")).id("first")
            }
        } destination: { _ in
            ColorBox(Color("#512BD4")).width(240).height(160).id("sheet")
        }
    }
}

/// A page that presents numbered sheets over its window from one state, saying when it shows and when it stops.
struct SheetsPage: View {
    let sheets: State<[Int]>
    let log: Received<String>

    var body: some View {
        let (sheets, log) = (self.sheets, self.log)
        return VStack {
            Text("beneath")
            Button("Present").onClicked { sheets.wrappedValue.append(1) }.id("present")
        }
        .onAppearing { log.values.append("beneath appearing") }
        .onDisappearing { log.values.append("beneath disappearing") }
    }
}
