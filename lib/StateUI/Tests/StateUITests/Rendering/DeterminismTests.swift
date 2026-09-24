// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The graph and the patch are DETERMINISTIC, and this is where that is proven.
//
// The claim is exact: the same application, described through the same
// sequence of state changes, produces the same patches - every run, every
// process, every machine. Not "usually the same": the same identities, handler
// ids, state numbers and orders, so a fixture can be a contract at all and two
// renders can be diffed against each other.
//
// Two things could break it, and there is a test here for each:
//
//   1. ORDER FROM A HASH. Swift seeds Dictionary and Set hashing per PROCESS,
//      so anything that reached a patch by iterating one - a handler id, a
//      child's place - would come out differently on the next run. The differ
//      hands out handler ids in name order; what proves it is
//      `testTheOrderAnAuthorWroteReachesNoHost`, which writes one tree twice
//      with its properties and handlers inserted in opposite orders.
//   2. ORDER FROM AN ADDRESS. `ObjectIdentifier` is a POINTER, and a sort or a
//      walk over one would be stable within a run and different in the next.
//      Two identical sessions in ONE process allocate different objects, so
//      `testASessionDescribedTwiceIsTheSamePatches` is what catches that. It
//      catches more than it was written for: Swift salts each Dictionary's hash
//      table with its own STORAGE ADDRESS, so two dictionaries holding the same
//      pairs, filled the same way, in one process, still iterate differently.
//
// The fixtures under `Fixtures/sessions/` are the third proof and the one that
// crosses a process boundary: they were written by an earlier run, with an
// earlier hash seed, and every run since compares against them.

import XCTest
@_spi(Host) @testable import StateUI

/// An application's tabs, and its routes: the two typed vocabularies the page
/// primitives are steered by.
private enum Tab: Hashable { case home, settings }

private enum Route: Hashable { case detail(String) }

/// A view that READS state, so a session can take the clean walk - the render
/// that builds only what read what changed - and have something to build.
private struct Counter: ContentView {
    @Binding var count: Int

    var content: any View { Label("Count: \(count)").fontSize(20) }
}

/// The stack's root. Every page of the session names itself as it comes into
/// the tree, which is the message that brings it - so the session's messages
/// carry every title a host reads.
private struct HomePage: ContentView {
    @Environment private var page: PageSession

    /// Lent rather than read here: what reads it is `Counter`, one level down,
    /// which is what makes the clean walk's answer interesting.
    let count: Binding<Int>

    var content: any View {
        VStack {
            Counter(count: count)
            Button("Open").onClicked {}
            Label("themed").textColor(Color(light: .black, dark: .white))
        }
        .spacing(12)
        .onCreated {
            page.title = "Home"
            page.icon = ImageSource("home.png")
        }
    }
}

private struct DetailPage: ContentView {
    @Environment private var page: PageSession
    let name: String

    var content: any View { Label(name).onCreated { page.title = name } }
}

private struct SettingsPage: ContentView {
    @Environment private var page: PageSession

    var content: any View {
        VStack {
            Label("Settings").fontAttributes(.bold)
            Switch(true).onToggled { _ in }
        }
        .onCreated {
            page.title = "Settings"
            page.icon = ImageSource("settings.png")
        }
    }
}

/// The one window of the deterministic session: tabs over a stack, which is the
/// widest tree these fixtures can hold in one screenful.
private struct DeterminismWindow: Window {
    let tab: Binding<Tab>
    let path: Binding<[Route]>
    let count: Binding<Int>

    var page: any Page {
        TabbedView([Tab.home, .settings]) { which in
            switch which {
            case .home:
                return NavigationStack(path) {
                    HomePage(count: count)
                } destination: { route in
                    switch route {
                    case .detail(let name): DetailPage(name: name)
                    }
                }
                .title("Home")
                .barBackgroundColor(Color("#512BD4"))
                .barForegroundColor(.white)

            case .settings:
                return SettingsPage()
            }
        }
        .selection(tab.projectedValue)
    }
}

/// One render of the deterministic session: its name and the patch.
struct SessionMessage {
    let name: String
    let patch: HostPatch
}

final class DeterminismTests: XCTestCase {
    // MARK: - One session, twice

    /// A whole session's worth of renders, from a fresh differ - the same six
    /// steps an application takes: it opens, it pushes, it changes tab, it
    /// pops, it rebuilds what read a changed state, and the host loses track.
    ///
    /// Everything it needs is built INSIDE, so two calls share nothing: two
    /// differs, two sets of state boxes, and two sets of objects at different
    /// addresses.
    static func session() -> [SessionMessage] {
        // The invalidation bookkeeping is the RENDERER's, and a session that
        // takes a clean walk reads it - so it starts from a known state,
        // whatever ran before. A leak between the two runs would show up as
        // two different patches, which is the failure this test is for.
        Renderer.shared.clearInvalidation()

        let differ = Differ()
        var rendered: RenderedNode?
        var messages: [SessionMessage] = []

        let tab = State<Tab>(.home)
        let path = State<[Route]>([])
        let count = State<Int>(0)

        let styles = StyleSheet {
            Style<Label>().fontSize(14).textColor(Color(light: .black, dark: .white))
            Style<Button>().background(Color("#512BD4")).textColor(.white)
        }

        // The APPLICATION over its scene and the scene over its window, which is
        // what a render is rooted in - one scene of one window here, the way
        // most applications have one.
        func tree() -> Node {
            var main = window()
            main.id = SceneElement.mainKey

            var scene = Node(type: .scene, children: [main])
            scene.id = "1"

            return Node(type: .application, children: [scene])
        }

        func window() -> Node {
            DeterminismWindow(
                tab: tab.projectedValue,
                path: path.projectedValue,
                count: count.projectedValue).body
        }

        func render(_ name: String, complete: Bool = false) {
            // The walk, then the handlers it found and what they wrote, in one
            // patch - which is how every page's title, written as the page
            // comes into the tree, reaches the host with the page. See
            // `Differ.settling`.
            let result = differ.settling(differ.reconcile(
                rendered, with: tree(), styles: styles, describeAll: complete,
                // THE CHANGES GO WITH THE RENDER, as the renderer passes them on
                // every path: a composed view is carried where nothing it read
                // moved, so a write the walk was never told about would leave the
                // view standing. Taken and cleared, the way the renderer does -
                // the settling passes take them.
                changed: Renderer.shared.pendingChanges))
            rendered = result.node
            messages.append(SessionMessage(name: name, patch: result.patch))
        }

        render("1-opens")

        path.wrappedValue = [.detail("one")]
        render("2-pushes")

        tab.wrappedValue = .settings
        render("3-changes-tab")

        path.wrappedValue = []
        render("4-pops")

        // The CLEAN WALK: nothing is written afresh, and only the views whose
        // recorded reads intersect what changed are built again. It is the path
        // most able to be non-deterministic - it walks what a subtree PROVIDED,
        // what it SAW and what it READ, all of them keyed by object identity -
        // so a session that never took it would be proving the easy half.
        count.wrappedValue += 1

        let walked = differ.revisit(rendered!, changed: Renderer.shared.pendingChanges)
        rendered = walked.node
        messages.append(SessionMessage(name: "5-revisits", patch: walked.patch))

        // The host lost track: everything again, against the same identities.
        render("6-resync", complete: true)

        return messages
    }

    /// The claim, at its plainest: run the same session twice and the patches
    /// are the same.
    ///
    /// The two runs are in ONE process, which is what makes this worth having
    /// beside the fixtures: their objects are at different addresses, so
    /// anything that ordered by `ObjectIdentifier` - a pointer - would give two
    /// different patches here while passing every fixture in a single run.
    func testASessionDescribedTwiceIsTheSamePatches() {
        let first = Self.session()
        let second = Self.session()

        XCTAssertEqual(first.map(\.name), second.map(\.name))

        for (one, two) in zip(first, second) {
            XCTAssertEqual(
                PatchDump.text(one.patch), PatchDump.text(two.patch),
                """
                The patch '\(one.name)' came out differently the second time \
                the same session was described.

                Something in the render read an order nothing fixes - a \
                Dictionary or Set iterated instead of sorted, or a sort by \
                ObjectIdentifier, which is a pointer. Whatever it is, it makes \
                every fixture in this suite a coin toss.
                """)
        }
    }

    /// And the order the AUTHOR happened to write properties and handlers in
    /// reaches no host either.
    ///
    /// Two dictionaries holding the same pairs iterate in different orders when
    /// they were filled in different orders - Swift's Dictionary has no order
    /// to promise. So this is the same node twice, filled forwards and
    /// backwards, and the patches have to match: it is what says the differ
    /// numbers the handlers in name order rather than being lucky.
    func testTheOrderAnAuthorWroteReachesNoHost() {
        let props: [(Prop, PropValue)] = [
            (.text, .string("hello")),
            (.fontSize, .number(20)),
            (.textColor, Color("#512BD4").propValue),
            (.background, Color.white.propValue),
            (.opacity, .number(0.5)),
            (.margin, .numbers([1, 2, 3, 4])),
            (.padding, .numbers([4, 3, 2, 1])),
            (.width, .number(120)),
            (.height, .number(44)),
            (.isVisible, .bool(true)),
            (.rotation, .number(15)),
            (.zIndex, .number(2)),
        ]

        let events: [Event] = [
            .tapped, .isFocusedChanged, .clicked, .toggled, .frameChanged,
        ]

        func written(_ order: [(Prop, PropValue)], _ handlers: [Event]) -> String {
            var node = Node(type: .label)

            for (key, value) in order {
                node.props[key] = value
            }

            for event in handlers {
                node.events[event] = {}
            }

            return PatchDump.text(Differ().reconcile(nil, with: node).patch)
        }

        XCTAssertEqual(
            written(props, events),
            written(props.reversed(), events.reversed()),
            """
            One node, written twice with its properties and handlers inserted \
            in opposite orders, came out as two different patches.

            A Dictionary's iteration order depends on how it was FILLED and on \
            this process's hash seed. Anything that numbers from one without \
            sorting it makes the patch depend on both.
            """)
    }

    /// The properties an element stops describing come in NAME ORDER - the
    /// one list of names a patch carries rather than a map, and one a host
    /// reads as it stands.
    func testClearedPropertiesComeInNameOrder() {
        for message in Self.session() {
            walk(message.patch) { patch in
                XCTAssertEqual(
                    patch.clearedProperties.map(\.name), patch.clearedProperties.map(\.name).sorted(),
                    "\(patch.type.name) cleared its properties out of order in \(message.name)")
            }
        }
    }

    /// Every patch in a render, itself included.
    private func walk(_ patch: HostPatch, _ body: (HostPatch) -> Void) {
        body(patch)

        for child in patch.children {
            walk(child, body)
        }
    }

    // MARK: - The contract a host reads

    /// The session, written down render by render - the cross-PROCESS proof,
    /// since Swift seeds its hashing per process and these files were written
    /// by a run with a different seed from this one's.
    ///
    /// Its own directory rather than a name each, because what it pins is the
    /// SEQUENCE: a host reads the renders in order, as one session.
    func testTheSessionIsWrittenDown() throws {
        for message in Self.session() {
            try Fixtures.check(message.patch, against: "sessions/\(message.name)")
        }
    }
}
