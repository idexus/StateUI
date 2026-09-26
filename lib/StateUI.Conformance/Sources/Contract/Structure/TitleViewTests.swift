// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TitleViewContract` on a host: the view a page shows in its bar in place of its title stands there and takes the
/// user's words; a page pushed over it without one leaves it, and back, it stands there again.
@_spi(Host) public enum TitleViewTests: ConformanceFamily {
    public static let name = "TitleView"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPagesTitleViewStandsInItsBar", covers: [Covered(TitleViewContract.self)]) { s in
                let query = State(wrappedValue: "")
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        SessionPage { page, _ in page.titleView = TextField(query.projectedValue).id("query") }
                    } destination: { _ in Label("Result") }
                }
                let field = try s.element("query")
                try s.settle { try s.held(VisualElementContract.isVisible, on: field) == true }

                try s.perform(.type("tea"), on: field)
                s.settle { query.wrappedValue == "tea" }
                s.expect(query.wrappedValue, "tea", "it takes the user's words")

                path.wrappedValue = [1]
                s.settle { (try? s.element("query")).map { (try? s.held(VisualElementContract.isVisible, on: $0)) != true } ?? true }
                path.wrappedValue = []
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("query")) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("query")), true, "back in its bar")
            },
        ]
    }
}
