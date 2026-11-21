// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Whether the board below shows its detail, else its deck; the board's scope, which changes are aimed at.
@MainActor private let detailShown = State(wrappedValue: false)
@MainActor private let cardBoardScope = Aim(VStack.self)

/// Whether the one item of the deck below shows its large view, else its small one.
@MainActor private let itemDetailed = State(wrappedValue: false)

/// A deck of two cards a motion layout places, and the detail of the first outside it: under one scope, tied by a key.
private struct CardBoard: View {
    var body: some View {
        VStack {
            if detailShown.wrappedValue {
                Text("detail").sharedTransition(5)
            } else {
                MotionLayout([5, 6], parameters: State(wrappedValue: 0.0).projectedValue) { card in
                    Text("card \(card)").sharedTransition(card)
                } placements: { _, _ in
                    [Placement(Rect(x: 40, y: 40, width: 40, height: 40)), Placement(Rect(x: 90, y: 40, width: 40, height: 40))]
                }
            }
        }
        .transitionScope("board")
        .aim(cardBoardScope)
    }
}

private struct CardBoardApplication: Application {
    var body: some Scene { WindowGroup { CardBoard() } }
}

/// A deck of one item whose small view and large view are tied by a key: a swap inside the item, which stands.
private struct SwappingDeck: View {
    var body: some View {
        VStack {
            MotionLayout([5], parameters: State(wrappedValue: 0.0).projectedValue) { _ in
                if itemDetailed.wrappedValue {
                    Rectangle().sharedTransition(5)
                } else {
                    Text("small").sharedTransition(5)
                }
            } placements: { _, _ in
                [Placement(Rect(x: 40, y: 40, width: 100, height: 60))]
            }
        }
        .transitionScope("deck")
    }
}

private struct SwappingDeckApplication: Application {
    var body: some Scene { WindowGroup { SwappingDeck() } }
}

/// Whether the deck below stands.
@MainActor private let fadingDeckShown = State(wrappedValue: true)

/// A deck of two cards a motion layout places, the second drawn at half its size, fading as it leaves.
private struct FadingDeck: View {
    var body: some View {
        VStack {
            if fadingDeckShown.wrappedValue {
                MotionLayout([1, 2], parameters: State(wrappedValue: 0.0).projectedValue) { card in
                    Text("card \(card)")
                } placements: { _, _ in
                    [Placement(Rect(x: 40, y: 40, width: 40, height: 40)),
                     Placement(Rect(x: 90, y: 40, width: 40, height: 40), transform: .scale(0.5))]
                }
                .transition(.symmetric(.opacity))
            }
        }
    }
}

private struct FadingDeckApplication: Application {
    var body: some Scene { WindowGroup { FadingDeck() } }
}

/// The cards of the deck below.
@MainActor private let growingDeckCards = State(wrappedValue: [1])

/// A deck a motion layout places a hundred points apart, as many cards as it is given.
private struct GrowingDeck: View {
    var body: some View {
        VStack {
            MotionLayout(growingDeckCards.wrappedValue, parameters: State(wrappedValue: 0.0).projectedValue) { card in
                Text("card \(card)")
            } placements: { context, _ in
                (0..<growingDeckCards.wrappedValue.count).map { Placement(Rect(x: Double($0) * 100, y: 0, width: 80, height: 80)) }
            }
        }
    }
}

private struct GrowingDeckApplication: Application {
    var body: some Scene { WindowGroup { GrowingDeck() } }
}

/// A shared transition on the host's side: one view dropped and one made in a patch under one key of one scope are
/// one - the made one enters from where the dropped one was drawn - and anything else is each view's own.
/// Design: docs/design/host/motion.md#a-shared-transition
@MainActor
final class SharedTransitionsTests: XCTestCase {
    /// A scope at (10, 20) in its window showing either a list of thumbnails or a page with a detail, on a clock
    /// wound by hand; the application moves in 200 ms.
    @MainActor
    private final class Bench {
        let clock = WoundClock()
        let runtime: HostRuntime
        private var views: [UInt64: Placed] = [:]

        init(keeps: Bool = false) {
            runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in
                let view = NoView()
                view.keepsExits = keeps
                return view
            }, log: { _ in })
            runtime.layoutMotion.applicationMotion = .eased(.milliseconds(200), curve: .linear)
        }

        var tree: MountedTree { runtime.tree }
        var root: MountedElement { tree.root! }

        /// A text of `id` wearing `key`, leaving by a fade where `fades`.
        static func keyed(_ id: String, _ key: Int, fades: Bool = false) -> HostPatch {
            var patch = HostPatch(id: .manual(id), type: .text)
            patch.properties = [.sharedTransition: .number(Double(key))]
            if fades { patch.properties[.transition] = Transition(enter: .identity, exit: .opacity).propValue }
            return patch
        }

        /// A stack of `id` holding `children`.
        static func holder(_ id: String, _ children: [HostPatch]) -> HostPatch {
            var patch = HostPatch(id: .manual(id), type: .vStack)
            patch.children = .arranged(children)
            return patch
        }

        /// Says the scope's children, whole the first time.
        func show(_ children: [HostPatch], complete: Bool = false) {
            var root = HostPatch(id: .manual("root"), type: .vStack)
            if complete { root.properties = [.transitionScope: .number(1)] }
            root.children = .arranged(children)
            tree.apply(root, complete: complete)
            (self.root.native as? NoView)?.frame = [0, 0, 300, 400, 10, 20, 10, 20]
        }

        func element(_ id: String) -> MountedElement? { root.first(id: .manual(id)) }

        /// Says the toolkit holds the view of `id` at `corner` in the window, `size` large.
        func stands(_ id: String, at corner: Point, size: LayoutSize) {
            (element(id)?.native as? NoView)?.frame = [0, 0, size.width, size.height, corner.x, corner.y, corner.x, corner.y]
        }

        /// A layout pass gives the element of `id` the place `rect` in what holds it; it enters there.
        func place(_ id: String, at rect: Rect) {
            guard let element = element(id) else { return XCTFail("no \(id)") }

            let view = views[element.mount, default: Placed()]
            views[element.mount] = view
            runtime.layoutMotion.place(
                view, mount: element.mount, at: rect, stated: [], words: .none,
                natural: { LayoutSize(width: rect.width, height: rect.height) },
                enter: { entry in element.enter(Shown(), as: entry) },
                in: Arrangement(law: .eased(.milliseconds(200), curve: .linear), lanes: .all, joins: true), room: nil)
        }

        func frame(at time: Double) {
            clock.time = time
            runtime.displayCycle.frame(now: time)
        }

        /// What the tree draws of `property` on the element of `id`; nil where it stands as declared.
        func drawn(_ property: Prop, of id: String) -> Double? {
            element(id).flatMap { tree.presentedPropertyValue(mount: $0.mount, property: property)?.number }
        }
    }

    private final class Placed: PlacedView {
        var placedFrame = Rect(x: 0, y: 0, width: 0, height: 0)
        var heldWords: LayoutSize?
    }

    private final class Shown: FadingView {
        var isShown = true
        var opacity = 1.0
        func setShown(_ shown: Bool) {}
        func setOpacity(_ opacity: Double) { self.opacity = opacity }
        func setIgnoresInput(_ ignores: Bool) {}
    }

    /// The list with its thumbnail drawn at (50, 60), forty points square - and the page laid out under the scope
    /// with its detail at (30, 150) in the window, two hundred by a hundred.
    private func listed(_ bench: Bench, thumbnails: [HostPatch] = [Bench.keyed("thumbnail", 5)]) {
        bench.show([Bench.holder("list", thumbnails)], complete: true)
        bench.stands("thumbnail", at: Point(x: 50, y: 60), size: LayoutSize(width: 40, height: 40))
    }

    private func paged(_ bench: Bench, details: [HostPatch] = [Bench.keyed("detail", 5)], holder: HostPatch? = nil) {
        bench.show([holder ?? Bench.holder("page", details)])
        bench.place("page", at: Rect(x: 0, y: 100, width: 300, height: 200))
        bench.place("detail", at: Rect(x: 20, y: 30, width: 200, height: 100))
    }

    /// ONE VIEW DROPPED AND ONE MADE UNDER ONE KEY ARE ONE: the made one enters from the rectangle the dropped one
    /// was drawn in - moved by the difference of their middles, scaled by the ratio of their sizes - and comes
    /// onto its own place under its motion.
    func testTheViewMadeEntersFromWhereTheViewDroppedWasDrawn() {
        let bench = Bench()
        listed(bench)

        paged(bench)
        XCTAssertEqual(
            (bench.element("detail")?.native as? NoView)?.presented.last,
            [.translationX, .translationY, .scaleX, .scaleY],
            "drawn where it sets out before any frame: never at its own place first")

        XCTAssertEqual(bench.drawn(.translationX, of: "detail") ?? .nan, -60, accuracy: 0.001, "70 against 130 across")
        XCTAssertEqual(bench.drawn(.translationY, of: "detail") ?? .nan, -120, accuracy: 0.001, "80 against 200 down")
        XCTAssertEqual(bench.drawn(.scaleX, of: "detail") ?? .nan, 0.2, accuracy: 0.001, "40 of 200")
        XCTAssertEqual(bench.drawn(.scaleY, of: "detail") ?? .nan, 0.4, accuracy: 0.001, "40 of 100")

        bench.frame(at: 100)
        XCTAssertEqual(bench.drawn(.translationX, of: "detail") ?? .nan, -30, accuracy: 0.5, "half way")
        bench.frame(at: 250)
        XCTAssertNil(bench.drawn(.translationX, of: "detail"), "and onto its place")
        XCTAssertNil(bench.drawn(.scaleX, of: "detail"))
    }

    /// A list of a keyed view at (40, 50) in the window, a hundred square, its thumbnail where `listed` stands it.
    private func standingList(_ bench: Bench, thumbnails: [HostPatch] = [Bench.keyed("thumbnail", 5)]) throws -> MountedElement {
        listed(bench, thumbnails: thumbnails)
        bench.stands("list", at: Point(x: 40, y: 50), size: LayoutSize(width: 100, height: 100))
        return try XCTUnwrap(bench.element("list"))
    }

    /// A rectangle of `id` wearing `key`, rounded by `corner`.
    private static func rounded(_ id: String, _ key: Int, corner: Double) -> HostPatch {
        var patch = HostPatch(id: .manual(id), type: .rectangle)
        patch.properties = [.sharedTransition: .number(Double(key)), .cornerRadius: .number(corner)]
        return patch
    }

    /// A VIEW DROPPED HOLDING A KEY GOES ALONG ONTO WHERE ITS PARTNER LANDS: kept where its holder keeps one, it is
    /// taken from where it is drawn so that its keyed view lands on the partner's place - (50, 60) forty square onto
    /// (30, 150) two hundred by a hundred, about the list's middle - and released as it lands.
    func testAViewKeptForItsPartnerGoesAlongOntoWhereItLands() throws {
        let bench = Bench(keeps: true)
        let list = try standingList(bench)
        paged(bench)
        XCTAssertEqual(list.lifecycle, .exiting, "kept for its partner")
        let ends = [list.exitEnds[.translationX], list.exitEnds[.translationY], list.exitEnds[.scaleX], list.exitEnds[.scaleY]]
        XCTAssertEqual(ends, [140, 150, 5, 2.5], "its thumbnail's middle onto the detail's, 40 onto 200 and 100")

        bench.frame(at: 250)
        XCTAssertEqual(list.lifecycle, .released, "landed, it is gone")
        bench.frame(at: 266)
        bench.frame(at: 282)
        XCTAssertEqual(bench.runtime.tree.shared.entries, 0, "its patch's notes let go, nothing of the pair is held")
    }

    /// A VIEW DROPPED HOLDING A KEY ITS PATCH MADE NO PARTNER FOR GOES AT ONCE, as the patch is applied whole.
    func testAViewDroppedWithNoPartnerGoesAtOnce() throws {
        let bench = Bench(keeps: true)
        let list = try standingList(bench)
        bench.show([Bench.holder("page", [Bench.keyed("other", 6)])])
        XCTAssertEqual(list.lifecycle, .released)
    }

    /// THE TWO CROSS OVER NEAR THE SMALLER: growing from the thumbnail, the detail comes in over the way's first
    /// part as the list goes out; half way they have crossed.
    func testTheTwoCrossOverNearTheSmaller() throws {
        let bench = Bench(keeps: true)
        let list = try standingList(bench)
        paged(bench)
        let detail = try XCTUnwrap(bench.element("detail"))
        let opacities = { [detail.value(.opacity)?.number, list.value(.opacity)?.number] }
        XCTAssertEqual(opacities(), [0, 1], "setting out: the thumbnail's list alone")
        bench.frame(at: 100)
        XCTAssertEqual(opacities(), [1, 0], "half way, grown past where they cross")
        XCTAssertEqual(SharedWay.crossing(from: Rect(x: 0, y: 0, width: 200, height: 100), to: Rect(x: 0, y: 0, width: 40, height: 40)), 0.55...1, "shrinking, late")
    }

    /// THE CORNER IS CARRIED ON THE WAY, DRAWN: from the thumbnail's 6 points to the detail's 12, straight as the way
    /// goes, whatever the view is scaled to - its own corner the drawn one over its scale - and its own at the end.
    func testTheCornerIsCarriedOnTheWayAsDrawn() throws {
        let bench = Bench(keeps: true)
        let list = try standingList(bench, thumbnails: [Self.rounded("thumbnail", 5, corner: 6)])
        let thumbnail = try XCTUnwrap(bench.element("thumbnail"))
        paged(bench, details: [Self.rounded("detail", 5, corner: 12)])
        let detail = try XCTUnwrap(bench.element("detail"))
        XCTAssertEqual(detail.number(.cornerRadius) ?? .nan, 6 / (0.2 * 0.4).squareRoot(), accuracy: 0.001, "drawn 6")
        XCTAssertEqual(thumbnail.number(.cornerRadius) ?? .nan, 6, accuracy: 0.001, "the leaving one too")

        bench.frame(at: 100)
        XCTAssertEqual(detail.number(.cornerRadius) ?? .nan, 9 / (0.6 * 0.7).squareRoot(), accuracy: 0.001, "drawn 9 half way")
        XCTAssertEqual(thumbnail.number(.cornerRadius) ?? .nan, 9 / (3 * 1.75).squareRoot(), accuracy: 0.001)
        // A frame moving the two draws each one's corner too: the kept list's keyed view, no more the tree's own.
        let views = [detail, thumbnail].map { $0.native as? NoView }
        let before = views.map { $0?.presented.count ?? 0 }
        bench.tree.present(states: [:], properties: [detail.mount: [.translationX], list.mount: [.translationX]])
        let corners = zip(views, before).map { view, count in view?.presented.dropFirst(count).first?.contains(.cornerRadius) }
        XCTAssertEqual(corners, [true, true], "each drawn so on every frame")

        bench.frame(at: 250)
        XCTAssertEqual(detail.number(.cornerRadius), 12, "its own")
        XCTAssertEqual(list.lifecycle, .released)
    }

    /// THE VIEW LEAVING GOES ON AT THE SPEED IT HAD: a list on its way across as it is dropped sets out onto its
    /// partner's place at that speed.
    func testTheViewLeavingGoesOnAtTheSpeedItHad() throws {
        let bench = Bench(keeps: true)
        bench.runtime.layoutMotion.applicationMotion = .spring(response: .milliseconds(300), damping: 1)
        let list = try standingList(bench)
        bench.runtime.tree.receiveProperty(
            mount: list.mount, property: .translationX, standing: .number(0), target: .number(50),
            motion: .eased(.milliseconds(200), curve: .linear))
        bench.frame(at: 50)
        paged(bench)
        let speed = bench.runtime.tree.standingProperty(mount: list.mount, property: .translationX)?.velocity.first
        XCTAssertEqual(speed ?? .nan, 250, accuracy: 1, "50 points in 200 ms, on its way on")
    }

    /// A VIEW DRAWN UNDER WHAT HOLDS IT SETS ITS PARTNER OUT FROM THERE: the transform of every view above it, up to
    /// its scope, draws it too - a list drawn at half its size draws its thumbnail at half, about the list's middle.
    func testAViewDrawnUnderWhatHoldsItSetsItsPartnerOutFromThere() {
        let bench = Bench()
        var list = Bench.holder("list", [Bench.keyed("thumbnail", 5)])
        list.properties = [.scale: .number(0.5)]
        bench.show([list], complete: true)
        bench.stands("list", at: Point(x: 40, y: 50), size: LayoutSize(width: 100, height: 100))
        bench.stands("thumbnail", at: Point(x: 50, y: 60), size: LayoutSize(width: 40, height: 40))

        paged(bench)
        XCTAssertEqual(bench.drawn(.scaleX, of: "detail") ?? .nan, 0.1, accuracy: 0.001, "20 of 200: drawn at half")
        XCTAssertEqual(bench.drawn(.translationX, of: "detail") ?? .nan, -50, accuracy: 0.001, "80 against 130 across")
        XCTAssertEqual(bench.drawn(.translationY, of: "detail") ?? .nan, -110, accuracy: 0.001, "90 against 200 down")
    }

    /// A VIEW ENTERING UNDER WHAT HOLDS IT LANDS WHERE IT IS DRAWN: on a page drawn at half its size, the detail sets
    /// out from the thumbnail with the page's transform undone, the list kept for it goes onto where the page draws
    /// the detail - (95, 185), a hundred by fifty - and the corner is the drawn one: 12 at half is 6 all the way.
    func testAViewEnteringUnderWhatHoldsItLandsWhereItIsDrawn() throws {
        let bench = Bench(keeps: true)
        let list = try standingList(bench, thumbnails: [Self.rounded("thumbnail", 5, corner: 6)])
        var page = Bench.holder("page", [Self.rounded("detail", 5, corner: 12)])
        page.properties = [.scale: .number(0.5)]
        bench.show([page])
        bench.stands("page", at: Point(x: 10, y: 120), size: LayoutSize(width: 300, height: 200))
        bench.place("page", at: Rect(x: 0, y: 100, width: 300, height: 200))
        bench.place("detail", at: Rect(x: 20, y: 30, width: 200, height: 100))
        let detail = try XCTUnwrap(bench.element("detail"))

        XCTAssertEqual(bench.drawn(.translationX, of: "detail") ?? .nan, -150, accuracy: 0.001, "-20 against 130 across")
        XCTAssertEqual(bench.drawn(.translationY, of: "detail") ?? .nan, -260, accuracy: 0.001, "-60 against 200 down")
        XCTAssertEqual(bench.drawn(.scaleX, of: "detail") ?? .nan, 0.4, accuracy: 0.001, "80 of 200: drawn 40 at half")
        XCTAssertEqual(bench.drawn(.scaleY, of: "detail") ?? .nan, 0.8, accuracy: 0.001, "80 of 100")
        let ends = [list.exitEnds[.translationX], list.exitEnds[.translationY], list.exitEnds[.scaleX], list.exitEnds[.scaleY]]
        XCTAssertEqual(ends, [105, 135, 2.5, 1.25], "the thumbnail's middle onto (145, 210), 40 onto 100 and 50")
        XCTAssertEqual(detail.number(.cornerRadius) ?? .nan, 6 / (0.4 * 0.8).squareRoot() / 0.5, accuracy: 0.001)

        bench.frame(at: 250)
        XCTAssertEqual(detail.number(.cornerRadius), 12, "drawn 6 at half: its own")
    }

    /// A HOLDER MADE WITH A VIEW SETTING OUT FROM ITS PARTNER COMES AS IT STANDS: joining a layout that stands, it
    /// does not fade in - its fade would hide where that view sets out. A holder made with no partner in it fades in.
    func testAHolderMadeWithAViewSettingOutFromItsPartnerComesAsItStands() {
        let bench = Bench()
        listed(bench)
        paged(bench)
        XCTAssertNil(bench.drawn(.opacity, of: "page"), "drawn at once, around the detail setting out")
        XCTAssertNotNil(bench.drawn(.scaleX, of: "detail"), "the detail sets out from the thumbnail")

        let alone = Bench()
        listed(alone)
        paged(alone, details: [Bench.keyed("detail", 6)])
        XCTAssertEqual(alone.drawn(.opacity, of: "page") ?? .nan, 0, accuracy: 0.001, "no partner in it: it fades in")
    }

    /// A VIEW SETTING OUT FROM ITS PARTNER IS DRAWN IN FRONT OF WHAT IT PASSES OVER UNTIL IT LANDS: in front of its
    /// siblings in its stack, and its stack in front in each layout up to the scope; landed, each stands back in
    /// its layout's order - each layout drawing its children again both times.
    func testAViewSettingOutIsDrawnInFrontUntilItLands() throws {
        let bench = Bench()
        listed(bench)
        paged(bench)
        let detail = try XCTUnwrap(bench.element("detail"))
        let page = try XCTUnwrap(bench.element("page"))
        let inFront = { [bench.runtime.layoutMotion.drawsInFront(detail.mount), bench.runtime.layoutMotion.drawsInFront(page.mount)] }
        let ordered = { [(page.native as? NoView)?.ordered, (bench.root.native as? NoView)?.ordered] }
        XCTAssertEqual(inFront(), [true, true], "the detail in its page, the page in the scope")
        XCTAssertEqual(ordered(), [1, 1])

        bench.frame(at: 250)
        XCTAssertEqual(inFront(), [false, false], "landed: back in its layouts' order")
        XCTAssertEqual(ordered(), [2, 2])
    }

    /// WHERE ONE LAYOUT HOLDS BOTH, THE LARGER IS IN FRONT: the detail is drawn in front in its page, and the list
    /// kept for it goes along drawn in front in what holds it - in its shelf, its shelf in its area - and in the
    /// scope, which holds the page and the area both, the page of the larger, the detail, alone; released, nothing.
    func testWhereOneLayoutHoldsBothTheLargerIsInFront() throws {
        let bench = Bench(keeps: true)
        let thumbnail = Bench.keyed("thumbnail", 5)
        bench.show([Bench.holder("area", [Bench.holder("shelf", [Bench.holder("list", [thumbnail])])])], complete: true)
        bench.stands("list", at: Point(x: 40, y: 50), size: LayoutSize(width: 100, height: 100))
        bench.stands("thumbnail", at: Point(x: 50, y: 60), size: LayoutSize(width: 40, height: 40))
        let list = try XCTUnwrap(bench.element("list"))
        bench.show([Bench.holder("area", [Bench.holder("shelf", [])]), Bench.holder("page", [Bench.keyed("detail", 5)])])
        bench.place("page", at: Rect(x: 0, y: 100, width: 300, height: 200))
        bench.place("detail", at: Rect(x: 20, y: 30, width: 200, height: 100))
        XCTAssertEqual(list.lifecycle, .exiting, "kept for its partner")

        let motion = bench.runtime.layoutMotion
        let inFront = { (id: String) in bench.element(id).map { motion.drawsInFront($0.mount) } }
        XCTAssertEqual(inFront("detail"), true, "the detail in its page")
        XCTAssertEqual([motion.drawsInFront(list.mount), inFront("shelf")], [true, true], "the list in its shelf, the shelf in its area")
        XCTAssertEqual([inFront("page"), inFront("area")], [true, false], "in the scope, the larger's alone")

        bench.frame(at: 250)
        XCTAssertEqual(list.lifecycle, .released)
        let all = ["detail", "page", "shelf"].map(inFront) + [motion.drawsInFront(list.mount)]
        XCTAssertEqual(all, [false, false, false, false], "landed and released: none in front")
    }

    /// WHAT CAME WITH IT KEEPS THE LAYERS ITS AUTHOR GAVE IT: a view setting out in a ZStack made with it stays
    /// where it is layered there - its words over it stay over it - while the ZStack is drawn in front in the
    /// scope; and a view taken away before it lands leaves nothing in front.
    func testWhatCameWithItKeepsItsLayers() throws {
        let bench = Bench()
        listed(bench)
        var layers = HostPatch(id: .manual("page"), type: .zStack)
        var words = HostPatch(id: .manual("words"), type: .text)
        words.properties = [.text: .string("words")]
        layers.children = .arranged([Bench.keyed("detail", 5), words])
        paged(bench, holder: layers)
        let detail = try XCTUnwrap(bench.element("detail"))
        let page = try XCTUnwrap(bench.element("page"))
        let motion = bench.runtime.layoutMotion
        XCTAssertFalse(motion.drawsInFront(detail.mount), "layered with what came with it, as written")
        XCTAssertTrue(motion.drawsInFront(page.mount), "in front of what stood in the scope")

        bench.show([])
        XCTAssertFalse(motion.drawsInFront(page.mount), "taken away: nothing stays in front")
    }

    /// A KEY THAT MEETS NO SINGLE PARTNER IS EACH VIEW'S OWN: two views dropped under it, or the made one standing
    /// where nothing is known of yet, enter as any view does - and a change waiting for the patch hears
    /// `.unsupported`.
    func testAKeyThatMeetsNoSinglePartnerIsEachViewsOwn() {
        let twice = Bench()
        listed(twice, thumbnails: [Bench.keyed("thumbnail", 5), Bench.keyed("other", 5)])
        twice.stands("other", at: Point(x: 100, y: 60), size: LayoutSize(width: 40, height: 40))
        let change = Renderer.shared.change(aimedAt: [.manual("root")])
        twice.tree.changes.begin(Renderer.shared.takeChanges(), in: twice.tree)
        paged(twice)
        twice.tree.changes.close()
        XCTAssertNil(twice.drawn(.translationX, of: "detail"), "two sources: no rectangle is its own")
        twice.frame(at: 250)
        twice.frame(at: 500)
        XCTAssertEqual(change.answered.settled, .interrupted([.unsupported]))

        let unplaced = Bench()
        listed(unplaced)
        unplaced.show([Bench.holder("page", [Bench.keyed("detail", 5)])])
        unplaced.place("detail", at: Rect(x: 20, y: 30, width: 200, height: 100))
        XCTAssertNil(unplaced.drawn(.translationX, of: "detail"), "its page stands nowhere yet: nothing is guessed")

        let another = Bench()
        listed(another)
        paged(another, details: [Bench.keyed("detail", 6)])
        XCTAssertNil(another.drawn(.translationX, of: "detail"), "another key")
    }

    /// A VIEW MADE ON ANOTHER PAGE THAN THE ONE DROPPED IS ITS OWN: a page that comes over a page is the
    /// navigation's to bring, so the made view enters as any view does, by its own transition, and a change
    /// waiting for the patch hears `.unsupported` - while the same two under one page are one.
    func testAViewMadeOnAnotherPageIsItsOwn() {
        func page(_ id: String, _ children: [HostPatch]) -> HostPatch {
            var patch = HostPatch(id: .manual(id), type: .page)
            patch.children = .arranged(children)
            return patch
        }

        let across = Bench()
        across.show([page("list", [Bench.keyed("thumbnail", 5)])], complete: true)
        across.stands("thumbnail", at: Point(x: 50, y: 60), size: LayoutSize(width: 40, height: 40))
        let change = Renderer.shared.change(aimedAt: [.manual("root")])
        across.tree.changes.begin(Renderer.shared.takeChanges(), in: across.tree)
        across.show([page("shown", [Bench.keyed("detail", 5)])])
        across.stands("shown", at: Point(x: 10, y: 120), size: LayoutSize(width: 300, height: 200))
        across.place("detail", at: Rect(x: 20, y: 30, width: 200, height: 100))
        across.tree.changes.close()
        XCTAssertNil(across.drawn(.translationX, of: "detail"), "another page: the rectangle is not its own")
        XCTAssertNil(across.drawn(.scaleX, of: "detail"))
        across.frame(at: 250)
        across.frame(at: 500)
        XCTAssertEqual(change.answered.settled, .interrupted([.unsupported]))

        let within = Bench()
        within.show([page("one", [Bench.holder("list", [Bench.keyed("thumbnail", 5)])])], complete: true)
        within.stands("thumbnail", at: Point(x: 50, y: 60), size: LayoutSize(width: 40, height: 40))
        within.show([page("one", [Bench.holder("shown", [Bench.keyed("detail", 5)])])])
        within.stands("shown", at: Point(x: 10, y: 120), size: LayoutSize(width: 300, height: 200))
        within.place("detail", at: Rect(x: 20, y: 30, width: 200, height: 100))
        XCTAssertNotNil(within.drawn(.scaleX, of: "detail"), "one page: the two are one")
    }

    /// A CARD A MOTION LAYOUT PLACES OPENS INTO A DETAIL OUTSIDE THE LAYOUT, under a scope around both - the core
    /// and the host layer together: the layout dropped with its cards in their holders, the detail made, in one
    /// patch, and the detail enters from where the card was drawn.
    func testACardOfAMotionLayoutOpensIntoADetailOutsideIt() throws {
        detailShown.wrappedValue = false
        CardBoardApplication.register()
        let runtime = HostRuntime(clock: WoundClock(), reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.layoutMotion.applicationMotion = .eased(.milliseconds(200), curve: .linear)
        runtime.connectWindow()
        runtime.pump.turn()
        let root = try XCTUnwrap(runtime.tree.root)
        func element(_ words: String) -> MountedElement? {
            func find(_ element: MountedElement) -> MountedElement? {
                if element.value(.text)?.string == words { return element }
                return element.children.lazy.compactMap(find).first
            }
            return find(root)
        }
        let card = try XCTUnwrap(element("card 5"))
        XCTAssertEqual(card.parent?.parent?.type, .motionLayout, "the card stands in its holder in the layout")
        var above = card.parent
        while let each = above, each.value(LayoutContract.transitionScope.token) == nil { above = each.parent }
        let scope = try XCTUnwrap(above)
        (scope.native as? NoView)?.frame = [0, 0, 300, 400, 10, 20, 10, 20]
        (card.native as? NoView)?.frame = [40, 40, 40, 40, 50, 60, 50, 60]

        detailShown.wrappedValue = true
        runtime.pump.turn()
        let detail = try XCTUnwrap(element("detail"))
        runtime.layoutMotion.place(
            Placed(), mount: detail.mount, at: Rect(x: 20, y: 30, width: 200, height: 100), stated: [], words: .none,
            natural: { LayoutSize(width: 200, height: 100) },
            enter: { entry in detail.enter(Shown(), as: entry) },
            in: Arrangement(law: .eased(.milliseconds(200), curve: .linear), lanes: .all, joins: true), room: nil)

        let drawn = { (property: Prop) in runtime.tree.presentedPropertyValue(mount: detail.mount, property: property)?.number }
        XCTAssertEqual(drawn(.scaleX) ?? .nan, 0.2, accuracy: 0.001, "40 of 200: it sets out as large as the card")
        XCTAssertEqual(drawn(.translationX) ?? .nan, -60, accuracy: 0.001, "the card's middle, 70, against 130")
    }

    /// A runtime with nothing native behind it, every view keeping one that leaves where `keeps`, the application
    /// motion 200 ms, showing what is registered, and a finder of its elements by their words or type.
    private func joint(keeps: Bool = false) throws -> (runtime: HostRuntime, find: (String) -> MountedElement?) {
        let runtime = HostRuntime(clock: WoundClock(), reducesMotion: { false }, makeNative: { _ in
            let view = NoView()
            view.keepsExits = keeps
            return view
        }, log: { _ in })
        runtime.layoutMotion.applicationMotion = .eased(.milliseconds(200), curve: .linear)
        runtime.connectWindow()
        runtime.pump.turn()
        let root = try XCTUnwrap(runtime.tree.root)
        func find(_ words: String) -> MountedElement? {
            func walk(_ element: MountedElement) -> MountedElement? {
                if element.value(.text)?.string == words || (words == "rectangle" && element.type == .rectangle) {
                    return element
                }
                return element.children.lazy.compactMap(walk).first
            }
            return walk(root)
        }
        return (runtime, find)
    }

    /// The display's frames from `from` to `to` milliseconds, a turn after each.
    private func frames(_ runtime: HostRuntime, from: Double, to: Double) {
        for time in stride(from: from, through: to, by: 16) {
            (runtime.clock as? WoundClock)?.time = time
            runtime.displayCycle.frame(now: time)
            runtime.pump.turn()
        }
    }

    /// A LAYOUT KEPT AS IT LEAVES KEEPS ITS CHILDREN WHERE ITS PROGRAM LAST SHOWED THEM - fading by its own exit, or
    /// kept for the partner of a card in it: its run stands, each child drawn as the program drew it, never laid
    /// over the layout's room as a stack would stand it.
    func testALayoutKeptAsItLeavesKeepsItsProgramsPlaces() throws {
        fadingDeckShown.wrappedValue = true
        FadingDeckApplication.register()
        let (runtime, find) = try joint(keeps: true)
        let second = try XCTUnwrap(find("card 2"))
        let holder = try XCTUnwrap(second.parent)
        let deck = try XCTUnwrap(holder.parent)
        XCTAssertEqual(deck.type, .motionLayout)
        deck.reportFrame([0, 0, 300, 200, 10, 20, 10, 20], in: runtime)
        frames(runtime, from: 16, to: 64)
        let shown = try XCTUnwrap(deck.placement)
        XCTAssertEqual(shown.placements.count, 2)
        XCTAssertEqual(holder.drawnTransform.scaleX, 0.5, accuracy: 0.001)

        fadingDeckShown.wrappedValue = false
        runtime.pump.turn()
        XCTAssertEqual(deck.lifecycle, .exiting, "kept as it fades")
        XCTAssertEqual(deck.placement, shown, "its run stands")
        XCTAssertEqual(holder.drawnTransform.scaleX, 0.5, accuracy: 0.001, "the second card drawn at half its size still")

        detailShown.wrappedValue = false
        CardBoardApplication.register()
        let board = try joint(keeps: true)
        let card = try XCTUnwrap(board.find("card 5"))
        let cards = try XCTUnwrap(card.parent?.parent)
        cards.reportFrame([0, 0, 300, 200, 10, 20, 10, 20], in: board.runtime)
        frames(board.runtime, from: 16, to: 64)
        let stood = try XCTUnwrap(cards.placement)
        (card.native as? NoView)?.frame = [0, 0, 40, 40, 50, 60, 50, 60]

        detailShown.wrappedValue = true
        board.runtime.pump.turn()
        XCTAssertEqual(cards.lifecycle, .exiting, "kept for the detail")
        XCTAssertEqual(cards.placement, stood, "its run stands")
    }

    /// The board showing its detail at (30, 50) in the window, two hundred by a hundred, told to show its deck again:
    /// the deck made, the toolkit's pass placing it at (10, 20), three hundred by `height`, before its program was
    /// asked - it fades in, as nothing in it is known to set out yet - and laying it out, asking its program's
    /// places in that room as every host does.
    private func boardBack(height: Double) throws -> (
        runtime: HostRuntime, change: PresentationChange, card: MountedElement, holder: MountedElement,
        deck: MountedElement, run: HostPlacementRun?
    ) {
        detailShown.wrappedValue = true
        CardBoardApplication.register()
        let (runtime, find) = try joint()
        let detail = try XCTUnwrap(find("detail"))
        let scope = try XCTUnwrap(detail.parent)
        (scope.native as? NoView)?.frame = [0, 0, 300, 400, 10, 20, 10, 20]
        (detail.native as? NoView)?.frame = [20, 30, 200, 100, 30, 50, 30, 50]

        let change = try cardBoardScope.presentationChange { detailShown.wrappedValue = false }
        runtime.pump.turn()
        let card = try XCTUnwrap(find("card 5"))
        let holder = try XCTUnwrap(card.parent)
        let deck = try XCTUnwrap(holder.parent)
        (deck.native as? NoView)?.frame = [0, 0, 300, height, 10, 20, 10, 20]
        runtime.layoutMotion.place(
            Placed(), mount: deck.mount, at: Rect(x: 0, y: 0, width: 300, height: height), stated: [], words: .none,
            natural: { LayoutSize(width: 300, height: height) },
            enter: { entry in deck.enter(Shown(), as: entry) },
            in: Arrangement(law: .eased(.milliseconds(200), curve: .linear), lanes: .all, joins: true), room: nil)
        XCTAssertEqual(
            runtime.tree.presentedPropertyValue(mount: deck.mount, property: .opacity)?.number ?? .nan, 0, accuracy: 0.001,
            "nothing in it known to set out before it is laid out: it fades in")
        return (runtime, change, card, holder, deck, deck.placementInRoom(LayoutSize(width: 300, height: height)))
    }

    /// The card `card` given its first place in its holder, `size` large, as its holder's pass lays it out.
    private func cardPlaced(_ card: MountedElement, size: LayoutSize, in runtime: HostRuntime) {
        runtime.layoutMotion.place(
            Placed(), mount: card.mount, at: Rect(x: 0, y: 0, width: size.width, height: size.height), stated: [],
            words: .none, natural: { size }, enter: { entry in card.enter(Shown(), as: entry) },
            in: Arrangement(law: .eased(.milliseconds(200), curve: .linear), lanes: .all, joins: true), room: nil)
    }

    /// A VIEW MADE WITH A LAYOUT ITS PROGRAM PLACES SETS OUT TOWARD THE PLACE THE PROGRAM GIVES IT: the layout's
    /// first pass asks its program, so the card coming back from its detail is first placed in the holder the
    /// program put at (40, 40) of the deck - (50, 60) in the window, forty square - and travels there from where
    /// the detail was drawn; the change waiting for it settles.
    func testAViewMadeWithALayoutSetsOutTowardThePlaceItsProgramGives() throws {
        let (runtime, change, card, holder, deck, run) = try boardBack(height: 200)
        XCTAssertEqual(run?.placements.map(\.bounds), [
            Rect(x: 40, y: 40, width: 40, height: 40), Rect(x: 90, y: 40, width: 40, height: 40),
        ], "asked in the pass that lays the deck out")
        XCTAssertTrue(deck.hasPlaced(holder))
        (holder.native as? NoView)?.frame = [40, 40, 40, 40, 50, 60, 50, 60]
        cardPlaced(card, size: LayoutSize(width: 40, height: 40), in: runtime)

        let drawn = { (property: Prop) in runtime.tree.presentedPropertyValue(mount: card.mount, property: property)?.number }
        XCTAssertEqual(drawn(.scaleX) ?? .nan, 5, accuracy: 0.001, "200 of 40: it sets out as large as the detail")
        XCTAssertEqual(drawn(.scaleY) ?? .nan, 2.5, accuracy: 0.001, "100 of 40")
        XCTAssertEqual(drawn(.translationX) ?? .nan, 60, accuracy: 0.001, "the detail's middle, 130, against 70")
        XCTAssertEqual(drawn(.translationY) ?? .nan, 20, accuracy: 0.001, "100 against 80")
        frames(runtime, from: 16, to: 400)
        XCTAssertEqual(change.answered.settled, .settled)
    }

    /// A VIEW MADE WITH A LAYOUT WHOSE PROGRAM SHOWS NO PLACE SETS OUT TOWARD NO PLACE THE TREE DOES NOT KNOW: laid
    /// out in a room of no height, the program places nothing, the toolkit stands the holder across the room, and
    /// the card coming back draws no way - a change waiting for it hears `.unsupported`.
    func testAViewMadeWithALayoutWhoseProgramShowsNoPlaceSetsOutTowardNone() throws {
        let (runtime, change, card, holder, deck, run) = try boardBack(height: 0)
        XCTAssertEqual(run?.placements ?? [], [], "a room of nothing places nothing")
        XCTAssertFalse(deck.hasPlaced(holder))
        (holder.native as? NoView)?.frame = [0, 0, 300, 0, 10, 20, 10, 20]
        cardPlaced(card, size: LayoutSize(width: 300, height: 0), in: runtime)

        XCTAssertNil(runtime.tree.presentedPropertyValue(mount: card.mount, property: .scaleY), "no way to a place unknown")
        frames(runtime, from: 16, to: 400)
        XCTAssertEqual(change.answered.settled, .interrupted([.unsupported]))
    }

    /// A LAYOUT GIVEN ANOTHER CHILD STANDS IT WHERE ITS PROGRAM PUTS IT IN ITS NEXT PASS: the run the pass stands
    /// the children by places every child the layout holds, the new one too.
    func testALayoutGivenAnotherChildStandsItWhereItsProgramPutsIt() throws {
        growingDeckCards.wrappedValue = [1]
        GrowingDeckApplication.register()
        let (runtime, find) = try joint()
        let first = try XCTUnwrap(find("card 1"))
        let deck = try XCTUnwrap(first.parent?.parent)
        deck.reportFrame([0, 0, 300, 200, 10, 20, 10, 20], in: runtime)
        frames(runtime, from: 16, to: 64)
        let room = LayoutSize(width: 300, height: 200)
        XCTAssertEqual(deck.placementInRoom(room)?.placements.count, 1)

        growingDeckCards.wrappedValue = [1, 2]
        runtime.pump.turn()
        let second = try XCTUnwrap(find("card 2")?.parent)
        XCTAssertEqual(deck.placementInRoom(room)?.placements.map(\.bounds.x), [0, 100])
        XCTAssertTrue(deck.hasPlaced(second))
    }

    /// A VIEW SWAPPED INSIDE AN ITEM A PROGRAM PLACES SETS OUT FROM ITS PARTNER: the item stands where the program
    /// showed it, so the view made in it enters from where the view dropped was drawn, to its place there.
    func testAViewSwappedInsideAnItemAProgramPlacesSetsOutFromItsPartner() throws {
        itemDetailed.wrappedValue = false
        SwappingDeckApplication.register()
        let (runtime, find) = try joint()
        let small = try XCTUnwrap(find("small"))
        let holder = try XCTUnwrap(small.parent)
        let layout = try XCTUnwrap(holder.parent)
        XCTAssertEqual(layout.type, .motionLayout)
        (layout.native as? NoView)?.frame = [0, 0, 300, 200, 10, 20, 10, 20]
        layout.reportFrame([0, 0, 300, 200, 10, 20, 10, 20], in: runtime)
        frames(runtime, from: 16, to: 64)
        XCTAssertEqual(layout.programPlace(at: 0)?.bounds, Rect(x: 40, y: 40, width: 100, height: 60))
        (holder.native as? NoView)?.frame = [40, 40, 100, 60, 50, 60, 50, 60]
        (small.native as? NoView)?.frame = [0, 0, 40, 30, 50, 60, 50, 60]
        // The toolkit arranged the holder across the layout's room first; the program moved it since.
        runtime.layoutMotion.place(
            Placed(), mount: holder.mount, at: Rect(x: 0, y: 0, width: 300, height: 200), stated: [], words: .none,
            natural: { LayoutSize(width: 300, height: 200) }, enter: nil, in: Arrangement(joins: false), room: nil)

        itemDetailed.wrappedValue = true
        runtime.pump.turn()
        let large = try XCTUnwrap(find("rectangle"))
        XCTAssertTrue(large.parent === holder, "the item stands")
        runtime.layoutMotion.place(
            Placed(), mount: large.mount, at: Rect(x: 0, y: 0, width: 100, height: 60), stated: [], words: .none,
            natural: { LayoutSize(width: 100, height: 60) },
            enter: { entry in large.enter(Shown(), as: entry) },
            in: Arrangement(law: .eased(.milliseconds(200), curve: .linear), lanes: .all, joins: true), room: nil)

        let drawn = { (property: Prop) in runtime.tree.presentedPropertyValue(mount: large.mount, property: property)?.number }
        XCTAssertEqual(drawn(.scaleX) ?? .nan, 0.4, accuracy: 0.001, "40 of 100")
        XCTAssertEqual(drawn(.scaleY) ?? .nan, 0.5, accuracy: 0.001, "30 of 60")
        XCTAssertEqual(drawn(.translationX) ?? .nan, -30, accuracy: 0.001, "the small one's middle, 70, against 100")
    }

    /// A RETURN DURING THE MOVEMENT SETS OUT FROM WHERE THE VIEW NOW LEAVING IS DRAWN, and a view still leaving by
    /// its own exit as its partner is placed is over at once.
    func testAReturnSetsOutFromWhereTheLeavingViewIsDrawn() {
        let bench = Bench(keeps: true)
        listed(bench)
        paged(bench)
        bench.stands("detail", at: Point(x: 30, y: 150), size: LayoutSize(width: 200, height: 100))
        bench.frame(at: 100)

        // Half way in, the detail is drawn 120 by 70 with its middle at (100, 140).
        bench.show([Bench.holder("list", [Bench.keyed("thumbnail", 5)])])
        bench.place("list", at: Rect(x: 0, y: 0, width: 300, height: 100))
        bench.place("thumbnail", at: Rect(x: 40, y: 40, width: 40, height: 40))
        XCTAssertEqual(bench.drawn(.translationX, of: "thumbnail") ?? .nan, 30, accuracy: 0.5, "100 against 70 across")
        XCTAssertEqual(bench.drawn(.scaleX, of: "thumbnail") ?? .nan, 3, accuracy: 0.05, "120 of 40")

        let kept = Bench(keeps: true)
        kept.show([Bench.keyed("thumbnail", 5, fades: true)], complete: true)
        kept.stands("thumbnail", at: Point(x: 50, y: 60), size: LayoutSize(width: 40, height: 40))
        let leaving = kept.element("thumbnail")
        kept.show([Bench.keyed("detail", 5)])
        XCTAssertEqual(leaving?.lifecycle, .exiting, "kept, leaving by its own exit")
        kept.place("detail", at: Rect(x: 20, y: 130, width: 200, height: 100))
        XCTAssertEqual(leaving?.lifecycle, .released, "its partner stands over it: it is drawn no more")
        XCTAssertNotNil(kept.drawn(.translationX, of: "detail"))
    }
}
