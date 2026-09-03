// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The path that describes nothing: a bus the platform moves many times a
// second, and the arithmetic that follows it.
//
// What has to hold, and each of these is one test below: a write records
// nothing and asks for no render; the value is still THERE for whoever reads
// it; a layout that follows one says so in its message, by a bus and a rule
// id; and the rule the id names answers the same placements a render would
// have described.
//
// The mechanism is in Core/Bus.swift; the host's half - which calls the
// rule on the platform's own frames and writes the numbers onto the controls -
// is StateUI.Runtime's Channels.cs.

import XCTest
@testable import StateUI

/// A view that reads a bus, so a test can see that reading one records
/// nothing.
private struct Follower: ContentView {
    let value: Bus<Double>
    let builds: Builds

    var content: Element {
        builds.count += 1
        return label("at \(value.wrappedValue)")
    }
}

/// A view holding a bus of its OWN, so a test can watch the wrapper a second
/// render builds take over the storage the first one made.
private struct Holder: ContentView {
    @Bus var offset = 0.0
    let seen: Seen

    var content: Element {
        seen.numbers.append($offset.bus)
        seen.values.append(offset)
        return label("held")
    }
}

/// A composed view with nothing of its own written on it, so a test can write
/// a bus ON it and look for the registration on the element its body ends at.
private struct Plain: ContentView {
    var content: Element { Label("plain") }
}

/// What each render of the holder saw. A class, for the same reason.
private final class Seen {
    var numbers: [Int32] = []
    var values: [Double] = []
}

/// Counts builds. A class, so the walk that collects state boxes leaves it
/// alone.
private final class Builds {
    var count = 0
}

final class BusTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearBuses()
    }

    // MARK: - The value

    /// Writing one asks for no render and names no change - which is the whole
    /// of what makes it affordable to move with a finger.
    func testWritingABusAsksForNoRender() {
        let value = Bus(wrappedValue: 0.0)

        value.wrappedValue = 40

        XCTAssertEqual(value.wrappedValue, 40)
        XCTAssertFalse(Renderer.shared.needsRender)
        XCTAssertTrue(Renderer.shared.pendingChanges.isEmpty)
    }

    /// And reading one records no dependency, so the view that read it is not
    /// rebuilt when it moves. The trade is the point: a view cannot SHOW one.
    func testReadingOneRecordsNothing() {
        let value = Bus(wrappedValue: 0.0)
        let builds = Builds()
        let renders = Renders()

        renders.render(stack([Follower(value: value, builds: builds).body], id: "root"))
        XCTAssertEqual(builds.count, 1)

        value.wrappedValue = 12
        renders.revisit(changed: Renderer.shared.pendingChanges)

        XCTAssertEqual(builds.count, 1)
    }

    /// The host says where it stands by the number it was issued, and the
    /// value is then what anything reading it sees - a handler asking where
    /// the run is, and the arithmetic itself.
    func testTheHostMovesItByItsBus() {
        let value = Bus(wrappedValue: 0.0)
        let bus = value.bus

        moved(bus, to: 91.5)

        XCTAssertEqual(value.wrappedValue, 91.5)
    }

    /// A value is issued ONE number however often it is asked for it: the host
    /// quotes that number back, and a second one would be a second value.
    func testABusNumberIsIssuedOnce() {
        let value = Bus(wrappedValue: 0.0)

        XCTAssertEqual(value.bus, value.bus)
        XCTAssertNotEqual(value.bus, Bus(wrappedValue: 0.0).bus)
    }

    /// A view is a value REBUILT on every render, and the wrapper is rebuilt
    /// with it - so the storage has to be taken over, or the host would be
    /// moving a value nothing reads. One number and one value across both.
    func testABusRenderedTwiceCarriesOneNumber() {
        let renders = Renders()
        let seen = Seen()

        renders.render(Holder(seen: seen).body)
        renders.render(Holder(seen: seen).body)

        XCTAssertEqual(seen.numbers.count, 2, "the holder was built twice")
        XCTAssertEqual(
            seen.numbers.first, seen.numbers.last,
            "the second wrapper quotes the number the first was issued")
    }

    /// And the VALUE goes with the number: a bus the host moved between two
    /// renders is where the host left it, not where the declaration says.
    func testABusKeepsWhatTheHostWroteAcrossARender() {
        let renders = Renders()
        let seen = Seen()

        renders.render(Holder(seen: seen).body)
        moved(seen.numbers[0], to: 91.5)
        renders.render(Holder(seen: seen).body)

        XCTAssertEqual(seen.values, [0, 91.5])
    }

    // MARK: - What a message says about it

    /// A scroller told to report into a bus says so as a number, and no
    /// handler at all - there is nothing to run on this side.
    /// A BUS WRITTEN ON A COMPOSED VIEW IS ABOUT THAT VIEW, and reaches the
    /// element its body ends at.
    ///
    /// A composed view has no node of its own, so everything written on it is
    /// kept on a placeholder and carried onto what the body built. A
    /// registration left behind there would name a control nothing holds: the
    /// modifier would compile, the property would never be written, and
    /// nothing anywhere would say so.
    func testABusWrittenOnAComposedViewReachesItsElement() {
        let fade = Bus(wrappedValue: AnimatedValue(1.0))
        let renders = Renders()

        let patch = renders.render(Plain().opacity(fade).id("plain").body)

        XCTAssertEqual(
            patch.buses?[.opacity],
            BusEntry(bus: fade.bus, mode: .inOut, kind: .property))
    }

    func testAScrollerNamesTheBusItReportsInto() {
        let value = Bus(wrappedValue: 0.0)

        let node = ScrollView { Label("x") }
            .orientation(.horizontal)
            .scrollX(value)
            .body

        XCTAssertEqual(node.props[.scrollXChannel], .number(Double(value.bus)))
        XCTAssertNil(node.events[.scrollXChanged])
    }

    /// A view whose drag is written into values says both numbers.
    func testADraggedViewNamesTheValuesItIsWrittenInto() {
        let across = Bus(wrappedValue: 0.0)
        let down = Bus(wrappedValue: 0.0)

        let node = BoxView(Color("#000000")).panX(across).panY(down).body

        XCTAssertEqual(node.props[.panXChannel], .number(Double(across.bus)))
        XCTAssertEqual(node.props[.panYChannel], .number(Double(down.bus)))
    }

    // MARK: - The reader

    /// A `ScrollReader` lays an empty scroller over what it holds, as long as
    /// the room plus how far the run goes beyond it, reporting into the
    /// bus.
    func testAScrollReaderReportsIntoItsBus() {
        let across = Bus(wrappedValue: 0.0)
        let renders = Renders()

        let patch = renders.render(
            ScrollReader(across: 540) { Label("under") }
                .scrollX(across)
                .snapInterval(90)
                .id("reader")
                .body)

        func scroller(_ patch: Patch) -> Patch? {
            if patch.type == .scrollView { return patch }

            for child in patch.children {
                if let found = scroller(child) { return found }
            }

            return nil
        }

        let found = scroller(patch)

        XCTAssertEqual(found?.props[.scrollXChannel], .number(Double(across.bus)))
        XCTAssertEqual(found?.props[.snapInterval], .number(90))
        XCTAssertEqual(found?.props[.orientation]?.enumeration, ScrollOrientation.horizontal.rawValue)
    }
}
