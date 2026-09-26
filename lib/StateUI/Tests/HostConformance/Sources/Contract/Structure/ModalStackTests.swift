// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `ModalStackContract` on a host: a page presented stands over the window, the page beneath hearing it stopped
/// showing; one presented from it stands over it; the user's way back takes the top one away, and the window hears
/// how many remain.
@_spi(Host) public enum ModalStackTests: ConformanceFamily {
    public static let name = "ModalStack"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPresentedPageStandsOverTheWindow", covers: [
                Covered(ModalStackContract.self), Covered(PageContract.disappearing), Covered(ButtonContract.clicked),
            ]) { s in
                let log = Received<String>()
                let sheets = State(wrappedValue: [Int]())
                s.start { SheetsPage(sheets: sheets, log: log) }

                try s.perform(.activate, on: s.element("present"))
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("sheet1")) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("sheet1")), true, "the sheet shown")
                s.expect(log.values.contains("beneath disappearing"), true, "the page beneath stopped showing")

                try s.perform(.activate, on: s.element("another1"))
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("sheet2")) == true }
                s.expect(sheets.wrappedValue, [1, 2], "one over the other")
            },
            ConformanceCase("theUsersWayBackTakesTheTopPageAway", covers: [
                Covered(ModalStackContract.self), Covered(WindowContract.modalPopped), Covered(PageContract.appearing),
            ]) { s in
                let log = Received<String>()
                let sheets = State(wrappedValue: [1, 2])
                s.start { SheetsPage(sheets: sheets, log: log) }
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

/// A page that presents numbered sheets over its window from one state, each able to present the next.
struct SheetsPage: ContentView {
    let sheets: State<[Int]>
    let log: Received<String>

    @Environment private var window: WindowSession
    @Environment private var page: PageSession

    var content: any View {
        let (sheets, log, window, page) = (self.sheets, self.log, self.window, self.page)
        return VStack {
            Label("beneath")
            Button("Present").onClicked { sheets.wrappedValue.append(1) }.id("present")
        }
        .onCreated {
            window.modalStack = ModalStack(sheets.projectedValue) { number in
                VStack {
                    Label("On sheet \(number)").id("sheet\(number)")
                    Button("Another").onClicked { sheets.wrappedValue.append(number + 1) }.id("another\(number)")
                }
            }
        }
        .onChanged(page.phase) { log.values.append("beneath \(page.phase)") }
    }
}
