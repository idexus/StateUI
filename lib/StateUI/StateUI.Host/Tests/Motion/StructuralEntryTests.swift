// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A child given its first place comes by the transition it declares: each number its entry's effect touches set
/// out from the effect and brought onto what the element declares, under the element's own motion - as it joins a
/// layout already standing, and as it appears with its layout where its transition says so.
/// Design: docs/design/host/motion.md#a-view-that-enters
@MainActor
final class StructuralEntryTests: XCTestCase {
    /// A view recording the opacity it was stood at, and how many times.
    private final class Joining: FadingView {
        var isShown = true
        var opacity = 1.0
        private(set) var stood = 0
        func setShown(_ shown: Bool) { isShown = shown }
        func setOpacity(_ opacity: Double) {
            self.opacity = opacity
            stood += 1
        }
        func setIgnoresInput(_ ignores: Bool) {}
    }

    /// A runtime on a clock wound by hand, the application moving by a linear 200 ms, holding one label in a stack
    /// with `properties`.
    private func label(
        _ properties: [Prop: HostValue], driven: [Prop: HostStateBinding] = [:]
    ) -> (HostRuntime, WoundClock, MountedElement) {
        let clock = WoundClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.layoutMotion.applicationMotion = .eased(.milliseconds(200), curve: .linear)
        var root = HostPatch(id: .manual("root"), type: .vStack)
        var label = HostPatch(id: .manual("label"), type: .text)
        label.properties = properties
        if !driven.isEmpty { label.driven = .replace(driven) }
        root.children = .arranged([label])
        runtime.tree.apply(root, complete: true)
        return (runtime, clock, runtime.tree.root!.children[0])
    }

    private func shown(_ property: Prop, of element: MountedElement, in runtime: HostRuntime) -> Double? {
        runtime.tree.presentedPropertyValue(mount: element.mount, property: property)?.number
    }

    /// A CHILD JOINING ENTERS FROM ITS EFFECT AND LANDS ON WHAT IT DECLARES: faded and moved as its transition's
    /// entry says, half way there half its motion's time in, and as declared at its end - under its own motion,
    /// whatever the layout it joins animates under.
    func testAChildJoiningEntersFromItsEffect() {
        let transition = Transition.symmetric(.opacity.combined(with: .translation(y: 12)).combined(with: .scale(0.5)))
        let (runtime, clock, element) = label([.transition: transition.propValue, .translationY: .number(8)])
        let view = Joining()
        XCTAssertTrue(element.entersMoving(presentsOpacity: false), "a transition enters whatever the view presents")

        element.enter(view, as: .joining(under: .none))
        XCTAssertEqual(shown(.opacity, of: element, in: runtime), 0, "from faded out")
        XCTAssertEqual(shown(.translationY, of: element, in: runtime), 14, "what it declares and the effect's move")
        XCTAssertEqual(shown(.scale, of: element, in: runtime), 0.5)
        XCTAssertNil(shown(.translationX, of: element, in: runtime), "a number the effect leaves alone moves none")
        XCTAssertEqual(view.opacity, 0, "drawn there at once")
        XCTAssertEqual(
            (element.native as? NoView)?.presented.last, [.translationY, .scale],
            "and its move and its scale too, before any frame: never drawn at its place first")

        clock.time = 100
        runtime.displayCycle.frame(now: 100)
        XCTAssertEqual(shown(.opacity, of: element, in: runtime) ?? .nan, 0.5, accuracy: 0.001, "the element's own 200 ms")
        XCTAssertEqual(shown(.translationY, of: element, in: runtime) ?? .nan, 11, accuracy: 0.001)

        clock.time = 200
        runtime.displayCycle.frame(now: 200)
        XCTAssertEqual(element.number(.opacity) ?? 1, 1, "as declared")
        XCTAssertEqual(element.number(.translationY), 8)
        XCTAssertEqual(element.number(.scale) ?? 1, 1)
    }

    /// A CHILD OF NO TRANSITION FADES IN AS EVER, under the law of the layout it joins, where its view presents
    /// opacity - and not at all where that layout's children arrive, or as it appears with its layout.
    func testAChildOfNoTransitionFadesInAsEver() {
        let (runtime, _, element) = label([:])
        let view = Joining()
        XCTAssertTrue(element.entersMoving(presentsOpacity: true))
        XCTAssertFalse(element.entersMoving(presentsOpacity: false))

        element.enter(view, as: .appearing)
        element.enter(view, as: .joining(under: .none))
        XCTAssertNil(shown(.opacity, of: element, in: runtime))
        XCTAssertEqual(view.stood, 0, "a view that simply appears is not touched")

        element.enter(view, as: .joining(under: .eased(.milliseconds(200), curve: .linear)))
        XCTAssertEqual(shown(.opacity, of: element, in: runtime), 0)
        XCTAssertNil(shown(.translationY, of: element, in: runtime))
    }

    /// A CHILD APPEARING WITH ITS LAYOUT ENTERS ONLY WHERE ITS TRANSITION SAYS SO.
    func testAChildAppearingWithItsLayoutEntersWhereItsTransitionSaysSo() {
        let transition = Transition.symmetric(.translation(y: 12))
        let (runtime, _, standing) = label([.transition: transition.propValue])
        standing.enter(Joining(), as: .appearing)
        XCTAssertNil(shown(.translationY, of: standing, in: runtime), "unless said, a view enters only as it joins")

        let (other, _, appearing) = label([.transition: transition.initialAppearance(true).propValue])
        appearing.enter(Joining(), as: .appearing)
        XCTAssertEqual(shown(.translationY, of: appearing, in: other), 12)
    }

    /// AN ELEMENT A MESSAGE MADE AGAIN ENTERS BY NO TRANSITION: one made by a complete message over a standing
    /// root, or with another root - while one a patch adds, and the first message's, enter.
    func testAnElementAMessageMadeAgainEntersByNoTransition() {
        let transition = Transition.symmetric(.translation(y: 12)).initialAppearance(true)
        let (runtime, _, first) = label([.transition: transition.propValue])
        XCTAssertFalse(first.isRemade, "the first message's")

        var root = HostPatch(id: .manual("root"), type: .vStack)
        var added = HostPatch(id: .manual("added"), type: .text)
        added.properties = [.transition: transition.propValue]
        root.children = .arranged([HostPatch(id: .manual("label"), type: .text), added])
        runtime.tree.apply(root, complete: false)
        let joined = runtime.tree.root!.children[1]
        XCTAssertFalse(joined.isRemade, "a patch's")
        joined.enter(Joining(), as: .joining(under: .none))
        XCTAssertEqual(shown(.translationY, of: joined, in: runtime), 12)

        var whole = HostPatch(id: .manual("root"), type: .vStack)
        var label = HostPatch(id: .manual("label"), type: .text)
        label.properties = [.transition: transition.propValue]
        var again = HostPatch(id: .manual("again"), type: .text)
        again.properties = [.transition: transition.propValue]
        whole.children = .arranged([label, again])
        runtime.tree.apply(whole, complete: true)
        let resynced = runtime.tree.root!.children[1]
        XCTAssertTrue(resynced.isRemade, "a complete message over a standing root")
        resynced.enter(Joining(), as: .joining(under: .none))
        XCTAssertNil(shown(.translationY, of: resynced, in: runtime))

        var swapped = HostPatch(id: .manual("another"), type: .vStack)
        swapped.children = .arranged([label])
        runtime.tree.apply(swapped, complete: true)
        let remade = runtime.tree.root!.children[0]
        XCTAssertTrue(remade.isRemade, "another root")
        remade.enter(Joining(), as: .appearing)
        XCTAssertNil(shown(.translationY, of: remade, in: runtime))
    }

    /// A view its layout placed, for the layout motion's seat.
    private final class Seated: PlacedView {
        var placedFrame = Rect(x: 0, y: 0, width: 0, height: 0)
        var heldWords: LayoutSize?
    }

    /// AN EFFECT OUT OF ITS ROOM ENTERS FROM WHOLLY OUTSIDE THE ROOM ITS LAYOUT PLACED IT IN, and from where it
    /// stands where no layout placed it.
    func testAnEffectOutOfItsRoomEntersFromOutsideTheRoomItWasPlacedIn() {
        let transition = Transition.symmetric(.outside(.right))
        let (runtime, _, element) = label([.transition: transition.propValue])
        element.enter(Joining(), as: .joining(under: .none))
        XCTAssertNil(shown(.translationX, of: element, in: runtime), "no layout placed it: no room to stand out of")

        let (placing, _, placed) = label([.transition: transition.propValue])
        let places = TravelingPlaces()
        places.layoutMotion = placing.layoutMotion
        places.begin(width: 300, height: 200)
        places.place(
            Seated(), mount: placed.mount, at: Rect(x: 20, y: 30, width: 100, height: 40), values: LayoutValues(),
            natural: { .zero }, enter: nil)
        placed.enter(Joining(), as: .joining(under: .none))
        XCTAssertEqual(shown(.translationX, of: placed, in: placing), 280, "its near edge at the room's far one")
        XCTAssertNil(shown(.translationY, of: placed, in: placing))
    }

    /// WHERE NOTHING MOVES, A CHILD STANDS AS DECLARED AT ONCE: less motion, or an application that moves nothing
    /// and a view of no motion of its own.
    func testWhereNothingMovesAChildStandsAtOnce() {
        let transition = Transition.symmetric(.opacity.combined(with: .translation(y: 12)))
        let (runtime, _, element) = label([.transition: transition.propValue])
        runtime.layoutMotion.applicationMotion = .none

        element.enter(Joining(), as: .joining(under: .eased(.milliseconds(200), curve: .linear)))

        XCTAssertNil(shown(.opacity, of: element, in: runtime), "the layout's law is not the view's")
        XCTAssertNil(shown(.translationY, of: element, in: runtime))
    }

    /// A NUMBER A STATE OWNS IS LEFT TO ITS STATE: the entry moves the others.
    func testANumberAStateOwnsIsLeftToIt() {
        let transition = Transition.symmetric(.opacity.combined(with: .translation(y: 12)))
        let owned = HostStateBinding(state: 7, mode: .in, kind: .property, laneKind: nil)
        let (runtime, _, element) = label([.transition: transition.propValue], driven: [.opacity: owned])
        XCTAssertNotNil(element.transition)

        element.enter(Joining(), as: .joining(under: .none))

        XCTAssertNil(shown(.opacity, of: element, in: runtime), "the state's")
        XCTAssertEqual(shown(.translationY, of: element, in: runtime), 12)
    }
}
