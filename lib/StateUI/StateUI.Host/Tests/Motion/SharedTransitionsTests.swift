// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

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

    private func paged(_ bench: Bench, details: [HostPatch] = [Bench.keyed("detail", 5)]) {
        bench.show([Bench.holder("page", details)])
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
