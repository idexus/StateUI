// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The path that describes nothing: a channel the platform moves many times a
// second, and the arithmetic that follows it.
//
// What has to hold, and each of these is one test below: a write records
// nothing and asks for no render; the value is still THERE for whoever reads
// it; a layout that follows one says so in its message, by a channel and a
// rule id; and the rule the id names answers the same placements a render
// would have described.
//
// The mechanism is in Core/Channel.swift; the host's half - which calls the
// rule on the platform's own frames and writes the numbers onto the controls -
// is StateUI.Runtime's Channels.cs.

import XCTest
@testable import StateUI

/// A view that reads a channel, so a test can see that reading one records
/// nothing.
private struct Follower: ContentView {
    let value: Channel<Double>
    let builds: Builds

    var content: Element {
        builds.count += 1
        return label("at \(value.wrappedValue)")
    }
}

/// Counts builds. A class, so the walk that collects state boxes leaves it
/// alone.
private final class Builds {
    var count = 0
}

final class ChannelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearChannels()
    }

    // MARK: - The value

    /// Writing one asks for no render and names no change - which is the whole
    /// of what makes it affordable to move with a finger.
    func testWritingAChannelAsksForNoRender() {
        let value = Channel(wrappedValue: 0.0)

        value.wrappedValue = 40

        XCTAssertEqual(value.wrappedValue, 40)
        XCTAssertFalse(Renderer.shared.needsRender)
        XCTAssertTrue(Renderer.shared.pendingChanges.isEmpty)
    }

    /// And reading one records no dependency, so the view that read it is not
    /// rebuilt when it moves. The trade is the point: a view cannot SHOW one.
    func testReadingOneRecordsNothing() {
        let value = Channel(wrappedValue: 0.0)
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
    func testTheHostMovesItByItsChannel() {
        let value = Channel(wrappedValue: 0.0)
        let channel = value.channel

        Renderer.shared.moved(channel, to: 91.5)

        XCTAssertEqual(value.wrappedValue, 91.5)
    }

    /// A value is issued ONE number however often it is asked for it: the host
    /// quotes that number back, and a second one would be a second value.
    func testAChannelIsIssuedOnce() {
        let value = Channel(wrappedValue: 0.0)

        XCTAssertEqual(value.channel, value.channel)
        XCTAssertNotEqual(value.channel, Channel(wrappedValue: 0.0).channel)
    }

    // MARK: - What a message says about it

    /// A scroller told to report into a channel says so as a number, and no
    /// handler at all - there is nothing to run on this side.
    func testAScrollerNamesTheChannelItReportsInto() {
        let value = Channel(wrappedValue: 0.0)

        let node = ScrollView { Label("x") }
            .orientation(.horizontal)
            .scrollX(value)
            .body

        XCTAssertEqual(node.props[.scrollXChannel], .number(Double(value.channel)))
        XCTAssertNil(node.events[.scrollXChanged])
    }

    /// A view whose drag is written into values says both numbers.
    func testADraggedViewNamesTheValuesItIsWrittenInto() {
        let across = Channel(wrappedValue: 0.0)
        let down = Channel(wrappedValue: 0.0)

        let node = BoxView(Color("#000000")).panX(across).panY(down).body

        XCTAssertEqual(node.props[.panXChannel], .number(Double(across.channel)))
        XCTAssertEqual(node.props[.panYChannel], .number(Double(down.channel)))
    }

    /// A layout that follows channels carries their numbers AND an id for the
    /// arithmetic - the closure itself never leaves this side.
    func testAFollowingLayoutCarriesItsChannelsAndItsRule() {
        let across = Channel(wrappedValue: 0.0)
        let turn = Channel(wrappedValue: 0.0)
        let renders = Renders()

        func tree() -> Node {
            PlacedLayout([1, 2], id: \.self, following: across, turn, at: { index, _, _ in
                Placement(Rect(Double(index) * 10 + across.wrappedValue, 0, 20, 20))
            }) { number in
                Label("\(number)")
            }
            .id("run")
            .body
        }

        // The room is measured before anything can be placed in it, so the
        // layout itself is one frame late - exactly as it is without this.
        var patch = renders.render(tree())

        func reader(_ patch: Patch) -> Int? {
            if let id = patch.events?[.frameChanged] { return id }

            for child in patch.children where reader(child) != nil {
                return reader(child)
            }

            return nil
        }

        XCTAssertTrue(renders.fire(
            reader(patch) ?? -1, with: [.numbers([0, 0, 300, 100, 0, 0, 0, 0])]))

        patch = renders.renderFromScratch(tree())

        func layout(_ patch: Patch) -> Patch? {
            if patch.type == .absoluteLayout { return patch }

            for child in patch.children {
                if let found = layout(child) { return found }
            }

            return nil
        }

        let placed = try? XCTUnwrap(layout(patch))

        XCTAssertEqual(
            placed?.props[.channels],
            .numbers([Double(across.channel), Double(turn.channel)]))

        guard case .number(let rule)? = placed?.props[.channelRule] else {
            return XCTFail("the layout carries no rule id")
        }

        // AND THE ID NAMES THE ARITHMETIC, which is what the host calls on its
        // own frames. The same closure a render used: moving the value and
        // asking again answers the cards somewhere else, with nothing built.
        let arithmetic = try? XCTUnwrap(renders.placement(Int(rule)))

        XCTAssertEqual(arithmetic?(1, 2, Rect(0, 0, 300, 100)).bounds, Rect(10, 0, 20, 20))

        Renderer.shared.moved(across.channel, to: 25)

        XCTAssertEqual(arithmetic?(1, 2, Rect(0, 0, 300, 100)).bounds, Rect(35, 0, 20, 20))
    }

    /// The shade is a NUMBER to the host, and its absence is a number too: a
    /// layout with no shade view answers `unshaded`, which is the one value an
    /// opacity cannot be, and a layout with one answers what its arithmetic
    /// said. Without that the host could not tell a card wearing NONE of a
    /// shade from a run that has no shade at all, both of which say nought.
    func testAShadeSaysWhetherThereIsOneAtAll() {
        let across = Channel(wrappedValue: 0.0)

        func rule(_ shaded: Bool) -> PlacementRule? {
            let renders = Renders()

            var run = PlacedLayout([1, 2], id: \.self, following: across, at: { index, _, _ in
                Placement(Rect(0, 0, 20, 20), shade: Double(index) * 0.5)
            }) { number in
                Label("\(number)")
            }

            if shaded {
                run = run.shade(BoxView(Color("#000000")))
            }

            let patch = renders.render(run.id("run").body)

            func layout(_ patch: Patch) -> Patch? {
                if patch.type == .absoluteLayout { return patch }

                for child in patch.children {
                    if let found = layout(child) { return found }
                }

                return nil
            }

            // The room is measured before anything is placed in it, so the
            // first render carries the reader rather than the layout.
            func reader(_ patch: Patch) -> Int? {
                if let id = patch.events?[.frameChanged] { return id }

                for child in patch.children where reader(child) != nil {
                    return reader(child)
                }

                return nil
            }

            XCTAssertTrue(renders.fire(
                reader(patch) ?? -1, with: [.numbers([0, 0, 300, 100, 0, 0, 0, 0])]))

            let settled = renders.renderFromScratch(run.id("run").body)

            guard case .number(let id)? = layout(settled)?.props[.channelRule] else {
                XCTFail("the layout carries no rule id")
                return nil
            }

            return renders.placement(Int(id))
        }

        let room = Rect(0, 0, 300, 100)

        XCTAssertEqual(rule(false)?(1, 2, room).shade, PackedPlacement.unshaded, """
            a layout with no shade view says so in the one number an opacity \
            cannot be, whatever its arithmetic answered
            """)

        XCTAssertEqual(rule(true)?(0, 2, room).shade, 0, """
            a card wearing none of a shade the layout HAS says nought, which is \
            an opacity like any other
            """)

        XCTAssertEqual(rule(true)?(1, 2, room).shade, 0.5)
    }

    /// A shaded layout places a GRID whose second child is the shade, wearing
    /// the opacity the arithmetic answered - which is what the host writes onto
    /// between renders, and what the tree draws before it ever does.
    func testAShadedLayoutDrawsTheShadeOverEachPlacedView() {
        let renders = Renders()

        let run = PlacedLayout([1, 2], id: \.self, at: { index, _, _ in
            Placement(Rect(0, 0, 20, 20), opacity: 0.9, shade: Double(index) * 0.4)
        }) { number in
            Label("\(number)")
        }
        .shade(BoxView(Color("#000000")))

        let patch = renders.render(run.id("run").body)

        func layout(_ patch: Patch) -> Patch? {
            if patch.type == .absoluteLayout { return patch }

            for child in patch.children {
                if let found = layout(child) { return found }
            }

            return nil
        }

        func reader(_ patch: Patch) -> Int? {
            if let id = patch.events?[.frameChanged] { return id }

            for child in patch.children where reader(child) != nil {
                return reader(child)
            }

            return nil
        }

        XCTAssertTrue(renders.fire(
            reader(patch) ?? -1, with: [.numbers([0, 0, 300, 100, 0, 0, 0, 0])]))

        let settled = renders.renderFromScratch(run.id("run").body)

        guard let placed = layout(settled),
              let first = placed.children.first,
              let near = first.children.last,
              let last = placed.children.last,
              let far = last.children.last
        else {
            return XCTFail("the run placed no views")
        }

        XCTAssertEqual(first.type, .grid, """
            a shaded layout places a grid of two - the view and the shade over \
            it - because the placement goes on one node and the shade's own \
            opacity on another
            """)
        XCTAssertEqual(first.children.count, 2)
        XCTAssertEqual(first.props[.opacity], .number(0.9), "the placement's own fade")
        XCTAssertEqual(near.props[.opacity], .number(0))
        XCTAssertEqual(far.props[.opacity], .number(0.4), "the far view wears more of the shade")
    }

    /// A layout given no value to follow says neither, so nothing on the far
    /// side has anything to call.
    func testALayoutFollowingNothingSaysNothing() {
        let node = following(AbsoluteLayout { Label("x") }, [], nil)

        XCTAssertNil(node.props[.channels])
        XCTAssertNil(node.placing)
    }

    // MARK: - The reader

    /// A `ScrollReader` lays an empty scroller over what it holds, as long as
    /// the room plus how far the run goes beyond it, reporting into the
    /// channel.
    func testAScrollReaderReportsIntoItsChannel() {
        let across = Channel(wrappedValue: 0.0)
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

        XCTAssertEqual(found?.props[.scrollXChannel], .number(Double(across.channel)))
        XCTAssertEqual(found?.props[.snapInterval], .number(90))
        XCTAssertEqual(found?.props[.orientation]?.enumeration, ScrollOrientation.horizontal.rawValue)
    }
}
