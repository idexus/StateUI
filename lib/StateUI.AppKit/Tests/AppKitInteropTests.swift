// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// An application's own acts and events - the ones with no control behind
/// them, which is what an application registers with this host.
private enum InteropTestContract: ApplicationTier {
    static let name = "InteropTest"

    /// Answers twice what it was given.
    static let doubled = ElementAct<Self, Int, Int>("InteropTest.Doubled")

    /// Registered by no test, so a call on it is refused.
    static let unregistered = ElementAct<Self, Void, Void>("InteropTest.Unregistered")

    /// Raised by the host, with what it said.
    static let spoke = ElementEvent<Self, String>("InteropTest.Spoke")

    static let members: [any ContractMember] = [doubled, unregistered, spoke]
}

/// A page that calls the acts and listens for the event, writing whatever
/// came back where a test can read it.
private struct Calling: ContentView {
    @State private var answer = "-"
    @State private var heard: [HostEventSubscription] = []

    var content: any View {
        VStack {
            Button("Ask")
                .onClicked {
                    do {
                        let doubled = try await stateUICall(InteropTestContract.doubled, 21)
                        answer = "\(doubled)"
                    } catch {
                        answer = "thrown: \(error)"
                    }
                }

            Button("Ask nobody")
                .onClicked {
                    do {
                        try await stateUICall(InteropTestContract.unregistered)
                        answer = "that should have thrown"
                    } catch {
                        answer = "thrown: \(error)"
                    }
                }

            Label(answer)
        }
        .onCreated {
            heard = [
                HostEvents.on(InteropTestContract.spoke) { said in answer = "heard \(said)" },
            ]
        }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
    }
}

/// What an APPLICATION registers with this host: the acts it performs and the
/// events it raises, neither of which any control stands behind.
final class AppKitInteropTests: XCTestCase {
    /// Pumps until `done` holds - an act's answer resumes its handler, and the
    /// handler's write renders on the next pump.
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

    /// An act the application registered is performed and answers the values
    /// its contract declares.
    @MainActor
    func testAnActTheApplicationRegisteredIsPerformedAndAnswers() throws {
        AppKitInterop.forgetPerformers()
        defer { AppKitInterop.forgetPerformers() }

        StateUIAppKit.performs(InteropTestContract.doubled) { number in number * 2 }

        let renderer = AppKitRenderer.running { Calling() }
        defer { renderer.closeForTesting() }
        let buttons = renderer.nativeViews(AppKitButtonView.self)
        XCTAssertEqual(buttons.count, 2)

        buttons[0].clickForTesting()
        settle(renderer) { said(renderer) != "-" }

        XCTAssertEqual(said(renderer), "42", "the performer answered, typed both ways")
    }

    /// An act nothing registered is refused by name, so a caller waiting on it
    /// throws rather than waiting for an answer nobody will send.
    @MainActor
    func testAnActNobodyRegisteredIsRefusedByName() throws {
        AppKitInterop.forgetPerformers()
        defer { AppKitInterop.forgetPerformers() }

        let renderer = AppKitRenderer.running { Calling() }
        defer { renderer.closeForTesting() }
        let buttons = renderer.nativeViews(AppKitButtonView.self)

        buttons[1].clickForTesting()
        settle(renderer) { said(renderer) != "-" }

        let answer = try XCTUnwrap(said(renderer))
        XCTAssertTrue(answer.hasPrefix("thrown:"), answer)
        XCTAssertTrue(answer.contains("InteropTest.Unregistered"), answer)
    }

    /// An event the host raises reaches every subscription to it, carrying the
    /// values the contract declares.
    @MainActor
    func testAnEventTheHostRaisesReachesItsSubscriptions() throws {
        AppKitInterop.forgetPerformers()
        defer { AppKitInterop.forgetPerformers() }

        let renderer = AppKitRenderer.running { Calling() }
        defer { renderer.closeForTesting() }
        XCTAssertEqual(said(renderer), "-")

        let heard = StateUIAppKit.raise(InteropTestContract.spoke, "hello")
        settle(renderer) { said(renderer) != "-" }

        XCTAssertEqual(heard, 1, "the page subscribed while it is in the tree")
        XCTAssertEqual(said(renderer), "heard hello")
    }
}
#endif
