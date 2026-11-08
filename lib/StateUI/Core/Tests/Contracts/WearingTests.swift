// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// A member handed to an element whose contract does not take it - one of a contract it does not wear, or one its
/// contract leaves out of `members` - compiles, so the description says it once, by every road an author writes.
@MainActor
final class WearingTests: XCTestCase {
    func testAPropertyOfAContractTheElementDoesNotWearIsSaid() {
        _ = Beacon().setValue(RangeElementContract.value, 3)

        XCTAssertTrue(hasComplained("Test.Beacon was handed `RangeElement.value`, and Test.Beacon wears no RangeElement"))
    }

    func testAStateOfAContractTheElementDoesNotWearIsSaid() {
        _ = Beacon().setValue(
            RangeElementContract.maximum, on: State(wrappedValue: 1.0).projectedValue, as: .journey)

        XCTAssertTrue(hasComplained("Test.Beacon was handed `RangeElement.maximum`"))
    }

    func testAnEventOfAContractTheElementDoesNotWearIsSaid() {
        _ = Beacon().onEvent(ClickElementContract.clicked) {}

        XCTAssertTrue(hasComplained("Test.Beacon was handed `ClickElement.clicked`"))
    }

    func testAMemberLeftOutOfTheContractsMembersIsSaid() {
        _ = Beacon().setValue(BeaconContract.unlisted, 2)

        XCTAssertTrue(hasComplained("`Test.Beacon.unlisted` is not among Test.Beacon's members"))
    }

    func testATierProtocolTheContractDoesNotListIsSaid() {
        _ = Beacon().fontSize(12)

        XCTAssertTrue(hasComplained("Test.Beacon was handed `FontElement.fontSize`"))
    }

    func testWhatTheElementWearsIsSaidNothing() {
        _ = Beacon().setValue(BeaconContract.glow, 0.5).opacity(0.5).onEvent(BeaconContract.flashed) {}

        XCTAssertFalse(hasComplained("Test.Beacon was handed `Test.Beacon.glow`"))
        XCTAssertFalse(hasComplained("Test.Beacon was handed `View.opacity`"))
        XCTAssertFalse(hasComplained("Test.Beacon was handed `Test.Beacon.flashed`"))
    }

    func testAnActOfAContractTheAimedElementDoesNotWearIsSaid() async throws {
        let renders = Renders()
        let beacon = Aim(Beacon.self)
        renders.render(stack([Beacon().aim(beacon).node], id: "root"))
        _ = drainedActs()

        let called = Task.immediate { @MainActor in try await beacon.call(WebViewContract.goBack) }
        for id in drainedActs().compactMap(\.completion) {
            ReplyBuffer.current = .finished([])
            _ = Renderer.shared.dispatch(id)
        }
        stateUIRunJobs()
        _ = try? await called.value

        XCTAssertTrue(hasComplained("Test.Beacon was handed `WebView.goBack`"))
    }

    func testATestReadsWhetherAnElementWearsAContract() {
        _ = Beacon()

        XCTAssertEqual(Wearing.element(BeaconContract.nodeType, wears: ViewContract.self), true)
        XCTAssertEqual(Wearing.element(BeaconContract.nodeType, wears: SliderContract.self), false)
        XCTAssertNil(Wearing.element("Test.NeverMade", wears: ViewContract.self))
    }
}

/// An element of an application's own: a view with a glow of its own.
private enum BeaconContract: ElementContract {
    static let nodeType: NodeType = "Test.Beacon"
    static let tiers: [any Tier.Type] = [ViewContract.self]

    static let glow = ElementProperty<Self, Double>("glow")
    static let flashed = ElementEvent<Self, Void>("flashed")
    static let unlisted = ElementProperty<Self, Double>("unlisted")

    static let members: [any ContractMember] = [glow, flashed]
}

/// The element's view, wearing a tier protocol its contract does not list.
private struct Beacon: ElementView, FontElement {
    var node = Node(contract: BeaconContract.self)
}
