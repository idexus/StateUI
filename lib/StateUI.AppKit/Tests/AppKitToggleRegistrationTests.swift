// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// The toggles, realized through the registry: a switch and a check box made
/// by their registrations, their members reaching the native controls, and
/// what their reader does reported by member - onto the state the value is
/// carried in, and to the handler that listens for it.
final class AppKitToggleRegistrationTests: XCTestCase {
    /// The registry realizes both toggles: the value each carries, the event
    /// each raises, and the enabled state they take from the tier they wear.
    @MainActor
    func testTheRegistryRealizesTheToggles() {
        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(realization.elements.isSuperset(of: ["Switch", "CheckBox"]))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Switch", owner: "Switch", member: "isOn")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Switch", owner: "Switch", member: "toggled")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Switch", owner: "VisualElement", member: "isEnabled")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "CheckBox", owner: "CheckBox", member: "isOn")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "CheckBox", owner: "TintElement", member: "tint")))
    }

    /// A switch shows what the tree says and takes the enabled state with it,
    /// and follows the tree when it says otherwise.
    @MainActor
    func testASwitchShowsWhatTheTreeSays() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var on = HostPatch(id: .manual("toggle"), type: .switch)
        on.properties[.isOn] = .bool(true)
        on.properties[.isEnabled] = .bool(false)
        renderer.applyForTesting(tree(on))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("toggle")) as? AppKitSwitchView)
        XCTAssertEqual(native.state, .on)
        XCTAssertFalse(native.isEnabled)

        var off = HostPatch(id: .manual("toggle"), type: .switch)
        off.properties[.isOn] = .bool(false)
        off.properties[.isEnabled] = .bool(true)
        renderer.applyForTesting(changedTree(off))

        XCTAssertEqual(native.state, .off)
        XCTAssertTrue(native.isEnabled)
    }

    /// A check box takes its value and the tint its tier declares - the colour
    /// converted where the registration reads it, as a colour and not a
    /// number.
    @MainActor
    func testACheckBoxTakesItsValueAndItsTint() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var checked = HostPatch(id: .manual("box"), type: .checkBox)
        checked.properties[.isOn] = .bool(true)
        checked.properties[.tint] = .color(red: 51, green: 102, blue: 153, alpha: 255)
        renderer.applyForTesting(tree(checked))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")) as? AppKitCheckBoxView)
        let tint = try XCTUnwrap(native.contentTintColor?.usingColorSpace(.sRGB))

        XCTAssertEqual(native.state, .on)
        XCTAssertEqual(Double(tint.redComponent), 0.2, accuracy: 0.01)
        XCTAssertEqual(Double(tint.greenComponent), 0.4, accuracy: 0.01)
        XCTAssertEqual(Double(tint.blueComponent), 0.6, accuracy: 0.01)
    }

    /// What the reader does reaches both halves at once: the state the value is
    /// carried in takes it, and the handler listening for the event hears it.
    @MainActor
    func testAReadersToggleReachesTheStateAndTheHandler() throws {
        let on = State(wrappedValue: false)
        let heard = Received<Bool>()
        let renderer = AppKitRenderer.running {
            VStack {
                Switch(on.projectedValue)
                    .onToggled { heard.values.append($0) }
            }
        }
        defer { renderer.closeForTesting() }

        let native = try XCTUnwrap(renderer.nativeViews(AppKitSwitchView.self).first)
        native.toggleForTesting()

        XCTAssertTrue(on.wrappedValue, "the state the switch is tied to takes the reader's value")
        XCTAssertEqual(heard.values, [true], "and the handler hears it once")
    }

    /// A toggle nobody takes keeps what the reader made it until the tree
    /// describes another value: a registration applies what changed, where the
    /// arms it replaces put the described value back at the element's next
    /// pass, whatever had changed.
    @MainActor
    func testAToggleNobodyTakesKeepsTheReadersValueUntilTheTreeSaysOtherwise() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var off = HostPatch(id: .manual("toggle"), type: .switch)
        off.properties[.isOn] = .bool(false)
        renderer.applyForTesting(tree(off))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("toggle")) as? AppKitSwitchView)
        native.toggleForTesting()

        XCTAssertEqual(native.state, .on, "nothing carries the value, so nothing answers the reader")

        var moved = HostPatch(id: .manual("toggle"), type: .switch)
        moved.properties[.margin] = .numbers([4, 4, 4, 4])
        renderer.applyForTesting(changedTree(moved))

        XCTAssertEqual(native.state, .on, "another member changing does not put the old value back")

        var described = HostPatch(id: .manual("toggle"), type: .switch)
        described.properties[.isOn] = .bool(false)
        renderer.applyForTesting(changedTree(described))

        XCTAssertEqual(native.state, .off, "the tree describing it again does")
    }

    /// The registry realizes the radio button too - its own value and event,
    /// and the caption members it draws from the tiers it wears.
    @MainActor
    func testTheRegistryRealizesTheRadioButton() {
        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(realization.elements.contains("RadioButton"))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "RadioButton", owner: "RadioButton", member: "isOn")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "RadioButton", owner: "RadioButton", member: "toggled")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "RadioButton", owner: "TextElement", member: "text")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "RadioButton", owner: "TextStyleElement", member: "textColor")))
    }

    /// A radio button draws the caption the tree describes, in the case it
    /// asks for, and wears its check.
    @MainActor
    func testARadioButtonShowsItsCaptionAndItsCheck() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var large = HostPatch(id: .manual("large"), type: .radioButton)
        large.properties[.isOn] = .bool(true)
        large.properties[.text] = .string("Large")
        large.properties[.textCase] = .enumeration(3)
        renderer.applyForTesting(tree(large))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("large")) as? AppKitRadioButtonView)

        XCTAssertEqual(native.state, .on)
        XCTAssertEqual(native.title, "LARGE")
    }

    /// Picking one button of a set takes the check off the others, wherever in
    /// the window they stand: the button reports that it is on, and the host
    /// answers for the set.
    @MainActor
    func testPickingOneOfASetClearsTheOthers() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var small = HostPatch(id: .manual("small"), type: .radioButton)
        small.properties[.isOn] = .bool(true)
        small.properties[.text] = .string("Small")
        small.properties[.groupName] = .name("size")
        var large = HostPatch(id: .manual("large"), type: .radioButton)
        large.properties[.isOn] = .bool(false)
        large.properties[.text] = .string("Large")
        large.properties[.groupName] = .name("size")
        var row = HostPatch(id: .manual("row"), type: .vStack)
        row.children = .arranged([small, large])
        renderer.applyForTesting(tree(row))

        let first = try XCTUnwrap(renderer.viewForTesting(id: .manual("small")) as? AppKitRadioButtonView)
        let second = try XCTUnwrap(renderer.viewForTesting(id: .manual("large")) as? AppKitRadioButtonView)

        second.selectForTesting()

        XCTAssertEqual(second.state, .on)
        XCTAssertEqual(first.state, .off, "the set's other button lost its check")
    }
}
#endif
