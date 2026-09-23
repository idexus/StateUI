// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// An element the APPLICATION declares, realized by a view the application
/// wrote - the half this host was missing.
private enum LampContract: ElementContract {
    static let nodeType: NodeType = "InteropTest.Lamp"
    static let tiers: [any Contract.Type] = [ViewContract.self]

    /// Whether the lamp is lit.
    static let lit = ElementProperty<Self, Bool>("lit")

    /// The lamp was pulled, with how many times it has been.
    static let pulled = ElementEvent<Self, Int>("pulled")

    /// Flashes the lamp this aim is on.
    static let flash = ElementAct<Self, Void, Void>("InteropTest.Flash")

    static let members: [any ContractMember] = [lit, pulled, flash]
}

/// The view this host makes for a lamp - an ordinary `NSView` that knows
/// nothing of StateUI.
final class LampView: NSView {
    /// Whether it is lit, as the tree last said.
    var lit = false

    /// How many times the act flashed it.
    var flashes = 0

    /// How many times a user pulled it.
    var pulls = 0

    /// What it reports when pulled.
    var onPulled: ((Int) -> Void)?

    /// Pulls it, as a user does.
    func pull() {
        pulls += 1
        onPulled?(pulls)
    }
}

/// The Swift half, which the application could already write.
private struct Lamp: View {
    var node = Node(contract: LampContract.self)

    func lit(_ value: Bool) -> Self {
        setValue(LampContract.lit, value)
    }

    func onPulled(_ handler: @escaping ValueEventHandler<Int>) -> Self {
        onEvent(LampContract.pulled, handler)
    }
}

extension Aim where Target == Lamp {
    /// Flashes the lamp this aim is on.
    func flash() async throws {
        try await call(LampContract.flash)
    }
}

/// A page holding one lamp, saying what it last heard.
private struct Pulling: ContentView {
    @State private var said = "-"
    @State private var on = true
    @Aim(Lamp.self) private var lamp

    var content: any View {
        VStack {
            Lamp()
                .lit(on)
                .onPulled { pulls in said = "pulled \(pulls)" }
                .aim(lamp)

            Button("Flash")
                .onClicked {
                    do {
                        try await lamp.flash()
                        said = "flashed"
                    } catch {
                        said = "thrown: \(error)"
                    }
                }

            Label(said)
        }
    }
}

/// An element of the APPLICATION'S OWN, realized on this host by a view of the
/// application's own: made by its registration, taking the members its
/// contract declares, raising its events, and answering an act aimed at it.
final class AppKitApplicationRegistrationTests: XCTestCase {
    /// Registers the lamp once for the process - a registry keeps what it is
    /// told, so registering it per test would only replace the same entry.
    @MainActor
    private func registerLamp() {
        StateUIControls.add(LampContract.self, create: { reports -> LampView in
            let lamp = LampView()
            lamp.onPulled = { pulls in reports.raise(LampContract.pulled, pulls) }
            return lamp
        }) { lamp in
            lamp.property(LampContract.lit) { view, lit in
                view.lit = lit ?? false
            }
            lamp.raises(LampContract.pulled)
        }

        StateUIActs.add(LampContract.flash, on: LampView.self) { lamp in
            lamp.flashes += 1
        }
    }

    /// Pumps until `done` holds.
    @MainActor
    private func settle(_ renderer: AppKitRenderer, until done: () -> Bool) {
        for _ in 0..<150 where !done() {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
            renderer.pump()
        }
    }

    /// The last thing the page said.
    @MainActor
    private func said(_ renderer: AppKitRenderer) -> String? {
        renderer.nativeViews(AppKitLabelView.self).last?.textForTesting.string
    }

    /// The application's own element is made by its registration and takes the
    /// property its contract declares.
    @MainActor
    func testTheApplicationsOwnElementIsMadeAndTakesItsProperty() throws {
        registerLamp()

        let renderer = AppKitRenderer.running { Pulling() }
        defer { renderer.closeForTesting() }

        let lamp = try XCTUnwrap(renderer.nativeViews(LampView.self).first)
        XCTAssertTrue(lamp.lit, "the registration put the described value on the view")
    }

    /// An event the application's own view raises reaches the handler the tree
    /// put on it, carrying what its contract declares.
    @MainActor
    func testAnEventTheApplicationsViewRaisesReachesItsHandler() throws {
        registerLamp()

        let renderer = AppKitRenderer.running { Pulling() }
        defer { renderer.closeForTesting() }
        let lamp = try XCTUnwrap(renderer.nativeViews(LampView.self).first)

        lamp.pull()
        settle(renderer) { said(renderer) != "-" }

        XCTAssertEqual(said(renderer), "pulled 1")
    }

    /// An act AIMED at the application's own element is handed that element's
    /// view - the identity the aim sent, turned back into what is on screen.
    @MainActor
    func testAnAimedActIsHandedTheApplicationsOwnView() throws {
        registerLamp()

        let renderer = AppKitRenderer.running { Pulling() }
        defer { renderer.closeForTesting() }
        let lamp = try XCTUnwrap(renderer.nativeViews(LampView.self).first)
        let button = try XCTUnwrap(renderer.nativeViews(AppKitButtonView.self).first)
        XCTAssertEqual(lamp.flashes, 0)

        button.clickForTesting()
        settle(renderer) { said(renderer) != "-" }

        XCTAssertEqual(said(renderer), "flashed")
        XCTAssertEqual(lamp.flashes, 1, "the performer was handed the aimed view itself")
    }

    /// The application's own element is NOT part of what this host declares:
    /// an export says which of the LIBRARY's elements this host presents, and
    /// a control the application wrote is the application's.
    @MainActor
    func testTheApplicationsOwnElementIsNotWhatThisHostDeclares() {
        registerLamp()

        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(
            realization.elements.contains(LampContract.nodeType.name),
            "the registry holds it, which is what makes the view")
        XCTAssertNil(
            LibraryContracts.elements.first { $0.nodeType.name == LampContract.nodeType.name },
            "and no contract of the library declares it, which is what keeps it out of the export")
    }
}
#endif
