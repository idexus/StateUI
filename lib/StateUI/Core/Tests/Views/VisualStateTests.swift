// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Visual states: declared as data, resolved by the differ into the values a
// control shows, followed from what the user does, and heard once entered.

import XCTest
@_spi(Host) @testable import StateUI

final class VisualStateTests: XCTestCase {
    private let green = Color("#008000").propValue
    private let gray = Color("#808080").propValue
    private let blue = Color("#0000FF").propValue

    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
    }

    /// Renders `control` alone in a stack, as the element "c".
    private func render(_ renders: Renders, _ control: Node) -> HostPatch? {
        renders.render(stack([control], id: "root")).child("c")
    }

    /// Runs the handler the element answers `event` with, then walks what it wrote.
    private func fire(_ renders: Renders, _ patch: HostPatch, _ event: Event, _ payload: [PropValue] = []) -> HostPatch? {
        Renderer.shared.clearInvalidation()
        XCTAssertTrue(renders.fire(patch.events?[event] ?? -1, with: payload), "\(event) is heard")
        return renders.revisit(changed: Renderer.shared.pendingChanges).child("c")
    }

    // MARK: - Declared

    /// A state is data on the control - its name, its group and its values - and nothing is laid out for it;
    /// written twice, the second writing stands where the first did.
    func testAStateIsDataAndTheSecondWritingWins() {
        var node = Switch()
            .visualState(.on) { $0.background(.green) }
            .visualState(.off) { $0.background(.gray) }
            .visualState(.on) { $0.background(.blue) }
            .node
        node.materialize()

        XCTAssertEqual(node.visualStates.map(\.name), ["On", "Off"])
        XCTAssertEqual(node.visualStates.first?.setters["background"], blue)
        XCTAssertTrue(node.children.isEmpty)
    }

    /// A control's state is written over its style's of the same name one setter at a time, and a state the style
    /// never mentioned joins after the style's.
    func testAControlsStatesAreWrittenOverItsStyles() {
        let sheet = StyleSheet {
            Style<Switch>().visualState(.disabled) { $0.opacity(0.5).background(.gray) }
        }
        let node = styled(
            Switch()
                .visualState(.disabled) { $0.background(.blue) }
                .visualState(.on) { $0.background(.green) }
                .node,
            with: sheet)

        XCTAssertEqual(node.visualStates, [
            DeclaredState(name: "Disabled", setters: ["opacity": .number(0.5), "background": blue]),
            DeclaredState(name: "On", setters: ["background": green]),
        ])
    }

    // MARK: - Resolved

    /// No state crosses: a control arrives with the values of the states it is in, and one it is not in says
    /// nothing.
    func testAControlArrivesWithTheValuesOfTheStatesItIsIn() {
        func control(_ enabled: Bool) -> Node {
            Button("Save").isEnabled(enabled).visualState(.disabled) { $0.background(.gray) }.id("c").body
        }

        let enabled = render(Renders(), control(true))
        XCTAssertNil(enabled?.props["background"])
        XCTAssertTrue(enabled?.children.isEmpty ?? false, "no state crosses")

        XCTAssertEqual(render(Renders(), control(false))?.props["background"], gray)
    }

    /// Leaving a state gives the control its own values back, and a value only the state set is cleared.
    func testLeavingAStateGivesTheControlItsOwnValuesBack() {
        func control(_ enabled: Bool) -> Node {
            Button("Save")
                .background(.blue)
                .isEnabled(enabled)
                .visualState(.disabled) { $0.background(.gray).opacity(0.5) }
                .id("c")
                .body
        }
        let renders = Renders()
        let disabled = render(renders, control(false))
        XCTAssertEqual(disabled?.props["background"], gray)
        XCTAssertEqual(disabled?.props["opacity"], .number(0.5))

        let enabled = render(renders, control(true))
        XCTAssertEqual(enabled?.props["background"], blue)
        XCTAssertEqual(enabled?.cleared, ["opacity"])
    }

    /// Every state that holds shows at once, the first in precedence winning a value two set: a disabled switch
    /// that is on shows Disabled's values, and On's where Disabled sets none.
    func testEveryStateThatHoldsShowsTheFirstWinningAValue() {
        let patch = render(Renders(), Switch(true)
            .isEnabled(false)
            .visualState(.on) { $0.background(.green).translationX(4) }
            .visualState(.disabled) { $0.opacity(0.5).background(.gray) }
            .id("c")
            .body)

        XCTAssertEqual(patch?.props["opacity"], .number(0.5))
        XCTAssertEqual(patch?.props["background"], gray, "Disabled before On")
        XCTAssertEqual(patch?.props["translationX"], .number(4), "and On's own")
    }

    /// A state the value follows follows the value the control is bound to: a switch turned on enters On, the
    /// element described again alone.
    func testAStateFollowsTheValueItsControlIsBoundTo() {
        let on = State(wrappedValue: false)
        let renders = Renders()
        let first = render(renders, Switch(on.projectedValue).visualState(.on) { $0.background(.green) }.id("c").body)
        XCTAssertNil(first?.props["background"])

        Renderer.shared.clearInvalidation()
        on.wrappedValue = true
        let turned = renders.revisit(changed: Renderer.shared.pendingChanges).child("c")
        XCTAssertEqual(turned?.props["background"], green)
    }

    /// The user's turn of a bound switch, as the host reports it, enters On the same way.
    func testTheUsersTurnEntersTheStateItFollows() throws {
        let on = State(wrappedValue: false)
        let renders = Renders()
        let first = try XCTUnwrap(render(renders, Switch(on.projectedValue).visualState(.on) { $0.background(.green) }.id("c").body))
        let binding = try XCTUnwrap(first.driven?.bindings["isOn"], "isOn is carried")

        Renderer.shared.clearInvalidation()
        XCTAssertTrue(Renderer.shared.hostReported(.lanes([1]), through: binding))
        let turned = renders.revisit(changed: Renderer.shared.pendingChanges).child("c")
        XCTAssertEqual(turned?.props["background"], green)
    }

    // MARK: - What the user does

    /// A pressed state hears the button's press and release and nothing more; a press describes the button again
    /// in its pressed look, and the release gives its own back.
    func testAPressDescribesTheButtonAgainInItsPressedLook() throws {
        let renders = Renders()
        let button = try XCTUnwrap(render(renders, Button("Save").visualState(.pressed) { $0.background(.green) }.id("c").body))
        XCTAssertEqual(button.eventNames, ["pressed", "released"])

        XCTAssertEqual(fire(renders, button, "pressed")?.props["background"], green)
        XCTAssertEqual(fire(renders, button, "released")?.cleared, ["background"])
    }

    /// The first state that holds by precedence wins: Disabled before Pressed, PointerOver before Focused, and
    /// Normal's values show where none holds.
    func testTheFirstStateThatHoldsWinsAValue() throws {
        let renders = Renders()
        let lamp = try XCTUnwrap(render(renders, Button("Lamp")
            .visualState(.normal) { $0.opacity(1) }
            .visualState(.focused) { $0.opacity(0.9) }
            .visualState(.pointerOver) { $0.opacity(0.8) }
            .id("c")
            .body))
        XCTAssertEqual(lamp.props["opacity"], .number(1))
        XCTAssertEqual(lamp.eventNames, ["isFocusedChanged", "pointerEntered", "pointerExited"])

        XCTAssertEqual(fire(renders, lamp, "isFocusedChanged", [.bool(true)])?.props["opacity"], .number(0.9))
        XCTAssertEqual(fire(renders, lamp, "pointerEntered")?.props["opacity"], .number(0.8), "over the focus")
        XCTAssertEqual(fire(renders, lamp, "pointerExited")?.props["opacity"], .number(0.9))
        XCTAssertEqual(fire(renders, lamp, "isFocusedChanged", [.bool(false)])?.props["opacity"], .number(1))

        let disabled = try XCTUnwrap(render(Renders(), Button("Save")
            .isEnabled(false)
            .visualState(.pressed) { $0.background(.green) }
            .visualState(.disabled) { $0.background(.gray) }
            .id("c")
            .body))
        XCTAssertEqual(disabled.props["background"], gray, "disabled before pressed")
    }

    // MARK: - Heard

    /// `.onVisualStateChanged` runs after the render that entered a state, never for the state the control arrives
    /// in; naming none hears every state, Normal included.
    func testAStateEnteredIsHeardAfterItsRender() throws {
        let renders = Renders()
        var heard: [String] = []
        let button = try XCTUnwrap(render(renders, Button("Save")
            .visualState(.pressed) { $0.background(.green) }
            .onVisualStateChanged { heard.append($0.name) }
            .id("c")
            .body))
        XCTAssertEqual(heard, [], "not for the state it arrives in")

        _ = fire(renders, button, "pressed")
        _ = fire(renders, button, "released")
        XCTAssertEqual(heard, ["Pressed", "Normal"])
    }

    /// Naming states declares them without changing the look, and only they are heard - as the typed state.
    func testAListenerDeclaresTheStatesItNamesAndHearsOnlyThem() throws {
        let node = Button("Save").onVisualStateChanged(.pressed) { _ in }.node
        XCTAssertEqual(node.visualStates, [DeclaredState(name: "Pressed")])

        let renders = Renders()
        var heard: [String] = []
        let button = try XCTUnwrap(render(renders, Button("Save")
            .onVisualStateChanged(.pressed) { heard.append($0 == .pressed ? "pressed" : $0.name) }
            .id("c")
            .body))

        _ = fire(renders, button, "pressed")
        _ = fire(renders, button, "released")
        XCTAssertEqual(heard, ["pressed"])
    }

    /// A style's states are the control's: its pressed look shows on a press, and declaring the state to hear it
    /// keeps that look.
    func testAStylesStateShowsAndHearingItKeepsItsLook() throws {
        let sheet = StyleSheet { Style<Button>().visualState(.pressed) { $0.background(.green) } }
        let renders = Renders()
        var heard: [String] = []
        let button = try XCTUnwrap(renders.render(
            stack([Button("Save").onVisualStateChanged(.pressed) { heard.append($0.name) }.id("c").body], id: "root"),
            styles: sheet).child("c"))

        Renderer.shared.clearInvalidation()
        XCTAssertTrue(renders.fire(button.events?["pressed"] ?? -1))
        let pressed = renders.revisit(changed: Renderer.shared.pendingChanges).child("c")
        XCTAssertEqual(pressed?.props["background"], green)
        XCTAssertEqual(heard, ["Pressed"])
    }
}
