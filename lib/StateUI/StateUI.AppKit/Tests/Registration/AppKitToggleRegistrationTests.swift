// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import StateUIConformance
import XCTest

/// The toggles, realized through the registry: a switch and a check box made
/// by their registrations, their members reaching the native controls, and
/// what their user does reported by member - onto the state the value is
/// carried in, and to the handler that listens for it.
@MainActor
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
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var on = HostPatch(id: .manual("toggle"), type: .switch)
        on.properties[.isOn] = .bool(true)
        on.properties[.isEnabled] = .bool(false)
        renderer.applyForTesting(tree(on))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("toggle")) as? AppKitSwitchView)
        XCTAssertEqual(native.state, .on)
        XCTAssertFalse(native.control.isEnabled)

        var off = HostPatch(id: .manual("toggle"), type: .switch)
        off.properties[.isOn] = .bool(false)
        off.properties[.isEnabled] = .bool(true)
        renderer.applyForTesting(changedTree(off))

        XCTAssertEqual(native.state, .off)
        XCTAssertTrue(native.control.isEnabled)
    }

    /// A switch and a check box say the words the tree gives them, in their case: the check box as its own title;
    /// the switch's beside it at its start, the switch at its end, naming it for assistive technology and flipping
    /// it at a click.
    @MainActor
    func testATogglesWordsStandBesideIt() throws {
        let on = State(wrappedValue: false)
        let renderer = AppKitRenderer.running {
            VStack {
                Switch(on.projectedValue).text("Wi-Fi")
                CheckBox(true).text("agree").textCase(.uppercase)
            }
        }
        defer { renderer.closeForTesting() }
        let toggle = try XCTUnwrap(renderer.nativeViews(AppKitSwitchView.self).first)
        let box = try XCTUnwrap(renderer.nativeViews(AppKitCheckBoxView.self).first)

        XCTAssertEqual(box.title, "AGREE")
        XCTAssertEqual(toggle.caption.stringValue, "Wi-Fi")
        XCTAssertEqual(toggle.control.accessibilityLabel(), "Wi-Fi", "the switch named by its words")
        toggle.frame = NSRect(x: 0, y: 0, width: 300, height: 30)
        toggle.layoutSubtreeIfNeeded()
        XCTAssertEqual(toggle.control.frame.maxX, 300, "the switch at the end")
        XCTAssertEqual(toggle.caption.frame.minX, 0, "the words from the start")

        toggle.clickWordsForTesting()
        XCTAssertTrue(on.wrappedValue, "a click on the words flips it")
    }

    /// A switch stands as wide as its words and itself need, its words whole - and again as they grow longer.
    @MainActor
    func testASwitchStandsWideEnoughForItsWords() throws {
        let words = State(wrappedValue: "Wi-Fi")
        let renderer = AppKitRenderer.running {
            VStack {
                Switch(true).text(words.wrappedValue).horizontalAlignment(.start)
            }
            .motion(.none)
        }
        defer { renderer.closeForTesting() }
        let toggle = try XCTUnwrap(renderer.nativeViews(AppKitSwitchView.self).first)
        let layOut = { toggle.window?.contentView?.layoutSubtreeIfNeeded() }
        layOut()
        XCTAssertGreaterThanOrEqual(toggle.caption.frame.width, try XCTUnwrap(toggle.caption.cell).cellSize.width - 0.01)

        words.wrappedValue = "Platform look and every word after it"
        renderer.runtime.pump.turn()
        layOut()

        XCTAssertGreaterThanOrEqual(
            toggle.caption.frame.width, try XCTUnwrap(toggle.caption.cell).cellSize.width - 0.01, "the longer words whole")
    }

    /// A switch whose width travels as its words grow stands its words whole once it lands: its parts stand again
    /// at every size its place passes through, the last one included.
    @MainActor
    func testASwitchsWordsStandWholeOnceItsWidthLands() throws {
        var now = 0.0
        let words = State(wrappedValue: "Wi-Fi")
        stateUIUseApp(OneWindowApplication {
            VStack {
                Switch(true).text(words.wrappedValue).horizontalAlignment(.start)
            }
            .motion(.eased(.milliseconds(1000), .linear))
        })
        let renderer = testRenderer(clock: { now })
        renderer.startForTesting()
        defer { renderer.closeForTesting() }
        let toggle = try XCTUnwrap(renderer.nativeViews(AppKitSwitchView.self).first)
        let layOut = { toggle.window?.contentView?.layoutSubtreeIfNeeded() }
        layOut()

        words.wrappedValue = "Platform look and every word after it"
        renderer.runtime.pump.turn()
        layOut()
        for step in 1...6 {
            now = Double(step) * 250
            renderer.displayFrameForTesting()
            layOut()
        }

        XCTAssertGreaterThanOrEqual(
            toggle.caption.frame.width, try XCTUnwrap(toggle.caption.cell).cellSize.width - 0.01, "the longer words whole")
    }

    /// A check box's tint is its box's: its words keep the platform's color, which AppKit's content tint would
    /// otherwise draw them in.
    @MainActor
    func testATintedCheckBoxsWordsKeepThePlatformsColor() throws {
        let renderer = AppKitRenderer.running {
            VStack { CheckBox(false).text("WWWWWW").tint(Color(hex: 0xFF0000)) }
        }
        defer { renderer.closeForTesting() }
        let box = try XCTUnwrap(renderer.nativeViews(AppKitCheckBoxView.self).first)
        box.frame = NSRect(origin: .zero, size: box.fittingSize)

        let drawn = try XCTUnwrap(box.bitmapImageRepForCachingDisplay(in: box.bounds))
        box.cacheDisplay(in: box.bounds, to: drawn)
        let red = (0..<drawn.pixelsWide).flatMap { x in (0..<drawn.pixelsHigh).map { (x, $0) } }.filter { x, y in
            guard let color = drawn.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
            return color.alphaComponent > 0.5 && color.redComponent > 0.7 && color.greenComponent < 0.3
        }
        XCTAssertEqual(red.count, 0, "the unticked box's words drawn in its tint")
    }

    /// A check box takes its value and the tint its tier declares - the color
    /// converted where the registration reads it, as a color and not a
    /// number.
    @MainActor
    func testACheckBoxTakesItsValueAndItsTint() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
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

    /// What the user does reaches both halves at once: the state the value is
    /// carried in takes it, and the handler listening for the event hears it.
    @MainActor
    func testAUsersToggleReachesTheStateAndTheHandler() throws {
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

        XCTAssertTrue(on.wrappedValue, "the state the switch is tied to takes the user's value")
        XCTAssertEqual(heard.values, [true], "and the handler hears it once")
    }

    /// A toggle nobody takes keeps what the user made it until the tree
    /// describes another value: a registration applies what changed, where the
    /// arms it replaces put the described value back at the element's next
    /// pass, whatever had changed.
    @MainActor
    func testAToggleNobodyTakesKeepsTheUsersValueUntilTheTreeSaysOtherwise() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var off = HostPatch(id: .manual("toggle"), type: .switch)
        off.properties[.isOn] = .bool(false)
        renderer.applyForTesting(tree(off))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("toggle")) as? AppKitSwitchView)
        native.toggleForTesting()

        XCTAssertEqual(native.state, .on, "nothing carries the value, so nothing answers the user")

        var moved = HostPatch(id: .manual("toggle"), type: .switch)
        moved.properties[.margin] = .numbers([4, 4, 4, 4])
        renderer.applyForTesting(changedTree(moved))

        XCTAssertEqual(native.state, .on, "another member changing does not put the old value back")

        var described = HostPatch(id: .manual("toggle"), type: .switch)
        described.properties[.isOn] = .bool(false)
        renderer.applyForTesting(changedTree(described))

        XCTAssertEqual(native.state, .off, "the tree describing it again does")
    }

}
#endif
