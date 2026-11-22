// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A view kept as it leaves: no more the application's at once, drawn on by the exit its transition declares where
/// what holds it keeps one, released as that ends - and gone at once wherever nothing keeps it.
/// Design: docs/design/host/tree.md#a-view-kept-as-it-leaves
@MainActor
final class StructuralTransitionsTests: XCTestCase {
    private static let fading = Transition(enter: .identity, exit: .opacity.combined(with: .translation(y: 12)))

    /// A runtime on a clock wound by hand whose application moves by `motion`, every view keeping a child that
    /// left where `keeps`, and how each kept exit ended.
    @MainActor
    private final class Bench {
        let clock = WoundClock()
        let runtime: HostRuntime
        var ended: [(id: ElementID, result: PresentationOperation.Result)] = []

        init(
            keeps: Bool = true, reducesMotion: Bool = false, motion: Motion = .eased(.milliseconds(200), curve: .linear)
        ) {
            runtime = HostRuntime(
                clock: clock, reducesMotion: { reducesMotion },
                makeNative: { _ in
                    let view = NoView()
                    view.keepsExits = keeps
                    return view
                },
                log: { _ in })
            runtime.layoutMotion.applicationMotion = motion
            runtime.tree.exits.onEnded = { [unowned self] element, result in ended.append((element.id, result)) }
        }

        var root: MountedElement { runtime.tree.root! }

        /// A text of `id`, exiting by `transition` where one is given.
        static func text(_ id: String, _ transition: Transition? = nil) -> HostPatch {
            var patch = HostPatch(id: .manual(id), type: .text)
            if let transition { patch.properties = [.transition: transition.propValue] }
            return patch
        }

        /// The root stack holding `children`, said whole or as a patch.
        func show(_ children: [HostPatch], complete: Bool = false) {
            var root = HostPatch(id: .manual("root"), type: .vStack)
            root.children = .arranged(children)
            runtime.tree.apply(root, complete: complete)
        }

        func frame(at time: Double) {
            clock.time = time
            runtime.displayCycle.frame(now: time)
        }

        func shown(_ property: Prop, of element: MountedElement) -> Double? {
            runtime.tree.presentedPropertyValue(mount: element.mount, property: property)?.number
        }

        func ids(_ elements: [MountedElement]) -> [String] { elements.map { "\($0.id)" } }
    }

    private func view(_ element: MountedElement) -> NoView { element.native as! NoView }

    /// A CHILD THAT EXITS IS THE APPLICATION'S NO MORE AT ONCE, AND DRAWN UNTIL ITS EXIT LANDS: out of its parent's
    /// children, among its presented ones, its numbers on their way to the effect - then released, and its holder
    /// arranged without it.
    func testAChildThatExitsIsKeptUntilItsExitLands() {
        let bench = Bench()
        bench.show([Bench.text("a"), Bench.text("b", Self.fading)], complete: true)
        let (a, b) = (bench.root.children[0], bench.root.children[1])
        let arranged = view(bench.root).arranged

        bench.show([Bench.text("a")])
        XCTAssertEqual(b.lifecycle, .exiting)
        XCTAssertEqual(view(b).deactivated, 1, "deaf and detached at once")
        XCTAssertTrue(bench.root.children.elementsEqual([a], by: ===), "measured and laid out without it")
        XCTAssertTrue(bench.root.presentedChildren.elementsEqual([a, b], by: ===), "drawn where it stood")
        XCTAssertEqual(bench.runtime.tree.exits.count, 1)

        bench.frame(at: 100)
        XCTAssertEqual(bench.shown(.opacity, of: b) ?? .nan, 0.5, accuracy: 0.001, "half way out")
        XCTAssertEqual(bench.shown(.translationY, of: b) ?? .nan, 6, accuracy: 0.001)
        XCTAssertEqual(b.lifecycle, .exiting)

        bench.frame(at: 200)
        XCTAssertEqual(b.lifecycle, .released)
        XCTAssertTrue(bench.root.presentedChildren.elementsEqual([a], by: ===))
        XCTAssertEqual(bench.runtime.tree.exits.count, 0)
        XCTAssertEqual(bench.ended.map(\.result), [.finished])
        XCTAssertGreaterThan(view(bench.root).arranged, arranged, "what kept it arranges its views without it")
        let once = view(bench.root).arranged

        bench.frame(at: 400)
        XCTAssertEqual(view(bench.root).arranged, once, "and never again for it")
        XCTAssertEqual(bench.ended.count, 1)
    }

    /// A VIEW KEPT AS IT LEAVES IGNORES INPUT AND IS MET BY NO ASSISTIVE TECHNOLOGY, with everything in it, for as
    /// long as it is drawn - what a host reads as it finds the view leaving - while the view beside it stands as
    /// it did.
    func testAViewKeptAsItLeavesIgnoresInputAndIsMetNoMore() {
        let bench = Bench()
        bench.show([Bench.text("a"), Bench.text("b", Self.fading)], complete: true)
        let (a, b) = (bench.root.children[0], bench.root.children[1])
        XCTAssertFalse(b.ignoresInput)
        XCTAssertEqual(b.accessibilityWords.presence, a.accessibilityWords.presence, "standing, as any view")

        bench.show([Bench.text("a")])
        bench.frame(at: 100)
        XCTAssertEqual(b.lifecycle, .exiting)
        XCTAssertTrue(b.ignoresInput, "deaf to input while it is drawn")
        XCTAssertEqual(b.accessibilityWords.presence, .hiddenWithContents, "and met no more")
        XCTAssertFalse(a.ignoresInput)
        XCTAssertNotEqual(a.accessibilityWords.presence, .hiddenWithContents)
    }

    /// A VIEW KEPT AS IT LEAVES SAYS, WITH EVERYTHING UNDER IT, THAT IT STAYS DRAWN, and each is told once that
    /// nothing of it is drawn any more, as the exit lands; a view gone at once says neither.
    func testAKeptViewStaysDrawnUntilItsPresentationIsReleased() {
        let bench = Bench()
        var card = HostPatch(id: .manual("card"), type: .vStack)
        card.properties = [.transition: Self.fading.propValue]
        card.children = .arranged([Bench.text("words")])
        bench.show([Bench.text("a"), card, Bench.text("plain")], complete: true)
        let (kept, plain) = (bench.root.children[1], bench.root.children[2])
        let leaving = [kept, kept.children[0], plain]

        bench.show([Bench.text("a")])
        XCTAssertEqual(leaving.map(\.staysDrawn), [true, true, false])
        XCTAssertEqual(leaving.map { view($0).released }, [0, 0, 0], "drawn on, and one gone at once is told nothing")

        bench.frame(at: 200)
        XCTAssertEqual(leaving.map { view($0).released }, [1, 1, 0], "the exit landed")
        bench.frame(at: 400)
        XCTAssertEqual(leaving.map { view($0).released }, [1, 1, 0], "once")
    }

    /// A NUMBER OF AN EXIT THAT LANDED STANDS AT ITS END until the view is released: a spring brings a fade home
    /// sooner than a move, and while the move still travels the view is not drawn as it was declared again.
    func testANumberOfAnExitThatLandedStandsAtItsEnd() {
        let bench = Bench(motion: .spring(response: .milliseconds(300), damping: 1))
        bench.show([Bench.text("a"), Bench.text("b", Self.fading)], complete: true)
        let b = bench.root.children[1]
        bench.show([Bench.text("a")])

        var time = 0.0
        while bench.shown(.opacity, of: b) != nil, time < KeptExits.timeLimit {
            time += 16
            bench.frame(at: time)
        }
        XCTAssertEqual(b.lifecycle, .exiting, "the fade is home, the move still travels")
        XCTAssertNotNil(bench.shown(.translationY, of: b))
        XCTAssertEqual(b.number(.opacity), 0, "and the fade stands where it landed")

        while b.lifecycle == .exiting, time < KeptExits.timeLimit {
            XCTAssertEqual(b.number(.opacity), 0, "at \(time) ms")
            time += 16
            bench.frame(at: time)
        }
        XCTAssertEqual(bench.ended.map(\.result), [.finished])
    }

    /// WHERE NOTHING KEEPS IT, A CHILD LEAVES AT ONCE: a view keeping none, no transition, an exit that changes
    /// nothing, less motion, and nothing to move by.
    func testWhereNothingKeepsItAChildLeavesAtOnce() {
        let still = Transition(enter: .opacity, exit: .identity)
        let cases: [(String, Bench, Transition?)] = [
            ("a view that keeps none", Bench(keeps: false), Self.fading),
            ("no transition", Bench(), nil),
            ("an exit that changes nothing", Bench(), still),
            ("less motion", Bench(reducesMotion: true), Self.fading),
            ("nothing to move by", Bench(motion: .none), Self.fading),
        ]
        for (name, bench, transition) in cases {
            bench.show([Bench.text("a"), Bench.text("b", transition)], complete: true)
            let b = bench.root.children[1]

            bench.show([Bench.text("a")])

            XCTAssertEqual(b.lifecycle, .released, name)
            XCTAssertEqual(bench.runtime.tree.exits.count, 0, name)
            XCTAssertEqual(bench.root.presentedChildren.count, 1, name)
            XCTAssertTrue(bench.ended.isEmpty, "\(name): no exit was kept, so none ended")
        }
    }

    /// A view its layout placed, for the layout motion's seat.
    private final class Seated: PlacedView {
        var placedFrame = Rect(x: 0, y: 0, width: 0, height: 0)
        var heldWords: LayoutSize?
    }

    /// AN EXIT OUT OF ITS ROOM TAKES THE VIEW WHOLLY OUT OF THE ROOM ITS LAYOUT PLACED IT IN: the place is read as
    /// it leaves, before its layout forgets it.
    func testAnExitOutOfItsRoomTakesTheViewWhollyOut() {
        let bench = Bench()
        let leaving = Transition(enter: .identity, exit: .outside(.left))
        bench.show([Bench.text("a"), Bench.text("b", leaving)], complete: true)
        let b = bench.root.children[1]
        let places = TravelingPlaces()
        places.layoutMotion = bench.runtime.layoutMotion
        places.begin(width: 300, height: 200)
        places.place(
            Seated(), mount: b.mount, at: Rect(x: 20, y: 30, width: 100, height: 40), values: LayoutValues(),
            natural: { .zero }, enter: nil)

        bench.show([Bench.text("a")])
        XCTAssertEqual(b.lifecycle, .exiting)
        bench.frame(at: 100)
        XCTAssertEqual(bench.shown(.translationX, of: b) ?? .nan, -60, accuracy: 0.001, "half way to its far edge past the room's")
        bench.frame(at: 200)
        XCTAssertEqual(b.lifecycle, .released)
    }

    /// THE SAME VIEW COMING BACK AS IT LEAVES TAKES OVER HOW THE LEAVING ONE WAS DRAWN: another element, the
    /// leaving one ended as interrupted, its numbers going on from where they stood and at their speed onto what
    /// it declares - a name by its own id, a number by the id its render says it returns as - while a view
    /// returning as nobody, or of another type, comes as any other.
    func testTheSameViewComingBackTakesOverHowItWasDrawn() {
        let bench = Bench()
        let comes = Transition(enter: .translation(y: 40), exit: .opacity.combined(with: .translation(y: 12)))
        bench.show([Bench.text("a"), Bench.text("b", comes)], complete: true)
        let leaving = bench.root.children[1]
        bench.show([Bench.text("a")])
        bench.frame(at: 100)
        XCTAssertEqual(bench.shown(.opacity, of: leaving) ?? .nan, 0.5, accuracy: 0.001)

        bench.show([Bench.text("a"), Bench.text("b", comes)])
        let back = bench.root.children[1]
        XCTAssertFalse(back === leaving, "another element, with handlers of its own")
        XCTAssertEqual(leaving.lifecycle, .released, "the leaving one is over")
        XCTAssertEqual(bench.ended.map(\.result), [.interrupted])
        XCTAssertTrue(bench.root.presentedChildren.elementsEqual(bench.root.children, by: ===), "one view of it stands")

        back.enter(Entering(), as: .joining(under: .none), presentsOpacity: true)
        XCTAssertEqual(bench.shown(.opacity, of: back) ?? .nan, 0.5, accuracy: 0.001, "from where the leaving one was drawn")
        XCTAssertEqual(bench.shown(.translationY, of: back) ?? .nan, 6, accuracy: 0.001, "not from its entry's effect")

        bench.frame(at: 200)
        XCTAssertGreaterThan(bench.shown(.opacity, of: back) ?? 0, 0.5, "and on its way back in")
        bench.frame(at: 300)
        XCTAssertEqual(back.number(.opacity) ?? 1, 1, "onto what it declares")
        XCTAssertNil(bench.shown(.translationY, of: back))

        // A view of a number comes back as the one its render names - whichever life of that line is leaving - and
        // one it names nobody for, like one of another type under the same name, comes as any other.
        func row(_ number: Int) -> HostPatch {
            var patch = HostPatch(id: .auto(number), type: .text)
            patch.properties = [.transition: comes.propValue]
            return patch
        }
        let numbered = Bench()
        numbered.show([Bench.text("a"), row(7)], complete: true)
        let first = numbered.root.children[1]
        numbered.show([Bench.text("a")])
        numbered.runtime.tree.returnsAs = [.auto(9): .auto(7)]
        numbered.show([Bench.text("a"), row(9)])
        let second = numbered.root.children[1]
        XCTAssertEqual(first.lifecycle, .released, "the one its render names is over")
        XCTAssertNotNil(second.returned, "and it is handed how that one was drawn")
        numbered.show([Bench.text("a")])
        numbered.runtime.tree.returnsAs = [.auto(10): .auto(7)]
        numbered.show([Bench.text("a"), row(10)])
        XCTAssertEqual(second.lifecycle, .released, "a later life leaving is known by the same id")
        XCTAssertNotNil(numbered.root.children[1].returned)
        XCTAssertEqual(numbered.ended.map(\.result), [.interrupted, .interrupted])

        let stranger = Bench()
        stranger.show([Bench.text("a"), row(7)], complete: true)
        let left = stranger.root.children[1]
        stranger.show([Bench.text("a")])
        stranger.show([Bench.text("a"), row(8)])
        XCTAssertEqual(left.lifecycle, .exiting, "a render naming nobody: nothing is guessed")
        XCTAssertNil(stranger.root.children[1].returned)

        let typed = Bench()
        typed.show([Bench.text("a"), Bench.text("b", comes)], complete: true)
        let text = typed.root.children[1]
        typed.show([Bench.text("a")])
        var other = HostPatch(id: .manual("b"), type: .rectangle)
        other.properties = [.transition: comes.propValue]
        typed.show([Bench.text("a"), other])
        XCTAssertEqual(text.lifecycle, .exiting, "another type: an exit and an entry apart")
        XCTAssertNil(typed.root.children[1].returned)
    }

    /// A view recording nothing, for an entry.
    private final class Entering: FadingView {
        var isShown = true
        var opacity = 1.0
        func setShown(_ shown: Bool) {}
        func setOpacity(_ opacity: Double) { self.opacity = opacity }
        func setIgnoresInput(_ ignores: Bool) {}
    }

    /// A SUBTREE AN ENGINE RUNS IN IS NOT KEPT: a web view's process or a map's would run on while it is drawn.
    func testASubtreeAnEngineRunsInIsNotKept() {
        for engine in [NodeType.webView, .map] {
            let bench = Bench()
            var card = HostPatch(id: .manual("card"), type: .vStack)
            card.properties = [.transition: Self.fading.propValue]
            card.children = .arranged([Bench.text("words"), HostPatch(id: .manual("engine"), type: engine)])
            bench.show([Bench.text("a"), card], complete: true)
            let leaving = bench.root.children[1]

            bench.show([Bench.text("a")])

            XCTAssertEqual(leaving.lifecycle, .released, "\(engine.name)")
            XCTAssertEqual(bench.runtime.tree.exits.count, 0, "\(engine.name)")
            XCTAssertTrue(bench.ended.isEmpty, "\(engine.name)")
        }
    }

    /// A MESSAGE MAKING THE TREE AGAIN KEEPS NOTHING: what it drops goes at once, and an exit running as it comes
    /// ends detached.
    func testAMessageMakingTheTreeAgainKeepsNothing() {
        let bench = Bench()
        bench.show(
            [Bench.text("a"), Bench.text("b", Self.fading), Bench.text("c", Self.fading)], complete: true)
        let (b, c) = (bench.root.children[1], bench.root.children[2])

        bench.show([Bench.text("a"), Bench.text("c", Self.fading)])
        XCTAssertEqual(b.lifecycle, .exiting)

        bench.show([Bench.text("a")], complete: true)
        XCTAssertEqual(b.lifecycle, .released, "the exit running ends")
        XCTAssertEqual(c.lifecycle, .released, "and what the message drops goes at once")
        XCTAssertEqual(bench.ended.map(\.result), [.detached])
        XCTAssertEqual(bench.runtime.tree.exits.count, 0)
    }

    /// A LEAVING VIEW STANDS WHERE IT STOOD among the views drawn: after the one it stood after, whatever joins or
    /// leaves beside it.
    func testALeavingViewStandsWhereItStood() {
        let bench = Bench()
        bench.show([Bench.text("a", Self.fading), Bench.text("b", Self.fading), Bench.text("c")], complete: true)

        bench.show([Bench.text("a", Self.fading), Bench.text("c")])
        XCTAssertEqual(bench.ids(bench.root.presentedChildren), ["a", "b", "c"].map { "\(ElementID.manual($0))" })

        bench.show([Bench.text("a", Self.fading), Bench.text("d"), Bench.text("c")])
        XCTAssertEqual(
            bench.ids(bench.root.presentedChildren), ["a", "b", "d", "c"].map { "\(ElementID.manual($0))" },
            "one that joins stands after the leaving one")

        bench.show([Bench.text("d"), Bench.text("c")])
        XCTAssertEqual(
            bench.ids(bench.root.presentedChildren), ["a", "b", "d", "c"].map { "\(ElementID.manual($0))" },
            "and a second leaving keeps the first after it")
        XCTAssertEqual(bench.ids(bench.root.arrangedChildren), ["d", "c"].map { "\(ElementID.manual($0))" })
    }

    /// THE BUDGET ENDS THE OLDEST: a window keeps thirty-two views leaving at once, none longer than two seconds,
    /// and a subtree past its whole budget leaves at once.
    func testTheBudgetEndsTheOldest() {
        let bench = Bench(motion: .eased(.seconds(5), curve: .linear))
        let many = (0...KeptExits.rootLimit).map { Bench.text("v\($0)", Self.fading) }
        bench.show(many, complete: true)
        let first = bench.root.children[0]

        bench.show([])
        XCTAssertEqual(bench.runtime.tree.exits.count, KeptExits.rootLimit)
        XCTAssertEqual(first.lifecycle, .released, "the oldest made room")
        XCTAssertEqual(bench.ended.map(\.result), [.limited])
        XCTAssertEqual("\(bench.ended[0].id)", "\(ElementID.manual("v0"))")

        bench.frame(at: KeptExits.timeLimit - 1)
        XCTAssertEqual(bench.runtime.tree.exits.count, KeptExits.rootLimit, "still within their time")
        bench.frame(at: KeptExits.timeLimit)
        XCTAssertEqual(bench.runtime.tree.exits.count, 0, "none is kept past it")
        XCTAssertEqual(Set(bench.ended.map(\.result)), [.limited])

        var large = HostPatch(id: .manual("large"), type: .vStack)
        large.properties = [.transition: Self.fading.propValue]
        large.children = .arranged((0..<KeptExits.mountLimit).map { Bench.text("leaf\($0)") })
        bench.show([large])
        let held = bench.root.children[0]
        bench.show([])
        XCTAssertEqual(held.lifecycle, .released, "larger than the budget: gone at once")
        XCTAssertEqual(bench.runtime.tree.exits.count, 0)
    }

    /// AN ELEMENT LEAVING OWNS THE LEAVINGS UNDER IT: gone at once, it takes them with it; kept itself, they stand
    /// as drawn, end none of their own, and are released with it.
    func testAnElementLeavingOwnsTheLeavingsUnderIt() {
        func box(_ transition: Transition?, _ children: [HostPatch]) -> HostPatch {
            var patch = HostPatch(id: .manual("box"), type: .vStack)
            if let transition { patch.properties = [.transition: transition.propValue] }
            patch.children = .arranged(children)
            return patch
        }

        let gone = Bench()
        gone.show([box(nil, [Bench.text("a"), Bench.text("b", Self.fading)])], complete: true)
        var inner = gone.root.children[0].children[1]
        gone.show([box(nil, [Bench.text("a")])])
        XCTAssertEqual(inner.lifecycle, .exiting)
        gone.show([])
        XCTAssertEqual(inner.lifecycle, .released, "its holder went at once, and took it")
        XCTAssertEqual(gone.ended.map(\.result), [.cancelled])

        let kept = Bench(motion: .eased(.milliseconds(400), curve: .linear))
        kept.show([box(Self.fading, [Bench.text("a"), Bench.text("b", Self.fading)])], complete: true)
        let holder = kept.root.children[0]
        inner = holder.children[1]
        kept.show([box(Self.fading, [Bench.text("a")])])
        kept.frame(at: 200)
        kept.show([])
        XCTAssertEqual(holder.lifecycle, .exiting)
        XCTAssertEqual(inner.lifecycle, .exiting, "it stands as drawn under its holder")
        XCTAssertEqual(kept.ended.map(\.result), [.cancelled], "its own exit is over")

        kept.frame(at: 400)
        XCTAssertEqual(inner.lifecycle, .exiting, "its own motion's end releases nothing")

        kept.frame(at: 600)
        XCTAssertEqual(holder.lifecycle, .released)
        XCTAssertEqual(inner.lifecycle, .released, "released with its holder")
        XCTAssertEqual(kept.ended.map(\.result), [.cancelled, .finished])
    }

    /// NOTHING HOLDS A VIEW ONCE ITS EXIT ENDED: the tree, its parent and the budget have let it go.
    func testNothingHoldsAViewOnceItsExitEnded() {
        let bench = Bench()
        bench.show([Bench.text("a"), Bench.text("b", Self.fading)], complete: true)
        weak let leaving = bench.root.children[1]
        bench.show([Bench.text("a")])
        XCTAssertNotNil(leaving, "kept while it exits")

        bench.frame(at: 200)
        XCTAssertNil(leaving)
    }
}
