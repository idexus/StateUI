// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// An element of the suite's own, as an application declares one.
enum ProbeContract: ElementContract {
    static let nodeType: NodeType = "WebTests.Probe"
    static let tiers: [any Contract.Type] = [ViewContract.self]
    static let tone = ElementProperty<Self, Double>("tone")
    static let members: [any ContractMember] = [tone]
}

/// The application's control for it: the page's element it shows, and the value it was handed.
@MainActor
final class ProbeControl: WebControl {
    let element = WebPageElement(tag: "test-probe")
    var tone: Double?
}

/// A control the application registers stands in the tree on its own element, handed the values its contract
/// declares.
@MainActor
final class WebInteropTests: XCTestCase {
    func testARegisteredControlStandsOnItsOwnElement() throws {
        let made = ProbeControl()
        StateUIControls.add(ProbeContract.self, create: { _ in made }) { probe in
            probe.property(ProbeContract.tone) { control, tone in control.tone = tone }
        }
        let view = try XCTUnwrap(WebRegistrations.registry.makeView(
            for: ProbeContract.nodeType, sending: { _, _ in }, reporting: { _, _, _ in }))
        defer { view.detach() }

        XCTAssertEqual(view.node, made.element.node, "the host's view is the control's own element")
        WebRegistrations.registry.apply(
            [Prop(ProbeContract.tone.name)], to: view, of: ProbeContract.nodeType, reading: { _ in .number(0.4) })
        XCTAssertEqual(made.tone, 0.4)
    }

    /// What the application's scripts tell reaches every hearer of its name, with the words told.
    func testWhatTheScriptsTellIsHeard() {
        var heard: [String] = []
        StateUIScripts.hear("battery") { heard.append($0) }
        WebPage.tell("battery", "0.8 true")
        WebPage.tell("connection", "none")
        XCTAssertEqual(heard, ["0.8 true"])
    }
}
