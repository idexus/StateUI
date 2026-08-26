// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The graph and the wire are DETERMINISTIC, and this is where that is proven.
//
// The claim is exact: the same application, described through the same
// sequence of state changes, produces the same bytes - every run, every
// process, every machine. Not "usually the same", and not "the same modulo
// ordering": byte for byte, so a fixture can be a contract at all and two
// renders can be diffed against each other.
//
// Three things could break it, and there is a test here for each:
//
//   1. ORDER FROM A HASH. Swift seeds Dictionary and Set hashing per PROCESS,
//      so anything that reached the wire by iterating one would write its
//      properties in a different order on the next run. The encoder sorts by
//      name and the differ hands out handler ids in name order; what proves it
//      is `testThePropertyOrderAnAuthorWroteCannotReachTheWire`, which writes
//      one tree twice with its properties inserted in opposite orders.
//   2. ORDER FROM AN ADDRESS. `ObjectIdentifier` is a POINTER, and a sort or a
//      walk over one would be stable within a run and different in the next.
//      Two identical sessions in ONE process allocate different objects, so
//      `testASessionDescribedTwiceWritesTheSameBytes` is what catches that.
//      MEASURED, and it catches more than it was written for: Swift salts each
//      Dictionary's hash table with its own STORAGE ADDRESS, so two dictionaries
//      holding the same pairs, filled the same way, in one process, still
//      iterate differently. Removing the `.sorted()` from the encoder made that
//      test fail on the first message - the two runs numbered the session's
//      names in different orders.
//   3. A NAME NUMBERED TWICE, or used before it was announced. The whole
//      dictionary is per session, so a message that referred to a number
//      nobody had announced would be unreadable to a host that had not seen
//      the earlier message. Decoding the session with a fresh reader is what
//      proves it: an unannounced number traps in `WireNames.resolve`.
//
// The fixtures under `fixtures/sessions/` are the fourth proof and the one
// that crosses a process boundary: they were written by an earlier run, with
// an earlier hash seed, and every run since compares against them.

import StateUIWireProbe
import XCTest
@testable import StateUI

/// An application's tabs, and its routes: the two typed vocabularies the page
/// primitives are steered by.
private enum Tab: Hashable { case home, settings }

private enum Route: Hashable { case detail(String) }

/// A view that READS state, so a session can take the clean walk - the render
/// that builds only what read what changed - and have something to build.
private struct Counter: ContentView {
    @Binding var count: Int

    var content: Element { Label("Count: \(count)").fontSize(20) }
}

private struct HomePage: ContentPage {
    /// Lent rather than read here: what reads it is `Counter`, one level down,
    /// which is what makes the clean walk's answer interesting.
    let count: Binding<Int>

    var title: String? { "Home" }
    var iconImageSource: ImageSource? { ImageSource("home.png") }

    var content: Element {
        VStack {
            Counter(count: count)
            Button("Open").onClicked {}
            Label("themed").textColor(Color(light: .black, dark: .white))
        }
        .spacing(12)
    }
}

private struct DetailPage: ContentPage {
    let name: String

    var title: String? { name }
    var content: Element { Label(name) }
}

private struct SettingsPage: ContentPage {
    var title: String? { "Settings" }
    var iconImageSource: ImageSource? { ImageSource("settings.png") }

    var content: Element {
        VStack {
            Label("Settings").fontAttributes(.bold)
            Switch(true).onToggled { _ in }
        }
    }
}

/// The one window of the deterministic session: tabs over a stack, which is the
/// widest tree these fixtures can hold in one screenful.
private struct DeterminismWindow: Window {
    let tab: Binding<Tab>
    let path: Binding<[Route]>
    let count: Binding<Int>

    var title: String? { "Determinism" }

    var content: Page {
        TabbedPage([Tab.home, .settings]) { which in
            switch which {
            case .home:
                return NavigationPage(path) {
                    HomePage(count: count)
                } destination: { route in
                    switch route {
                    case .detail(let name): DetailPage(name: name)
                    }
                }
                .title("Home")
                .barBackgroundColor(Color.fromArgb("#512BD4"))
                .barTextColor(.white)

            case .settings:
                return SettingsPage()
            }
        }
        .selection(tab)
        .selectedTabColor(.white)
        .unselectedTabColor(Color.fromArgb("#B0A6E0"))
    }
}

final class DeterminismTests: XCTestCase {
    // MARK: - One session, twice

    /// A whole session's worth of messages, from a fresh differ and a fresh
    /// dictionary - the same five steps an application takes: it opens, it
    /// pushes, it changes tab, it pops, and the host loses track.
    ///
    /// Everything it needs is built INSIDE, so two calls share nothing: two
    /// differs, two sets of state boxes, two dictionaries, and two sets of
    /// objects at different addresses.
    private func session() -> [(name: String, bytes: [UInt8])] {
        // The invalidation bookkeeping is the RENDERER's, and a session that
        // takes a clean walk reads it - so it starts from a known state,
        // whatever ran before. A leak between the two runs would show up as
        // two different messages, which is the failure this test is for.
        Renderer.shared.clearInvalidation()

        let differ = Differ()
        let dictionary = WireDictionary()
        var rendered: RenderedNode?
        var messages: [(name: String, bytes: [UInt8])] = []

        let tab = State<Tab>(.home)
        let path = State<[Route]>([])
        let count = State<Int>(0)

        let styles = StyleSheet {
            Style<Label>().fontSize(14).textColor(Color(light: .black, dark: .white))
            Style<Button>().backgroundColor(Color.fromArgb("#512BD4")).textColor(.white)
        }

        // The APPLICATION over the window, which is what a message is rooted
        // in - one window here, the way most applications have one.
        func tree() -> Node {
            Node(type: .application, children: [window()])
        }

        func window() -> Node {
            DeterminismWindow(
                tab: tab.projectedValue,
                path: path.projectedValue,
                count: count.projectedValue).body
        }

        func render(_ name: String, generation: Int32, complete: Bool = false) {
            let result = differ.reconcile(
                rendered, with: tree(), styles: styles, describeAll: complete)
            rendered = result.node
            messages.append((
                name,
                Wire.encode(
                    result.patch,
                    generation: generation,
                    complete: complete,
                    dictionary: dictionary)))
        }

        render("1-opens", generation: 1)

        path.wrappedValue = [.detail("one")]
        render("2-pushes", generation: 2)

        tab.wrappedValue = .settings
        render("3-changes-tab", generation: 3)

        path.wrappedValue = []
        render("4-pops", generation: 4)

        // The CLEAN WALK: nothing is written afresh, and only the views whose
        // recorded reads intersect what changed are built again. It is the path
        // most able to be non-deterministic - it walks what a subtree PROVIDED,
        // what it SAW and what it READ, all of them keyed by object identity -
        // so a session that never took it would be proving the easy half.
        count.wrappedValue += 1

        let walked = differ.revisit(rendered!, changed: Renderer.shared.pendingChanges)
        rendered = walked.node
        messages.append((
            "5-revisits",
            Wire.encode(walked.patch, generation: 5, dictionary: dictionary)))

        // The host lost track: everything again, against the same identities -
        // and the dictionary does NOT start over, a resync renegotiating the
        // tree and never the session's names.
        render("6-resync", generation: 6, complete: true)

        return messages
    }

    /// The claim, at its plainest: run the same session twice and the bytes are
    /// the same.
    ///
    /// The two runs are in ONE process, which is what makes this worth having
    /// beside the fixtures: their objects are at different addresses, so
    /// anything that ordered by `ObjectIdentifier` - a pointer - would write
    /// two different messages here while passing every fixture in a single run.
    func testASessionDescribedTwiceWritesTheSameBytes() {
        let first = session()
        let second = session()

        XCTAssertEqual(first.map(\.name), second.map(\.name))

        for (one, two) in zip(first, second) {
            XCTAssertEqual(
                one.bytes, two.bytes,
                """
                The message '\(one.name)' came out differently the second time \
                the same session was described.

                Something in the render read an order nothing fixes - a \
                Dictionary or Set iterated instead of sorted, or a sort by \
                ObjectIdentifier, which is a pointer. Whatever it is, it makes \
                every fixture in this suite a coin toss.
                """)
        }
    }

    /// And the order the AUTHOR happened to write properties in does not reach
    /// the wire either.
    ///
    /// Two dictionaries holding the same pairs iterate in different orders when
    /// they were filled in different orders - Swift's Dictionary has no order
    /// to promise. So this is the same node twice, filled forwards and
    /// backwards, and the bytes have to match: it is what says the encoder
    /// SORTS rather than merely being lucky.
    func testThePropertyOrderAnAuthorWroteCannotReachTheWire() {
        let props: [(Prop, PropValue)] = [
            (.text, .string("hello")),
            (.fontSize, .number(20)),
            (.textColor, Color.fromArgb("#512BD4").propValue),
            (.backgroundColor, Color.white.propValue),
            (.opacity, .number(0.5)),
            (.margin, .numbers([1, 2, 3, 4])),
            (.padding, .numbers([4, 3, 2, 1])),
            (.widthRequest, .number(120)),
            (.heightRequest, .number(44)),
            (.isVisible, .bool(true)),
            (.rotation, .number(15)),
            (.zIndex, .number(2)),
        ]

        let events: [Event] = [
            .tapped, .isFocusedChanged, .loaded, .unloaded, .frameChanged,
        ]

        func written(_ order: [(Prop, PropValue)], _ handlers: [Event]) -> [UInt8] {
            var node = Node(type: .label)

            for (key, value) in order {
                node.props[key] = value
            }

            for event in handlers {
                node.events[event] = {}
            }

            return Wire.encode(
                Differ().reconcile(nil, with: node).patch,
                generation: 1,
                dictionary: WireDictionary())
        }

        XCTAssertEqual(
            written(props, events),
            written(props.reversed(), events.reversed()),
            """
            One node, written twice with its properties inserted in opposite \
            orders, came out as two different messages.

            A Dictionary's iteration order depends on how it was FILLED and on \
            this process's hash seed. Anything that writes one without sorting \
            it makes the wire depend on both.
            """)
    }

    // MARK: - What the bytes themselves say

    /// Every node's properties and handlers ride in NAME ORDER, which is the
    /// rule that makes the sentence above true rather than accidental - and the
    /// one that makes two messages readably diffable in review.
    func testEveryNodeWritesItsPropertiesInNameOrder() {
        let names = WireNames()

        for message in session() {
            let decoded = WireProbe.decodeMessage(message.bytes, names: names)

            walk(decoded.root) { node in
                XCTAssertEqual(
                    node.props.map(\.key), node.props.map(\.key).sorted(),
                    "\(node.type) wrote its properties out of order in \(message.name)")

                XCTAssertEqual(
                    node.events.map(\.name), node.events.map(\.name).sorted(),
                    "\(node.type) wrote its handlers out of order in \(message.name)")
            }
        }
    }

    /// A name is announced ONCE in a session, by the first message that uses
    /// it, and every later message speaks the number.
    ///
    /// Both halves matter. Announcing one twice would mean two numbers for one
    /// name - a reader could then hold either, and two hosts could disagree.
    /// Announcing one LATE - after a message already used the number - is
    /// unreadable, and is what `WireNames.resolve` traps on while this test
    /// decodes: the decode above is itself the proof of that half.
    func testEveryNameIsAnnouncedExactlyOnceInASession() {
        var announced: [Int: String] = [:]
        var order: [Int] = []

        for message in session() {
            for entry in Self.announcements(in: message.bytes) {
                XCTAssertNil(
                    announced[entry.id],
                    "#\(entry.id) was announced again in \(message.name), as \(entry.name)")

                announced[entry.id] = entry.name
                order.append(entry.id)
            }
        }

        XCTAssertEqual(
            order, Array(1...order.count),
            "the numbers are handed out one after another, so a gap is a name lost")

        XCTAssertEqual(
            Set(announced.values).count, announced.count,
            "and no name was numbered twice under different ids")
    }

    /// The message head, read on its own: the announcements this message
    /// carries, before anything that could refer to them.
    ///
    /// A hand-written reader rather than the probe's, deliberately - the same
    /// reason the C# tests decode a payload by hand. What is being checked is
    /// the LAYOUT, and a second spelling of it is what makes a writer's mistake
    /// a failure instead of two halves agreeing on it.
    private static func announcements(in bytes: [UInt8]) -> [(id: Int, name: String)] {
        var at = 0

        func u8() -> Int {
            defer { at += 1 }
            return Int(bytes[at])
        }

        func u16() -> Int { u8() | u8() << 8 }

        func u32() -> Int { u16() | u16() << 16 }

        XCTAssertEqual(u8(), Int(Wire.version), "the envelope starts with the version")
        _ = u8()                            // complete
        _ = u32()                           // generation

        return (0..<u16()).map { _ in
            let id = u16()
            let length = u32()
            let name = String(decoding: bytes[at..<(at + length)], as: UTF8.self)
            at += length
            return (id: id, name: name)
        }
    }

    /// Every node in a decoded message, itself included.
    private func walk(_ node: WireProbe.WireNode, _ body: (WireProbe.WireNode) -> Void) {
        body(node)

        for child in node.children {
            walk(child, body)
        }
    }

    // MARK: - The contract the C# side reads

    /// The session, written down message by message - the cross-PROCESS proof,
    /// since Swift seeds its hashing per process and these files were written
    /// by a run with a different seed from this one's.
    ///
    /// Its own directory rather than a name each, because what it pins is the
    /// SEQUENCE: the numbering of the names is the session's, and message 4
    /// speaks numbers that message 1 announced. The C# side applies them in
    /// order, to one host, and reads the same tree out twice.
    func testTheSessionIsWrittenDown() throws {
        let names = WireNames()

        for message in session() {
            try Fixtures.check(
                message.bytes,
                sidecar: WireProbe.dumpMessage(message.bytes, names: names),
                against: "sessions/\(message.name)")
        }
    }
}
