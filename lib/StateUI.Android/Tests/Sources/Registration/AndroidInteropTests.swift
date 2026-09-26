// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
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

/// A page that calls the acts and listens for the event, showing whatever came back.
private struct Calling: ContentView {
    @State private var answer = "-"
    @State private var heard: [HostEventSubscription] = []

    var content: any View {
        VStack {
            Button("Ask").onClicked {
                do {
                    let doubled = try await stateUICall(InteropTestContract.doubled, 21)
                    answer = "\(doubled)"
                } catch {
                    answer = "thrown: \(error)"
                }
            }
            Button("Ask nobody").onClicked {
                do {
                    try await stateUICall(InteropTestContract.unregistered)
                    answer = "that should have thrown"
                } catch {
                    answer = "thrown: \(error)"
                }
            }
            Label(answer)
        }
        .onCreated { heard = [HostEvents.on(InteropTestContract.spoke) { said in answer = "heard \(said)" }] }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
    }
}

/// What an application registers with this host: the acts it performs and the events it raises.
final class AndroidInteropTests: XCTestCase {
    static var allTests: [(String, (AndroidInteropTests) -> () throws -> Void)] {
        [
            ("testAnActTheApplicationRegisteredIsPerformedAndAnswers", testAnActTheApplicationRegisteredIsPerformedAndAnswers),
            ("testAnActNobodyRegisteredIsRefusedByName", testAnActNobodyRegisteredIsRefusedByName),
            ("testAnEventTheApplicationRaisesReachesItsListeners", testAnEventTheApplicationRaisesReachesItsListeners),
        ]
    }

    /// An act the application registered is performed and answers the values its contract declares.
    func testAnActTheApplicationRegisteredIsPerformedAndAnswers() throws {
        try onMainActor {
            AndroidInterop.acts.forget()
            defer { AndroidInterop.acts.forget() }
            StateUIActs.add(InteropTestContract.doubled) { number in number * 2 }
            let host = AndroidRenderer.running { Calling() }

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            host.settle { host.views(AndroidLabelView.self).first?.text != "-" }

            XCTAssertEqual(host.views(AndroidLabelView.self).map(\.text), ["42"], "answered, typed both ways")
        }
    }

    /// An act nothing registered is refused by name, so a caller waiting on it throws.
    func testAnActNobodyRegisteredIsRefusedByName() throws {
        try onMainActor {
            AndroidInterop.acts.forget()
            let host = AndroidRenderer.running { Calling() }

            try XCTUnwrap(host.views(AndroidButtonView.self).last).click()
            host.settle { host.views(AndroidLabelView.self).first?.text != "-" }

            let said = host.views(AndroidLabelView.self).first?.text ?? ""
            XCTAssertTrue(said.hasPrefix("thrown:") && said.contains("InteropTest.Unregistered"), said)
        }
    }

    /// An event the application raises reaches every listener, carrying the values its contract declares.
    func testAnEventTheApplicationRaisesReachesItsListeners() {
        onMainActor {
            StateUIEvents.raises(InteropTestContract.spoke)
            let host = AndroidRenderer.running { Calling() }

            let heard = StateUIEvents.raise(InteropTestContract.spoke, "hello")
            host.settle { host.views(AndroidLabelView.self).first?.text != "-" }

            XCTAssertEqual(heard, 1)
            XCTAssertEqual(host.views(AndroidLabelView.self).map(\.text), ["heard hello"])
        }
    }
}
