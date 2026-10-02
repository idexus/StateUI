// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `TitleViewContract` on a host: the view a page declares in its bar in place of its title stands there and takes the
/// user's words; a page pushed over it without one leaves it, and back, it stands there again; the view a stack
/// declares stands on a page declaring none.
@_spi(Host) public enum TitleViewTests: ConformanceFamily {
    public static let name = "TitleView"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPagesTitleViewStandsInItsBar", proves: [Covered(TitleViewContract.self)]) { s in
                let query = State(wrappedValue: "")
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        DeclaringPage(title: TextField(query.projectedValue).id("query"))
                    } destination: { _ in Text("Result") }
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
            ConformanceCase("aStacksTitleViewStandsWhereAPageDeclaresNone", proves: [Covered(TitleViewContract.self)]) { s in
                let path = State(wrappedValue: [Int]())
                s.start {
                    NavigationStack(path.projectedValue) {
                        DeclaringPage(title: Text("Own").id("own"))
                    } destination: { _ in DeclaringPage() }
                    .titleView { Text("Shared").id("shared") }
                }
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("own")) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("own")), true, "the page's own first")

                path.wrappedValue = [1]
                try s.settle { try s.held(VisualElementContract.isVisible, on: s.element("shared")) == true }
                s.expect(try s.held(VisualElementContract.isVisible, on: s.element("shared")), true,
                         "the stack's, on a page declaring none")
            },
        ]
    }
}
