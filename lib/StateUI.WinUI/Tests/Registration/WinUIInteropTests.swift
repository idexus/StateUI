// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIWinUI
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

    /// Declared by no test, so a handler listening for it hears nothing.
    static let unheard = ElementEvent<Self, String>("InteropTest.Unheard")

    static let members: [any ContractMember] = [doubled, unregistered, spoke, unheard]
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

/// An element the APPLICATION declares, realized by a control the application wrote.
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

/// The control the application makes for a lamp - a WinUI element that knows nothing of StateUI, here one the host's
/// relay makes, where an application's own relay makes its own.
@MainActor
final class LampControl: WinUIControl {
    let element: OpaquePointer = stateui_winui_text_make()!

    isolated deinit {
        stateui_winui_release(element)
    }

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

/// What an APPLICATION registers with this host: its own controls, the acts it performs and the events it raises.
final class WinUIInteropTests: XCTestCase {
    /// Registers the lamp: a registry keeps what it is told, so registering it again only replaces the same entry.
    @MainActor
    private static func registerLamp() {
        StateUIControls.add(LampContract.self, create: { reports -> LampControl in
            let lamp = LampControl()
            lamp.onPulled = { pulls in reports.raise(LampContract.pulled, pulls) }
            return lamp
        }) { lamp in
            lamp.property(LampContract.lit) { control, lit in control.lit = lit ?? false }
            lamp.raises(LampContract.pulled)
        }
        StateUIActs.add(LampContract.flash, on: LampControl.self) { lamp in lamp.flashes += 1 }
    }

    /// An act the application registered is performed and answers the values its contract declares.
    func testAnActTheApplicationRegisteredIsPerformedAndAnswers() throws {
        try onUIThread {
            WinUIInterop.acts.forget()
            defer { WinUIInterop.acts.forget() }
            StateUIActs.add(InteropTestContract.doubled) { number in number * 2 }
            let host = WinUIRenderer.running { Calling() }

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { host.said != "-" }

            XCTAssertEqual(host.said, "42", "the performer answered, typed both ways")
        }
    }

    /// A performer may await before it answers, and the call is answered once it returns.
    func testAPerformerThatAwaitsAnswersOnceItReturns() throws {
        try onUIThread {
            WinUIInterop.acts.forget()
            defer { WinUIInterop.acts.forget() }
            StateUIActs.add(InteropTestContract.doubled) { number in
                try await Task.sleep(nanoseconds: 20_000_000)
                return number * 2
            }
            let host = WinUIRenderer.running { Calling() }

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { host.said != "-" }

            XCTAssertEqual(host.said, "42")
        }
    }

    /// An act nothing registered is refused by name, so a caller waiting on it throws.
    func testAnActNobodyRegisteredIsRefusedByName() throws {
        try onUIThread {
            WinUIInterop.acts.forget()
            let host = WinUIRenderer.running { Calling() }

            try XCTUnwrap(host.views(WinUIButtonView.self).last).invoke()
            host.settle { host.said != "-" }

            XCTAssertTrue(host.said.hasPrefix("thrown:"), host.said)
            XCTAssertTrue(host.said.contains("InteropTest.Unregistered"), host.said)
        }
    }

    /// An event the host raises reaches every subscription to it, carrying the values the contract declares.
    func testAnEventTheHostRaisesReachesItsSubscriptions() {
        onUIThread {
            let host = WinUIRenderer.running { Calling() }
            XCTAssertEqual(host.said, "-")

            let heard = StateUIEvents.raise(InteropTestContract.spoke, "hello")
            host.settle { host.said != "-" }

            XCTAssertEqual(heard, 1, "the page subscribed while it is in the tree")
            XCTAssertEqual(host.said, "heard hello")
        }
    }

    /// The application's own element is made by its registration, stands in the tree as its element and takes the
    /// property its contract declares.
    func testTheApplicationsOwnElementIsMadeAndTakesItsProperty() throws {
        try onUIThread {
            Self.registerLamp()
            let host = WinUIRenderer.running { Pulling() }
            let lamp = try XCTUnwrap(host.views(WinUIHostedView<LampControl>.self).first)

            XCTAssertTrue(lamp.control.lit, "the registration put the described value on the control")
            XCTAssertTrue(lamp.handle == lamp.control.element, "the view shows the control's own element")
            host.layOut()
            XCTAssertGreaterThan(lamp.laidOutFrame.width, 0, "placed in its layout")
        }
    }

    /// An event the application's own control raises reaches the handler the tree put on it.
    func testAnEventTheApplicationsControlRaisesReachesItsHandler() throws {
        try onUIThread {
            Self.registerLamp()
            let host = WinUIRenderer.running { Pulling() }
            let lamp = try XCTUnwrap(host.views(WinUIHostedView<LampControl>.self).first)

            lamp.control.pull()
            host.settle { host.said != "-" }

            XCTAssertEqual(host.said, "pulled 1")
        }
    }

    /// An act AIMED at the application's own element is handed that element's control.
    func testAnAimedActIsHandedTheApplicationsOwnControl() throws {
        try onUIThread {
            Self.registerLamp()
            let host = WinUIRenderer.running { Pulling() }
            let lamp = try XCTUnwrap(host.views(WinUIHostedView<LampControl>.self).first)
            XCTAssertEqual(lamp.control.flashes, 0)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { host.said != "-" }

            XCTAssertEqual(host.said, "flashed")
            XCTAssertEqual(lamp.control.flashes, 1, "the performer was handed the aimed control itself")
        }
    }
}

private extension WinUIRenderer {
    /// The last thing the page said.
    var said: String {
        views(WinUILabelView.self).last?.text ?? ""
    }
}
