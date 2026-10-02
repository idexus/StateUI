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

    var content: some View {
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

/// The control the application makes for a lamp: an Android view that knows nothing of StateUI - here a text view,
/// where an application makes one of its own Java classes.
@MainActor
private final class LampControl: AndroidControl {
    let view = Java.new(JavaAPI.textView, JavaAPI.newTextView, .object(StateUIAndroid.context))

    /// Whether it is lit, as the tree last said; how many times the act flashed it, and a user pulled it.
    var lit = false
    var flashes = 0
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
    fileprivate func flash() async throws {
        try await call(LampContract.flash)
    }
}

/// A lamp, lit, that says when it is pulled or flashed.
private struct Pulling: ContentView {
    @State private var said = "-"
    @Aim(Lamp.self) private var lamp

    var content: some View {
        VStack {
            Lamp().lit(true).onPulled { pulls in said = "pulled \(pulls)" }.aim(lamp)
            Button("Flash").onClicked {
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

/// What an application registers with this host: its own controls, the acts it performs and the events it raises.
final class AndroidInteropTests: XCTestCase {
    static var allTests: [(String, (AndroidInteropTests) -> () throws -> Void)] {
        [
            ("testAnActTheApplicationRegisteredIsPerformedAndAnswers", testAnActTheApplicationRegisteredIsPerformedAndAnswers),
            ("testAnActNobodyRegisteredIsRefusedByName", testAnActNobodyRegisteredIsRefusedByName),
            ("testAnEventTheApplicationRaisesReachesItsListeners", testAnEventTheApplicationRaisesReachesItsListeners),
            ("testTheApplicationsOwnElementIsMadeAndTakesItsProperty", testTheApplicationsOwnElementIsMadeAndTakesItsProperty),
            ("testAnEventTheApplicationsControlRaisesReachesItsHandler", testAnEventTheApplicationsControlRaisesReachesItsHandler),
            ("testAnAimedActIsHandedTheApplicationsOwnControl", testAnAimedActIsHandedTheApplicationsOwnControl),
        ]
    }

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

    /// The application's own element is made by its registration, stands in the tree as its element, takes the
    /// property its contract declares, and is placed as the host's own views are.
    func testTheApplicationsOwnElementIsMadeAndTakesItsProperty() throws {
        try onMainActor {
            Self.registerLamp()
            let host = AndroidRenderer.running { Pulling() }
            let lamp = try XCTUnwrap(host.views(AndroidHostedView<LampControl>.self).first)
            host.layOut()

            XCTAssertTrue(lamp.control.lit, "the registration put the described value on the control")
            XCTAssertTrue(lamp.object === lamp.control.view, "the view shows the control's own view")
            XCTAssertGreaterThan(lamp.placedFrame.width, 0, "placed in its layout")
        }
    }

    /// An event the application's own control raises reaches the handler the tree put on it.
    func testAnEventTheApplicationsControlRaisesReachesItsHandler() throws {
        try onMainActor {
            Self.registerLamp()
            let host = AndroidRenderer.running { Pulling() }
            let lamp = try XCTUnwrap(host.views(AndroidHostedView<LampControl>.self).first)

            lamp.control.pull()
            host.settle { host.views(AndroidLabelView.self).last?.text != "-" }

            XCTAssertEqual(host.views(AndroidLabelView.self).last?.text, "pulled 1")
        }
    }

    /// An act AIMED at the application's own element is handed that element's control.
    func testAnAimedActIsHandedTheApplicationsOwnControl() throws {
        try onMainActor {
            Self.registerLamp()
            let host = AndroidRenderer.running { Pulling() }
            let lamp = try XCTUnwrap(host.views(AndroidHostedView<LampControl>.self).first)

            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            host.settle { host.views(AndroidLabelView.self).last?.text != "-" }

            XCTAssertEqual(host.views(AndroidLabelView.self).last?.text, "flashed")
            XCTAssertEqual(lamp.control.flashes, 1, "the performer was handed the aimed control itself")
        }
    }

    /// An act the application registered is performed and answers the values its contract declares.
    func testAnActTheApplicationRegisteredIsPerformedAndAnswers() throws {
        try onMainActor {
            defer { AndroidInterop.acts.forget(InteropTestContract.doubled.token) }
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
