// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// An item on a bar is styled as a control is: a style for every one of its kind or by its key, its own values over
// it, and its visual states followed from the pointer and the press.

import XCTest
@_spi(Host) @testable import StateUI

extension StyleKey where Target == ToolbarButton {
    fileprivate static let outlined = StyleKey("Outlined")
}

@MainActor
final class BarItemStyleTests: XCTestCase {
    private let green = Color(hex: 0x008000).propValue
    private let blue = Color(hex: 0x0000FF).propValue

    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
    }

    /// Renders `item` alone in a stack, as the element "c", under `styles`.
    private func render(_ renders: Renders, _ item: Node, styles: StyleSheet? = nil) -> HostPatch? {
        renders.render(stack([item], id: "root"), styles: styles).child("c")
    }

    /// Runs the handler the element answers `event` with, then walks what it wrote.
    private func fire(_ renders: Renders, _ patch: HostPatch, _ event: Event) -> HostPatch? {
        Renderer.shared.clearInvalidation()
        XCTAssertTrue(renders.fire(patch.events?[event] ?? -1, with: []), "\(event) is heard")
        return renders.revisit(changed: Renderer.shared.pendingChanges).child("c")
    }

    /// A style every item of a kind wears dresses each one, and a keyed one the item asking for it.
    func testAStyleDressesTheItemsItIsFor() throws {
        let sheet = StyleSheet {
            Style<ToolbarButton>().background(.green)
            Style<ToolbarButton>(.outlined).stroke(.blue).lineWidth(1)
        }

        let plain = try XCTUnwrap(render(Renders(), ToolbarButton("Save").id("c").node, styles: sheet))
        let outlined = try XCTUnwrap(render(Renders(), ToolbarButton("Sign out").style(.outlined).id("c").node,
                                            styles: sheet))

        XCTAssertEqual(plain.props["background"], Material.color(Color(hex: 0x008000)).propValue)
        XCTAssertEqual(outlined.props["stroke"], Brush.solidColor(Color(hex: 0x0000FF)).propValue)
        XCTAssertNil(outlined.props["background"], "a keyed style stands in place of the one every item wears")
    }

    /// An item's own state is written on it: the pointer coming over it shows the state's values, and leaving gives
    /// its own back.
    func testAButtonsStateFollowsThePointer() throws {
        let renders = Renders()
        let item = ToolbarButton("Share").visualState(.pointerOver) { $0.textColor(.green) }.id("c")
        let button = try XCTUnwrap(render(renders, item.node))
        XCTAssertEqual(button.eventNames, ["pointerEntered", "pointerExited"])

        XCTAssertEqual(fire(renders, button, "pointerEntered")?.props["textColor"], green)
        XCTAssertEqual(fire(renders, button, "pointerExited")?.cleared, ["textColor"])
    }

    /// A button on a bar is pressed as a button is.
    func testAButtonsPressShowsItsPressedLook() throws {
        let renders = Renders()
        let item = ToolbarButton("Share").visualState(.pressed) { $0.textColor(.green) }.id("c")
        let button = try XCTUnwrap(render(renders, item.node))

        XCTAssertEqual(fire(renders, button, "pressed")?.props["textColor"], green)
        XCTAssertEqual(fire(renders, button, "released")?.cleared, ["textColor"])
    }

    /// A group follows the pointer over it: its outline takes another color.
    func testAGroupsOutlineFollowsThePointer() throws {
        let renders = Renders()
        var group = ToolbarGroup { ToolbarButton("Add") }
            .stroke(.green)
            .visualState(.pointerOver) { $0.stroke(.blue) }
            .node
        group.identify("c")
        let shown = try XCTUnwrap(render(renders, group))

        XCTAssertEqual(shown.props["stroke"], Brush.solidColor(Color(hex: 0x008000)).propValue)
        XCTAssertEqual(fire(renders, shown, "pointerEntered")?.props["stroke"], Brush.solidColor(Color(hex: 0x0000FF)).propValue)
    }

    /// A setting wears its on look while it stands on.
    func testASettingWearsItsOnLook() throws {
        let item = ToolbarToggle("Pin", isOn: true).visualState(.on) { $0.textColor(.blue) }.id("c")

        XCTAssertEqual(try XCTUnwrap(render(Renders(), item.node)).props["textColor"], blue)
    }

    /// A group style dresses every group on a bar: one its author declared, and a lone item's own.
    func testAGroupStyleDressesEveryGroupOnABar() throws {
        let sheet = StyleSheet { Style<ToolbarGroup>().background(.green) }
        var declared = ToolbarGroup { ToolbarButton("Add") }.node
        declared.identify("c")
        var lone = ToolbarButton("Sort").standingAlone
        lone.identify("c")

        XCTAssertEqual(try XCTUnwrap(render(Renders(), declared, styles: sheet)).props["background"],
                       Material.color(Color(hex: 0x008000)).propValue)
        XCTAssertEqual(try XCTUnwrap(render(Renders(), lone, styles: sheet)).props["background"],
                       Material.color(Color(hex: 0x008000)).propValue)
    }
}
