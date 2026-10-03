// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import UIKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIUIKit
import XCTest

/// An application's own acts and events - the ones with no control behind them.
private enum InteropTestContract: ApplicationTier {
    static let name = "InteropTest"

    /// Answers twice what it was given.
    static let doubled = ElementAct<Self, Int, Int>("InteropTest.Doubled")

    /// Registered by no test, so a call on it is refused.
    static let unregistered = ElementAct<Self, Void, Void>("InteropTest.Unregistered")

    /// Raised by the application, with what it said.
    static let spoke = ElementEvent<Self, String>("InteropTest.Spoke")

    static let members: [any ContractMember] = [doubled, unregistered, spoke]
}

/// An element the application declares, realized by a view the application wrote.
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

/// The view this host makes for a lamp - an ordinary `UIView` that knows nothing of StateUI.
final class LampView: UIView {
    var lit = false
    var flashes = 0
    var pulls = 0
    var onPulled: ((Int) -> Void)?

    /// Pulls it, as a user does.
    func pull() {
        pulls += 1
        onPulled?(pulls)
    }
}

/// The Swift half of the lamp, which the application writes.
private struct Lamp: ElementView {
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

/// A page calling the application's acts, hearing its event, and holding one lamp - saying what came back.
private struct Calling: View {
    @State private var said = "-"
    @State private var heard: [HostEventSubscription] = []
    @Aim(Lamp.self) private var lamp

    var body: some View {
        VStack {
            Button("Ask").onClicked {
                do {
                    let doubled = try await stateUICall(InteropTestContract.doubled, 21)
                    said = "\(doubled)"
                } catch {
                    said = "thrown: \(error)"
                }
            }
            Button("Ask nobody").onClicked {
                do {
                    try await stateUICall(InteropTestContract.unregistered)
                    said = "that should have thrown"
                } catch {
                    said = "thrown: \(error)"
                }
            }
            Button("Flash").onClicked {
                do {
                    try await lamp.flash()
                    said = "flashed"
                } catch {
                    said = "thrown: \(error)"
                }
            }
            Lamp().lit(true).onPulled { pulls in said = "pulled \(pulls)" }.aim(lamp)
            Text(said)
        }
        .onCreated { heard = [HostEvents.on(InteropTestContract.spoke) { words in said = "heard \(words)" }] }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
    }
}

/// What an application registers with this host: the acts it performs, the events it raises, and its own elements,
/// each realized by a view of its own.
final class UIKitInteropTests: XCTestCase {
    /// Registers the lamp once for the process - a registry keeps what it is told.
    @MainActor
    private static func registerLamp() {
        StateUIControls.add(LampContract.self, create: { reports -> LampView in
            let lamp = LampView()
            lamp.onPulled = { pulls in reports.raise(LampContract.pulled, pulls) }
            return lamp
        }) { lamp in
            lamp.property(LampContract.lit) { view, lit in view.lit = lit ?? false }
            lamp.raises(LampContract.pulled)
        }
        StateUIActs.add(LampContract.flash, on: LampView.self) { lamp in lamp.flashes += 1 }
    }

    /// A host running the calling page, the lamp registered.
    @MainActor
    private func running() -> UIKitRenderer {
        Self.registerLamp()
        StateUIEvents.raises(InteropTestContract.spoke)
        return UIKitRenderer.running { Calling() }
    }

    /// Presses the button captioned `caption` as a tap does, and waits until the page said something.
    @MainActor
    private func press(_ caption: String, on host: UIKitRenderer) throws {
        let button = try XCTUnwrap(host.views(UIKitButtonView.self).first { $0.configuration?.title == caption })
        button.sendActions(for: .primaryActionTriggered)
        host.settle { said(host) != "-" }
    }

    /// The last thing the page said.
    @MainActor
    private func said(_ host: UIKitRenderer) -> String? {
        host.views(UIKitTextView.self).last?.attributedText?.string
    }

    /// An act the application registered is performed and answers the values its contract declares.
    @MainActor
    func testAnActTheApplicationRegisteredIsPerformedAndAnswers() throws {
        defer { UIKitInterop.acts.forget(InteropTestContract.doubled.token) }
        let host = running()
        defer { host.finish() }
        StateUIActs.add(InteropTestContract.doubled) { number in number * 2 }

        try press("Ask", on: host)

        XCTAssertEqual(said(host), "42")
    }

    /// An act nothing registered is refused by name, so its caller throws rather than waits.
    @MainActor
    func testAnActNobodyRegisteredIsRefusedByName() throws {
        let host = running()
        defer { host.finish() }

        try press("Ask nobody", on: host)

        let answer = try XCTUnwrap(said(host))
        XCTAssertTrue(answer.hasPrefix("thrown:") && answer.contains("InteropTest.Unregistered"), answer)
    }

    /// An event the application raises reaches every subscription to it, carrying the values its contract
    /// declares.
    @MainActor
    func testAnEventTheApplicationRaisesReachesItsSubscriptions() throws {
        let host = running()
        defer { host.finish() }

        let heard = StateUIEvents.raise(InteropTestContract.spoke, "hello")
        host.settle { said(host) != "-" }

        XCTAssertEqual(heard, 1)
        XCTAssertEqual(said(host), "heard hello")
    }

    /// The application's own element is made by its registration, takes its property, and raises its event to the
    /// handler the tree put on it.
    @MainActor
    func testTheApplicationsOwnElementIsMadeTakesItsPropertyAndRaises() throws {
        let host = running()
        defer { host.finish() }
        let lamp = try XCTUnwrap(host.views(LampView.self).first)
        XCTAssertTrue(lamp.lit)

        lamp.pull()
        host.settle { said(host) != "-" }

        XCTAssertEqual(said(host), "pulled 1")
    }

    /// An act aimed at the application's own element is handed that element's view.
    @MainActor
    func testAnAimedActIsHandedTheApplicationsOwnView() throws {
        let host = running()
        defer { host.finish() }
        let lamp = try XCTUnwrap(host.views(LampView.self).first)

        try press("Flash", on: host)

        XCTAssertEqual(said(host), "flashed")
        XCTAssertEqual(lamp.flashes, 1)
    }

    /// The application's own element is the application's, not what this host declares of the library.
    @MainActor
    func testTheApplicationsOwnElementIsNotWhatThisHostDeclares() {
        Self.registerLamp()

        XCTAssertTrue(UIKitRegistrations.registry.realization.elements.contains(LampContract.nodeType.name))
        XCTAssertNil(LibraryContracts.elements.first { $0.nodeType.name == LampContract.nodeType.name })
    }
}
