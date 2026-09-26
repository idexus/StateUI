// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The value a mounted element's property presents: a bound state's lanes as the value the property carries, and
/// where an animation of the property starts.
@MainActor
final class PropertyValuesTests: XCTestCase {
    /// A bound state's lanes become the value its property carries: a colour's four lanes each held between 0 and
    /// 255, a Boolean true where its lane is not zero, an enumeration at its nearest case, and a number or numbers
    /// as they are.
    func testABoundStatesLanesAreTheValueItsPropertyCarries() throws {
        let runtime = HostRuntime.still()
        let plain: [Prop: Int32] = [
            .background: 811, .isEnabled: 812, .isVisible: 813, .horizontalAlignment: 814, .opacity: 815,
            .margin: 816,
        ]
        var bindings = plain.mapValues { HostStateBinding(state: $0, mode: .out, kind: .plain) }
        bindings[.tint] = HostStateBinding(state: 817, mode: .out, kind: .property)
        var label = HostPatch(id: .manual("label"), type: .label)
        label.driven = .replace(bindings)
        runtime.tree.apply(label, complete: true)
        let tint = HostJourney(
            value: [0, 1, 0.2, 1], destination: [0, 1, 0.2, 1], velocity: [0, 0, 0, 0], motion: .none,
            completion: nil, stopped: 0)

        runtime.tree.present(states: [
            811: .lanes([1.2, 0.5, -0.1, 1]),
            812: .lanes([0]),
            813: .lanes([0.25]),
            814: .lanes([1.6]),
            815: .lanes([0.25]),
            816: .lanes([1, 2, 3, 4]),
            817: HostBoundary.value(of: tint),
        ], properties: [:])

        let element = try XCTUnwrap(runtime.tree.root)
        XCTAssertEqual(element.value(.background), .color(red: 255, green: 128, blue: 0, alpha: 255))
        XCTAssertEqual(element.value(.tint), .color(red: 0, green: 255, blue: 51, alpha: 255), "a channel's lanes alike")
        XCTAssertEqual(element.value(.isEnabled), .bool(false))
        XCTAssertEqual(element.value(.isVisible), .bool(true))
        XCTAssertEqual(element.value(.horizontalAlignment), .enumeration(2))
        XCTAssertEqual(element.value(.opacity), .number(0.25))
        XCTAssertEqual(element.value(.margin), .numbers([1, 2, 3, 4]))
    }

    /// A property the toolkit animates, given a value for the first time, starts from its resting value: no
    /// margin, no turn, a scale of one, a corner radius of the target's shape.
    func testAPropertyFirstAnimatedStartsAtItsNeutralValue() throws {
        let runtime = HostRuntime(
            clock: StillClock(), reducesMotion: { false }, makeNative: { _ in AnimatingView() }, log: { _ in })
        runtime.tree.apply(HostPatch(id: .manual("box"), type: .colorBox), complete: true)
        let targets: [Prop: HostValue] = [
            .margin: .numbers([8, 8, 8, 8]), .rotation: .number(90), .scale: .number(3),
            .cornerRadius: .numbers([4, 4, 4, 4]),
        ]
        var moved = HostPatch(id: .manual("box"), type: .colorBox)
        moved.properties = targets
        moved.transitions = targets.mapValues { _ in HostTransition(motion: .eased(200, .linear)) }

        runtime.tree.apply(moved, complete: false)

        let box = try XCTUnwrap(runtime.tree.root)
        XCTAssertEqual(box.value(.margin), .numbers([0, 0, 0, 0]))
        XCTAssertEqual(box.value(.rotation), .number(0))
        XCTAssertEqual(box.value(.scale), .number(1))
        XCTAssertEqual(box.value(.cornerRadius), .numbers([0, 0, 0, 0]))

        runtime.describedMotion.follow(runtime.animator.advance(to: 100))
        XCTAssertEqual(box.value(.margin), .numbers([4, 4, 4, 4]), "and moves from there")
        XCTAssertEqual(box.value(.scale), .number(2))
    }
}

/// A native half that animates every property and reads none off a control.
@MainActor
private final class AnimatingView: NativeElement {
    let presentsView = true
    func willApply() {}
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { true }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {}
    func presentFrame(_ changed: Set<Prop>) -> FrameImpact { .none }
    func arrangeChildren() {}
    func leave() {}
}
