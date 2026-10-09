// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a render COSTS under the carry: a container's content runs when the
// differ descends and not when the author's line constructs it, and a composed
// view built with the same inputs is not built again. These count the builds.

import XCTest
@_spi(Host) @testable import StateUI

private final class Builds {
    var count = 0
}

/// A composed view over one value, counting its builds.
private struct Inner: View {
    let shown: Int
    let builds: Builds

    var body: some View {
        builds.count += 1
        return VStack { Text("shown \(shown)") }
    }
}

/// A composed view that reads its own state.
private struct Reader: View {
    let builds: Builds
    @State var n = 0

    var body: some View {
        builds.count += 1
        return Text("n\(n)")
    }
}

/// A composed view that reads nothing and shows nothing that moves.
private struct Blank: View {
    let builds: Builds

    var body: some View {
        builds.count += 1
        return Text("blank")
    }
}

@MainActor
final class CarriedCostTests: XCTestCase {
    private struct Page: Element {
        let chosen: Int
        let shown: Int
        let builds: Builds

        var node: Node {
            VStack {
                Text("chosen \(chosen)")
                Grid { Inner(shown: shown, builds: builds) }
            }.node
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

        _ = renders.render(Page(chosen: 1, shown: 7, builds: builds).node)
        _ = renders.render(Page(chosen: 2, shown: 7, builds: builds).node)
        _ = renders.render(Page(chosen: 3, shown: 7, builds: builds).node)
        XCTAssertEqual(
            builds.count, 1,
            "built once; the page and the grid around it were described three times")
    }

    func testWhatACarriedViewWouldSayIsNotSent() {
        let renders = Renders()
        let builds = Builds()

        _ = renders.render(Page(chosen: 1, shown: 7, builds: builds).node)
        let patch = renders.render(Page(chosen: 2, shown: 7, builds: builds).node)
        XCTAssertEqual(
            patch.children.count, 1,
            "only the label outside the carried view travels")
    }

    func testAComposedViewUpdatesWhenItsInputChanges() {
        let renders = Renders()
        let builds = Builds()

        _ = renders.render(Page(chosen: 1, shown: 1, builds: builds).node)
        let patch = renders.render(Page(chosen: 2, shown: 2, builds: builds).node)
        XCTAssertEqual(builds.count, 2, "what it was built with moved, so it was built again")

        // The grid's own child carries the new text.
        let text = patch.children
            .flatMap { $0.children }
            .flatMap { $0.children }
            .compactMap { $0.props[.text] }
        XCTAssertEqual(
            text.first, .string("shown 2"),
            "what the rebuilt view says reaches the patch")
    }

    func testStateInsideAContainerSurvivesRedescription() {
        struct Holder: Element {
            @State private var count = 0
            let bump: Int

            var node: Node {
                Grid {
                    Text("held \(count) bumped \(bump)")
                }.node
            }
        }

        let renders = Renders()
        _ = renders.render(Holder(bump: 1).node)
        let patch = renders.render(Holder(bump: 2).node)
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

        // Written the way an application writes views - `body`, not a raw
        // `node` - because that is what gives a view its placeholder, and the
        // placeholder is where `@Environment` is resolved.
        struct Deep: View {
            @Environment var theme: Theme
            var body: some View { Text(theme.name) }
        }

        struct Above: View {
            let theme: Theme
            var body: some View {
                VStack {
                    Grid { Deep() }
                }
                .environment(theme)
            }
        }

        let renders = Renders()
        let patch = renders.render(Above(theme: Theme("dark")).node)
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
            Node(type: "VStack", children: [
                VStack {
                    reader
                    Blank(builds: blanks)
                }.id("row").node,
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
            "and what the reader now says reaches the patch")
    }

    private func texts(in patch: HostPatch) -> [PropValue] {
        var found: [PropValue] = []

        func walk(_ patch: HostPatch) {
            if let text = patch.props[.text] { found.append(text) }
            patch.children.forEach(walk)
        }

        walk(patch)
        return found
    }
}
