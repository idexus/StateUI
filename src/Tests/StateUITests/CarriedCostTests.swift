// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a render COSTS under the carry: a container's content runs when the
// differ descends and not when the author's line constructs it, and a composed
// view built with the same inputs is not built again. These count the builds.

import XCTest
@testable import StateUI

private final class Builds {
    var count = 0
}

/// A composed view over one value, counting its builds.
private struct Inner: ContentView {
    let shown: Int
    let builds: Builds

    var content: any View {
        builds.count += 1
        return VStack { Label("shown \(shown)") }
    }
}

/// A composed view that reads its own state.
private struct Reader: ContentView {
    let builds: Builds
    @State var n = 0

    var content: any View {
        builds.count += 1
        return Label("n\(n)")
    }
}

/// A composed view that reads nothing and shows nothing that moves.
private struct Blank: ContentView {
    let builds: Builds

    var content: any View {
        builds.count += 1
        return Label("blank")
    }
}

final class CarriedCostTests: XCTestCase {
    private struct Page: Element {
        let chosen: Int
        let shown: Int
        let builds: Builds

        var body: Node {
            VStack {
                Label("chosen \(chosen)")
                Grid { Inner(shown: shown, builds: builds) }
            }.body
        }
    }

    func testAContainerBuildsNothingWhenItIsConstructed() {
        let builds = Builds()

        // Constructed, never rendered.
        _ = Grid { Inner(shown: 7, builds: builds) }
        XCTAssertEqual(builds.count, 0, "construction keeps the closure unrun")
    }

    func testAComposedViewBuildsOnceWhileItsInputsHold() {
        let renders = Renders()
        let builds = Builds()

        _ = renders.render(Page(chosen: 1, shown: 7, builds: builds).body)
        _ = renders.render(Page(chosen: 2, shown: 7, builds: builds).body)
        _ = renders.render(Page(chosen: 3, shown: 7, builds: builds).body)
        XCTAssertEqual(
            builds.count, 1,
            "built once; the page and the grid around it were described three times")
    }

    func testWhatACarriedViewWouldSayIsNotSent() {
        let renders = Renders()
        let builds = Builds()

        _ = renders.render(Page(chosen: 1, shown: 7, builds: builds).body)
        let patch = renders.render(Page(chosen: 2, shown: 7, builds: builds).body)
        XCTAssertEqual(
            patch.children.count, 1,
            "only the label outside the carried view travels")
    }

    func testAComposedViewUpdatesWhenItsInputChanges() {
        let renders = Renders()
        let builds = Builds()

        _ = renders.render(Page(chosen: 1, shown: 1, builds: builds).body)
        let patch = renders.render(Page(chosen: 2, shown: 2, builds: builds).body)
        XCTAssertEqual(builds.count, 2, "what it was built with moved, so it was built again")

        // The grid's own child carries the new text.
        let text = patch.children
            .flatMap { $0.children }
            .flatMap { $0.children }
            .compactMap { $0.props[.text] }
        XCTAssertEqual(
            text.first, .string("shown 2"),
            "what the rebuilt view says reaches the wire")
    }

    func testStateInsideAContainerSurvivesRedescription() {
        struct Holder: Element {
            @State private var count = 0
            let bump: Int

            var body: Node {
                Grid {
                    Label("held \(count) bumped \(bump)")
                }.body
            }
        }

        let renders = Renders()
        _ = renders.render(Holder(bump: 1).body)
        let patch = renders.render(Holder(bump: 2).body)
        let text = patch.children.compactMap { $0.props[.text] }
        XCTAssertEqual(
            text.first, .string("held 0 bumped 2"),
            "the state kept its value across a redescription")
    }

    func testAnEnvironmentReachesALazilyDescribedChild() {
        final class Theme: @unchecked Sendable {
            let name: String
            init(_ name: String) { self.name = name }
        }

        // Written the way an application writes views - `content`, not a raw
        // `body` - because that is what gives a view its placeholder, and the
        // placeholder is where `@Environment` is resolved.
        struct Deep: ContentView {
            @Environment var theme: Theme
            var content: any View { Label(theme.name) }
        }

        struct Above: ContentView {
            let theme: Theme
            var content: any View {
                VStack {
                    Grid { Deep() }
                }
                .environment(theme)
            }
        }

        let renders = Renders()
        let patch = renders.render(Above(theme: Theme("dark")).body)
        XCTAssertEqual(
            texts(in: patch).first, .string("dark"),
            "the provider above was in scope where the child was described")
    }

    /// The two halves of the rule, side by side in one container: a view that
    /// READ what moved is built again, and the one beside it - which read
    /// nothing and was built with the same inputs - is carried, although the
    /// container holding both was described again.
    func testOnlyTheReaderIsBuiltWhenAStateMoves() {
        let renders = Renders()
        let reads = Builds(), blanks = Builds()
        let reader = Reader(builds: reads)

        func tree() -> Node {
            Node(type: "VerticalStackLayout", children: [
                VStack {
                    reader
                    Blank(builds: blanks)
                }.id("row").body,
            ])
        }

        renders.render(tree())
        XCTAssertEqual(reads.count, 1)
        XCTAssertEqual(blanks.count, 1)

        reader.n = 7
        let patch = renders.render(tree(), changed: Renderer.shared.pendingChanges)
        XCTAssertEqual(reads.count, 2, "the reader read what moved")
        XCTAssertEqual(blanks.count, 1, "the view beside it read nothing and was built with the same inputs")
        XCTAssertEqual(
            patch.child("row")?.children.first?.props["text"], .string("n7"),
            "and what the reader now says reaches the wire")
    }

    private func texts(in patch: Patch) -> [PropValue] {
        var found: [PropValue] = []

        func walk(_ patch: Patch) {
            if let text = patch.props[.text] { found.append(text) }
            patch.children.forEach(walk)
        }

        walk(patch)
        return found
    }
}
