// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// An element's showing: fading in as it joins, and a change of its visibility crossed, the same on every host.
@MainActor
final class VisibilityCrossingTests: XCTestCase {
    /// A hidden element fades out, standing shown the while; as the fade lands it hides, and its layout closes over
    /// it, once.
    func testAHiddenElementFadesOutThenHidesAndItsLayoutCloses() throws {
        let (runtime, clock, element) = Self.label(visible: true)
        let view = Faded()
        var closed = 0

        Self.show(false, in: runtime)
        element.crossVisibility(view) { closed += 1 }
        XCTAssertTrue(element.standsShown, "shown while it fades out")
        XCTAssertTrue(view.isShown)

        clock.time = 100
        runtime.displayCycle.frame(now: 100)
        XCTAssertEqual(runtime.tree.presentedPropertyValue(mount: element.mount, property: .opacity), .number(0.5))
        XCTAssertEqual(closed, 0)

        clock.time = 200
        runtime.displayCycle.frame(now: 200)
        XCTAssertEqual(closed, 1)
        XCTAssertFalse(view.isShown, "hidden once the fade landed")
        XCTAssertFalse(element.standsShown)
    }

    /// An element shown again as it fades out comes back from the opacity it stands at, and its layout never closes.
    func testAnElementShownAgainMidFadeComesBackFromWhereItStands() throws {
        let (runtime, clock, element) = Self.label(visible: true)
        let view = Faded()
        var closed = 0
        Self.show(false, in: runtime)
        element.crossVisibility(view) { closed += 1 }
        clock.time = 100
        runtime.displayCycle.frame(now: 100)
        view.opacity = 0.5

        Self.show(true, in: runtime)
        element.crossVisibility(view) { closed += 1 }
        XCTAssertFalse(element.isLeaving)
        XCTAssertEqual(runtime.tree.presentedPropertyValue(mount: element.mount, property: .opacity), .number(0.5),
                       "from where it stands")
        clock.time = 400
        runtime.displayCycle.frame(now: 400)
        XCTAssertEqual(closed, 0)
        XCTAssertTrue(view.isShown)
    }

    /// An element shown from nothing fades in from no opacity; a child joining a standing layout fades in unless a
    /// state owns its opacity or it is already on its way.
    func testAnElementShownFromNothingFadesIn() throws {
        let (runtime, _, element) = Self.label(visible: true)
        let view = Faded()
        view.isShown = false

        element.crossVisibility(view) {}
        XCTAssertEqual(runtime.tree.presentedPropertyValue(mount: element.mount, property: .opacity), .number(0))
        XCTAssertEqual(view.said, ["opacity 0.0"])

        let joining = Faded()
        XCTAssertTrue(element.fadesIn(presentsOpacity: true))
        XCTAssertFalse(element.fadesIn(presentsOpacity: false))
        element.fadeIn(joining, under: .eased(200, .linear))
        XCTAssertEqual(joining.said, [], "its opacity is already on its way")
    }

    /// Where nothing moves, nothing crosses: the host shows or hides the view itself.
    func testWhereNothingMovesNothingCrosses() throws {
        let (runtime, _, element) = Self.label(visible: true)
        runtime.layoutMotion.applicationMotion = .none
        let view = Faded()
        var closed = 0

        Self.show(false, in: runtime)
        element.crossVisibility(view) { closed += 1 }
        XCTAssertFalse(element.isLeaving)
        XCTAssertFalse(element.standsShown)
        XCTAssertEqual(view.said, [])
        XCTAssertEqual(closed, 0)
    }

    /// A runtime on a clock the test winds, its application's motion a linear 200 ms, holding one label.
    private static func label(visible: Bool) -> (HostRuntime, WoundClock, MountedElement) {
        let clock = WoundClock()
        let runtime = HostRuntime(clock: clock, reducesMotion: { false }, makeNative: { _ in NoView() }, log: { _ in })
        runtime.layoutMotion.applicationMotion = .eased(200, .linear)
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [.isVisible: .bool(visible)]
        runtime.tree.apply(label, complete: true)
        return (runtime, clock, runtime.tree.root!)
    }

    /// The label shown or hidden, as a patch says.
    private static func show(_ visible: Bool, in runtime: HostRuntime) {
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [.isVisible: .bool(visible)]
        runtime.tree.apply(label, complete: false)
    }
}

/// A clock whose time the test sets.
@MainActor
private final class WoundClock: FrameClock {
    var time = 0.0
    lazy var now: () -> Double = { [unowned self] in self.time }
    var held = false
    var onFrame: ((Double) -> Void)?
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
