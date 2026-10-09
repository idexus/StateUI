// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT AN ELEMENT ATTACHES, AND WHETHER IT GOES WHEN THE ELEMENT DOES.
//
// A view hangs things outside the tree as it is described: a handler in the
// differ's table, an engine on the board, a registration on a state's image, a
// reading on the value it reads, a derived state on the state it is worked out
// from, an aim pointed at the element, a watcher on the platform's frame. Every
// one of them is a way from something that OUTLIVES the render back to the
// page - and one that nothing takes back is a page whose states are never
// freed, every visit leaving another set behind for the board to walk on every
// frame it runs.
//
// So there is a test here for each thing `Node` can carry, and each asks the
// same question in the same shape: describe the view, describe it AWAY - which
// is what navigating off a page is, and what tells the differ to forget the
// element - and then ask whether what it attached was let go.
//
// A test here going red is a leak, and the name says which. What was found by
// writing them: `.samples` kept a ring (the value, its image, the reading, and
// the closure back to the value) and a conversion kept another (the source, its
// derived state, and the conversion pointing back).

import XCTest
@_spi(Host) @testable import StateUI

/// A view that runs one closure of the test's while it is described.
private struct Held: View {
    let read: () -> Void

    init(_ read: @escaping () -> Void = {}) {
        self.read = read
    }

    var body: some View { read(); return Text("held") }
}

/// An object a test provides to a subtree, or hands to a handler to capture.
private final class Carried {}

/// A view counting with a ticker of its own, which it shows the test.
private struct Counting: View {
    @State private var ticker = Ticker(every: .milliseconds(10))
    let seen: (Ticker) -> Void

    var body: some View { seen(ticker); return Text("\(ticker.ticks)") }
}

@MainActor
final class ElementReleaseTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// Describes what `build` writes, then describes it AWAY, and answers
    /// whether the object it returned was let go.
    ///
    /// The second render is the whole instrument: a tree that stops naming a
    /// view is how a page is left, and it is what runs `Differ.forget(_:)`.
    /// Without it a test proves only that nothing holds the object at all,
    /// which is a different and much weaker sentence.
    private func released(_ build: (Renders) -> AnyObject) -> Bool {
        weak var kept: AnyObject?

        do {
            let renders = Renders()
            var made: AnyObject? = build(renders)

            kept = made
            XCTAssertNotNil(kept, "the test built nothing to watch")

            renders.render(stack([], id: "root"))
            made = nil
            _ = made
        }

        return kept == nil
    }

    /// A state a DRIVEN property was read from: the registration holds the
    /// image, and the image is the state's own.
    func testADrivenPropertyGoesWithTheElement() {
        XCTAssertTrue(released { renders in
            let fade = State(1.0)

            renders.render(stack([ColorBox().opacity(fade.projectedValue).node], id: "root"))
            return fade.storage
        })
    }

    /// A state an ENGINE follows. The board holds an armed engine and the
    /// engine holds what it follows, so the element handing its numbers back
    /// at `Differ.forget(_:)` is what ends it.
    func testAnEngineGoesWithTheElement() {
        XCTAssertTrue(released { renders in
            let step = State(0)
            let out = State(0.0)

            renders.render(stack([
                Held().engine(following: step.projectedValue) { _ in out.wrappedValue += 1 }.node,
            ], id: "root"))
            return step.storage
        })
    }

    /// A state a HANDLER captured. The differ keeps handlers by the id the host
    /// quotes them back by, and `forget` takes them out.
    func testAHandlerGoesWithTheElement() {
        XCTAssertTrue(released { renders in
            let taps = State(0)

            renders.render(stack([Button("x").onClicked { taps.wrappedValue += 1 }.node], id: "root"))
            return taps.storage
        })
    }

    /// AND A HANDLER REPLACED ON AN ELEMENT THAT STAYS lets the old one go.
    ///
    /// A closure is written afresh on every render and captures whatever that
    /// render had in hand, so a handler table that only ever grew would hold
    /// every value every render ever captured - a page that stands still and
    /// leaks while nothing about it changes.
    func testAReplacedHandlerLetsTheOldOneGo() {
        weak var first: Carried?

        do {
            let renders = Renders()
            let held = Carried()

            first = held
            renders.render(stack([Button("x").onClicked { _ = held }.node], id: "root"))

            // The same element, described again with a handler that captures
            // something else.
            let other = Carried()
            renders.render(stack([Button("x").onClicked { _ = other }.node], id: "root"))
            _ = other
        }

        XCTAssertNil(first, "the handler table kept the closure the last render replaced")
    }

    /// An object `.environment()` provided, which the element carries so the
    /// clean walk can push the same scope again.
    func testAProvidedObjectGoesWithTheElement() {
        XCTAssertTrue(released { renders in
            let object = Carried()

            renders.render(stack([Held().environment(object).node], id: "root"))
            return object
        })
    }

    /// An aim the differ pointed at the element.
    func testAnAimGoesWithTheElement() {
        XCTAssertTrue(released { renders in
            let aim = Aim(TextField.self)

            renders.render(stack([TextField("").aim(aim).node], id: "root"))
            return aim
        })
    }

    /// A state a FRAME FEED is written into.
    func testAFrameFeedGoesWithTheElement() {
        XCTAssertTrue(released { renders in
            let room = State(Rect(0, 0, 0, 0))

            renders.render(stack([Held().frame(room.projectedValue).node], id: "root"))
            return room.storage
        })
    }

    /// A state a BUILD READ, which the renderer counts the element as a reader
    /// of from `init` to `deinit`.
    func testAStateAViewReadGoesWithTheElement() {
        XCTAssertTrue(released { renders in
            let counter = State(0)

            renders.render(stack([Held { _ = counter.get() }.node], id: "root"))
            return counter.storage
        })
    }

    /// A state a CONVERSION is worked out from. The derived state is kept on
    /// the source so one conversion is one state across renders, and the
    /// conversion knows its sources weakly so the two are not a ring.
    func testAConversionGoesWithTheElement() {
        XCTAssertTrue(released { renders in
            let fade = State(1.0)

            renders.render(stack([
                Text().text(fade.projectedValue.convert { "\($0)" }).node,
            ], id: "root"))
            return fade.storage
        })
    }

    /// The same over SEVERAL states read as one.
    func testAMultiConversionGoesWithTheElement() {
        XCTAssertTrue(released { renders in
            let name = State("a")
            let count = State(1)

            renders.render(stack([
                Text().text(Binding.multi(name.projectedValue, count.projectedValue)
                    .convert { "\($0) \($1)" }).node,
            ], id: "root"))
            return name.storage
        })
    }

    /// A state a READING is taken of. The value's image knows the reading
    /// weakly and the element holds it, so the reading ends with the view.
    func testAReadingGoesWithTheElement() {
        XCTAssertTrue(released { renders in
            let fade = State(1.0)
            let shown = State(1.0)

            renders.render(stack([
                Held { _ = shown.get() }
                    .samples(fade.projectedValue, into: shown.projectedValue, .every(100))
                    .node,
            ], id: "root"))
            return fade.storage
        })
    }

    /// And the state a view DECLARES, which the differ pairs across renders by
    /// the property's own path.
    func testAViewsOwnStateGoesWithIt() {
        XCTAssertTrue(released { renders in
            let seen = Carried()

            renders.render(stack([Held { _ = seen }.node], id: "root"))
            return seen
        })
    }

    /// A RUNNING TICKER a view declares: its loop holds it only through a tick, so it goes with the view's state
    /// and stops, no stop written for it.
    func testAViewsRunningTickerGoesWithIt() {
        XCTAssertTrue(released { renders in
            var made: Ticker?

            renders.render(stack([Counting { made = $0 }.node], id: "root"))
            guard let made else { XCTFail("the view made no ticker"); return Carried() }
            made.start()
            // The render the start asks for takes its write, as the renderer's next turn does.
            Renderer.shared.clearInvalidation()
            return made
        })
    }
}
