// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `AnchorContract` on a host: what is written on a view keeping no node of its own stands on its anchor, which has
/// no view - what it holds stands in its place, a stack it holds in a sheet is the sheet's page, and its branch
/// flipping keeps what it presents and what it watches.
@_spi(Host) public enum AnchorTests: ConformanceFamily {
    public static let name = "Anchor"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("whatItHoldsStandsInItsPlace", proves: [
                Covered(AnchorContract.self),
            ], needs: [Covered(VStackContract.self), Covered(TextContract.self)]) { s in
                let states = AnchorStates(shows: false)
                s.start { AnchoredPage(states: states) }

                @MainActor func standsBetween(_ id: String) throws -> Bool {
                    guard try s.isShown(id) else { return false }
                    let (before, shown, after) = (
                        try s.place(of: s.element("before")), try s.place(of: s.element(id)),
                        try s.place(of: s.element("after")))
                    return shown.height > 0 && shown.y >= before.y + before.height - 1
                        && shown.y + shown.height <= after.y + 1
                }
                // The views around it move as the layout places the branch shown: waited for, then read.
                try s.settle { try standsBetween("narrow") }
                s.expect(try standsBetween("narrow"), true, "between the views around it")
                states.wide.wrappedValue = true
                try s.settle { try standsBetween("wide") }
                s.expect(try standsBetween("wide"), true, "the other branch in the same place")
            },
            ConformanceCase("itsBranchFlippingKeepsWhatItPresentsAndWatches", proves: [
                Covered(AnchorContract.self),
            ], needs: [Covered(PresentedElementContract.isPresented, on: SheetContract.self), Covered(TextContract.self)]) { s in
                let states = AnchorStates(shows: true)
                s.start { AnchoredPage(states: states) }
                try s.settle { try s.isShown("sheet") }

                states.wide.wrappedValue = true
                // A watch runs after the walk, on the UI thread's next turn where the host takes one.
                s.settle { (try? s.element("wide")) != nil && states.log.values == ["wide"] }
                s.expect((try? s.element("wide")) != nil, true, "the other branch shown")
                s.expect(states.shows.wrappedValue, true, "the sheet's state left as it was")
                s.expect(try s.isShown("sheet"), true, "the sheet shows on")
                s.expect(states.log.values, ["wide"], "the watch heard the flip")
            },
            ConformanceCase("aStackItHoldsInASheetIsTheSheetsPage", proves: [
                Covered(AnchorContract.self),
            ], needs: [
                Covered(PresentedElementContract.isPresented, on: SheetContract.self), Covered(PageContract.appearing),
                Covered(NavigationStackContract.self), Covered(TextContract.self),
            ]) { s in
                let (shows, wide, log) = (State(wrappedValue: true), State(wrappedValue: false), Received<String>())
                s.start {
                    Text("Beneath").sheet(isPresented: shows.projectedValue) {
                        AnchoredStack(wide: wide.wrappedValue, log: log).onChanged(wide.wrappedValue) {}
                    }
                }
                // A page's root fills the sheet, under its bar too: pressed in its middle.
                @MainActor func reached(_ id: String) throws -> Bool {
                    guard let root = try? s.element(id), let place = try? s.place(of: root) else { return false }
                    return try s.reaches(root, at: Point(place.width / 2, place.height / 2))
                }
                // A sheet still entering its window - the platform's presentation - is waited for.
                try s.settle { try reached("root") }
                s.expect(try reached("root"), true, "the stack's root shows in the sheet, where a press reaches it")
                s.settle { log.values.contains("root appearing") }
                s.expect(log.values.contains("root appearing"), true, "the sheet's page in front: told it appears")

                wide.wrappedValue = true
                try s.settle { try reached("wideRoot") }
                s.expect(try reached("wideRoot"), true, "the other branch's stack in its place")

                try s.perform(.goBack, on: s.element(ofType: WindowContract.nodeType))
                s.settle { !shows.wrappedValue }
                s.expect(shows.wrappedValue, false, "the way back closes the sheet its page stands in")
            },
        ]
    }
}

/// One stack or another, as a composed view builds it, its root saying its phases into `log`: in a sheet, the anchor
/// watching it holds the sheet's page.
struct AnchoredStack: View {
    let wide: Bool
    let log: Received<String>
    @State private var path: [Int] = []

    var body: some View {
        if wide {
            NavigationStack($path) { Text("Wide").id("wideRoot") } destination: { _ in Text("Next") }
        } else {
            NavigationStack($path) {
                Text("Root").id("root").loggingPhases(log, as: "root")
            } destination: { _ in Text("Next") }
        }
    }
}

/// What `AnchoredPage` flips, presents and hears.
@MainActor
final class AnchorStates {
    let wide = State(wrappedValue: false)
    let shows: State<Bool>
    let log = Received<String>()

    init(shows: Bool) {
        self.shows = State(wrappedValue: shows)
    }
}

/// A group of one branch or another between two words, presenting a sheet and watching its flag.
struct AnchoredPage: View {
    let states: AnchorStates

    var body: some View {
        let states = self.states
        return VStack {
            Text("Before").id("before")
            Group {
                if states.wide.wrappedValue {
                    HStack { Text("Wide").id("wide") }.width(160).height(40)
                } else {
                    VStack { Text("Narrow").id("narrow") }.width(80).height(30)
                }
            }
            .sheet(isPresented: states.shows.projectedValue) {
                Text("Sheet").id("sheet")
            }
            .onChanged(states.wide.wrappedValue) { states.log.values.append(states.wide.wrappedValue ? "wide" : "narrow") }
            Text("After").id("after")
        }
        .verticalAlignment(.start)
    }
}
