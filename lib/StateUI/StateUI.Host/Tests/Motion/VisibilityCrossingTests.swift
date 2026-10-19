// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// An element's showing: fading in as it joins, and a change of its visibility crossed, the same on every host.
@MainActor
final class VisibilityCrossingTests: XCTestCase {
    /// A hidden element fades out, standing shown the while; as the fade lands it hides, and the layout placing it
    /// closes over it, once - its travelling places told the change arrived.
    func testAHiddenElementFadesOutThenHidesAndItsLayoutCloses() throws {
        let (runtime, clock, element) = Self.label(visible: true)
        let view = Faded()
        let places = TravellingPlaces()
        let closed = { Self.arranged(in: runtime) }

        Self.show(false, in: runtime)
        element.crossVisibility(view, closingIn: places)
        XCTAssertTrue(element.standsShown, "shown while it fades out")
        XCTAssertTrue(view.isShown)

        clock.time = 100
        runtime.displayCycle.frame(now: 100)
        XCTAssertEqual(runtime.tree.presentedPropertyValue(mount: element.mount, property: .opacity), .number(0.5))
        XCTAssertEqual(closed(), 0)

        clock.time = 200
        runtime.displayCycle.frame(now: 200)
        XCTAssertEqual(closed(), 1)
        XCTAssertTrue(places.patched, "the change arrives where the layout travels")
        XCTAssertFalse(view.isShown, "hidden once the fade landed")
        XCTAssertFalse(element.standsShown)
    }

    /// An element shown again as it fades out comes back from the opacity it stands at, and its layout never closes.
    func testAnElementShownAgainMidFadeComesBackFromWhereItStands() throws {
        let (runtime, clock, element) = Self.label(visible: true)
        let view = Faded()
        Self.show(false, in: runtime)
        element.crossVisibility(view, closingIn: nil)
        clock.time = 100
        runtime.displayCycle.frame(now: 100)
        view.opacity = 0.5

        Self.show(true, in: runtime)
        element.crossVisibility(view, closingIn: nil)
        XCTAssertFalse(element.isLeaving)
        XCTAssertEqual(runtime.tree.presentedPropertyValue(mount: element.mount, property: .opacity), .number(0.5),
                       "from where it stands")
        clock.time = 400
        runtime.displayCycle.frame(now: 400)
        XCTAssertEqual(Self.arranged(in: runtime), 0)
        XCTAssertTrue(view.isShown)
    }

    /// An element shown from nothing fades in from no opacity; a child joining a standing layout fades in where its
    /// view presents its opacity and no state owns it, unless it is already on its way.
    func testAnElementShownFromNothingFadesIn() throws {
        let (runtime, _, element) = Self.label(visible: true)
        let view = Faded()
        view.isShown = false

        element.crossVisibility(view, closingIn: nil)
        XCTAssertEqual(runtime.tree.presentedPropertyValue(mount: element.mount, property: .opacity), .number(0))
        XCTAssertEqual(view.said, ["opacity 0.0"])

        let joining = Faded()
        XCTAssertTrue(element.fadesIn(presentsOpacity: true))
        XCTAssertFalse(element.fadesIn(presentsOpacity: false))
        element.fadeIn(joining, under: .eased(.milliseconds(200), .linear))
        XCTAssertEqual(joining.said, [], "its opacity is already on its way")
    }

    /// Where nothing moves, nothing crosses: the host shows or hides the view itself.
    func testWhereNothingMovesNothingCrosses() throws {
        let (runtime, _, element) = Self.label(visible: true)
        runtime.layoutMotion.applicationMotion = .none
        let view = Faded()

        Self.show(false, in: runtime)
        element.crossVisibility(view, closingIn: nil)
        XCTAssertFalse(element.isLeaving)
        XCTAssertFalse(element.standsShown)
        XCTAssertEqual(view.said, [])
        XCTAssertEqual(Self.arranged(in: runtime), 0)
    }

    /// A runtime on a clock the test winds, its application's motion a linear 200 ms, holding one label in a stack.
    private static func label(visible: Bool) -> (HostRuntime, WoundClock, MountedElement) {
        let clock = WoundClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.layoutMotion.applicationMotion = .eased(.milliseconds(200), .linear)
        runtime.tree.apply(stack(visible), complete: true)
        (runtime.tree.root?.native as? NoView)?.arranged = 0
        return (runtime, clock, runtime.tree.root!.children[0])
    }

    /// The label shown or hidden, as a patch says.
    private static func show(_ visible: Bool, in runtime: HostRuntime) {
        runtime.tree.apply(stack(visible), complete: false)
        (runtime.tree.root?.native as? NoView)?.arranged = 0
    }

    /// The stack holding the label, shown or hidden.
    private static func stack(_ visible: Bool) -> HostPatch {
        var label = HostPatch(id: .manual("label"), type: .text)
        label.properties = [.isVisible: .bool(visible)]
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([label])
        return stack
    }

    /// How many times the stack arranged its children since the patch last shown or hid the label.
    private static func arranged(in runtime: HostRuntime) -> Int {
        (runtime.tree.root?.native as? NoView)?.arranged ?? -1
    }
}

/// A view that says what it was told.
@MainActor
private final class Faded: FadingView {
    var isShown = true
    var opacity = 1.0
    var said: [String] = []

    func setShown(_ shown: Bool) {
        isShown = shown
        said.append("shown \(shown)")
    }

    func setOpacity(_ opacity: Double) {
        self.opacity = opacity
        said.append("opacity \(opacity)")
    }
}
