// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `RefreshElementContract` on a host: the pull offered where it is heard, heard once and landing on the state,
/// the spinner ended by the application; what the application writes heard by nobody. Each case made for every
/// element wearing the tier.
@_spi(Host) public enum RefreshElementTests: ConformanceFamily {
    public static let name = "RefreshElement"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(RefreshElementContract.self).flatMap { element in
            [pulled(element), shown(element), unended(element), withheld(element)]
        }
    }

    /// The pull is offered where it is heard; it lands on the state before its handler hears it, the spinner shows
    /// until the application ends it, and the end is heard by nobody.
    @MainActor
    static func pulled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPullIsHeardOnceAndTheApplicationEndsIt", proves: [
            Covered(RefreshElementContract.isRefreshing, on: element),
            Covered(RefreshElementContract.refreshRequested, on: element),
            Covered(RefreshElementContract.isRefreshEnabled, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let refreshing = State(wrappedValue: false)
            let heard = Received<Bool>()
            s.start {
                VStack {
                    specimen(element, Pull(refreshing: refreshing.projectedValue) {
                        heard.values.append(refreshing.wrappedValue)
                    })
                    Button("Done").onClicked { refreshing.wrappedValue = false }.id("done")
                }
            }
            let view = try s.element("specimen")
            s.expect(try s.held(RefreshElementContract.isRefreshEnabled, on: view), true, "the heard pull offered")
            s.expect(try s.held(RefreshElementContract.isRefreshing, on: view), false)

            try s.perform(.pullToRefresh, on: view)
            s.settle { !heard.values.isEmpty }

            s.expect(heard.values, [true], "the pull heard once, on the state already")
            s.expect(try s.held(RefreshElementContract.isRefreshing, on: view), true, "the spinner showing")
            try s.perform(.activate, on: s.element("done"))
            try s.settle { try s.held(RefreshElementContract.isRefreshing, on: view) == false }
            s.expect(try s.held(RefreshElementContract.isRefreshing, on: view), false, "the application ended it")
            s.turn()
            s.expect(heard.values, [true], "and nobody heard the end as a pull")
        }
    }

    /// A refresh the application begins shows the spinner, and nobody hears it as the user's pull.
    @MainActor
    static func shown(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).theApplicationsRefreshShowsUnheard", proves: [
            Covered(RefreshElementContract.isRefreshing, on: element),
        ], needs: [Covered(ButtonContract.clicked), Covered(RefreshElementContract.refreshRequested, on: element)]) { s in
            let refreshing = State(wrappedValue: false)
            let heard = Received<Bool>()
            s.start {
                VStack {
                    specimen(element, Pull(refreshing: refreshing.projectedValue) { heard.values.append(true) })
                    Button("Begin").onClicked { refreshing.wrappedValue = true }.id("begin")
                    Button("Done").onClicked { refreshing.wrappedValue = false }.id("done")
                }
            }
            let view = try s.element("specimen")

            try s.perform(.activate, on: s.element("begin"))
            try s.settle { try s.held(RefreshElementContract.isRefreshing, on: view) == true }
            s.expect(try s.held(RefreshElementContract.isRefreshing, on: view), true, "the spinner the application began")
            try s.perform(.activate, on: s.element("done"))
            try s.settle { try s.held(RefreshElementContract.isRefreshing, on: view) == false }
            s.expect(try s.held(RefreshElementContract.isRefreshing, on: view), false, "and ended")
            s.turn()
            s.expect(heard.values, [], "nobody heard either as a pull")
        }
    }

    /// A pull nothing would end - no state carries `isRefreshing` - is heard, and its spinner goes at once.
    @MainActor
    static func unended(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aPullNothingEndsShowsNoSpinner", proves: [
            Covered(RefreshElementContract.refreshRequested, on: element),
            Covered(RefreshElementContract.isRefreshing, on: element),
        ]) { s in
            let heard = Received<Bool>()
            s.start { VStack { specimen(element, Pull { heard.values.append(true) }) } }
            let view = try s.element("specimen")

            try s.perform(.pullToRefresh, on: view)
            s.settle { !heard.values.isEmpty }
            try s.settle { try s.held(RefreshElementContract.isRefreshing, on: view) == false }

            s.expect(heard.values, [true], "the pull heard once")
            s.expect(try s.held(RefreshElementContract.isRefreshing, on: view), false, "its spinner gone")
        }
    }

    /// The pull is not offered where nothing hears it, nor where the element withholds it; offered again as the
    /// application lets it.
    @MainActor
    static func withheld(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).aWithheldPullIsNotOffered", proves: [
            Covered(RefreshElementContract.isRefreshEnabled, on: element),
        ], needs: [Covered(ButtonContract.clicked), Covered(RefreshElementContract.refreshRequested, on: element)]) { s in
            let enabled = State(wrappedValue: false)
            s.start {
                VStack {
                    specimen(element, Pull(enabled: enabled.projectedValue) {})
                    specimen(element, id: "unheard", Pull())
                    Button("Let").onClicked { enabled.wrappedValue = true }.id("let")
                }
            }
            let view = try s.element("specimen")
            s.expect(try s.held(RefreshElementContract.isRefreshEnabled, on: view), false, "withheld")
            s.expect(try s.held(RefreshElementContract.isRefreshEnabled, on: s.element("unheard")), false,
                "heard by nothing")

            try s.perform(.activate, on: s.element("let"))
            try s.settle { try s.held(RefreshElementContract.isRefreshEnabled, on: view) == true }
            s.expect(try s.held(RefreshElementContract.isRefreshEnabled, on: view), true, "let again")
        }
    }

    /// `element` - a scroller of lines, or a list of them - wearing `pull`, found by `id`.
    @MainActor
    static func specimen(_ element: String, id: String = "specimen", _ pull: Pull) -> ModifiedContent {
        let worn = element == "ItemsView"
            ? pull.worn(by: ItemsView(0..<20) { Text("Item \($0)") })
            : pull.worn(by: ScrollView { VStack { ForEach(0..<20) { Text("Line \($0)") } } })
        return worn.width(240).height(160).id(id)
    }
}

/// What a specimen wears of the pull: the state its spinner follows, the state offering it, and what hears it.
@MainActor
struct Pull {
    var refreshing: Binding<Bool>?
    var enabled: Binding<Bool>?
    var heard: (@MainActor () -> Void)?

    init(refreshing: Binding<Bool>? = nil, enabled: Binding<Bool>? = nil, heard: (@MainActor () -> Void)? = nil) {
        self.refreshing = refreshing
        self.enabled = enabled
        self.heard = heard
    }

    /// `element` wearing it.
    func worn<Element: Pulled>(by element: Element) -> ModifiedContent {
        var element = element
        if let refreshing { element = element.isRefreshing(refreshing) }
        if let enabled { element = element.isRefreshEnabled(enabled) }
        if let heard { element = element.onRefreshRequested(heard) }
        return ModifiedContent(node: element.node)
    }
}

/// The pull's modifiers, as a scroller and a list each give them.
@MainActor
protocol Pulled: View {
    func isRefreshing(_ state: Binding<Bool>) -> Self
    func isRefreshEnabled(_ state: Binding<Bool>) -> Self
    func onRefreshRequested(_ handler: @escaping @MainActor () throws -> Void) -> Self
}

extension ScrollView: Pulled {}
extension ItemsView: Pulled {}
