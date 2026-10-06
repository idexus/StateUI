// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// A state's lanes as the value its property carries: read as the type that carried them.
@MainActor
final class StateLanesTests: XCTestCase {
    /// An application's own element said from a state reaches the host as its member's type - a Boolean as a
    /// Boolean, a choice as its case - which no name the library knows could say.
    func testAnApplicationsOwnValuesFromAStateArriveAsTheirType() throws {
        stateUIUseApp(LampApplication())
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()

        let lamp = try XCTUnwrap(runtime.tree.root?.first(type: LampContract.nodeType))
        XCTAssertEqual(lamp.value(LampContract.isLit.token), .bool(false))
        XCTAssertEqual(lamp.value(LampContract.signal.token), .enumeration(Signal.go.rawValue))
    }

    /// Every member of every library contract whose value lies as lanes arrives from a state as it arrives stated:
    /// the host reads the lanes as their type says and finds the value that type crosses as.
    func testEveryMemberFromAStateArrivesAsItArrivesStated() {
        var met: Set<HostLaneKind> = []

        for contract in LibraryContracts.elements.flatMap({ $0.worn }) {
            for case let member as any PropertyMember in contract.members {
                let declared = (member.valueType as? any OptionalValue.Type)?.wrapped ?? member.valueType
                guard let type = declared as? any (LaneValue & HostRepresentable).Type else { continue }
                if arrivesAsStated(type, "\(contract.name).\(member.name)") { met.insert(type.laneKind) }
            }
        }

        XCTAssertEqual(met, [.number, .boolean, .choice, .color], "the lane kinds the library's members are of")
    }

    /// Whether some value of `type` was read back from its lanes, each as it crosses stated.
    private func arrivesAsStated<Value: LaneValue & HostRepresentable>(_ type: Value.Type, _ member: String) -> Bool {
        var read = false

        for lane in [0, 1, 2, 0.25] {
            guard let value = Value(carried: .lanes(Array(repeating: lane, count: max(Value.lanes, 1)))),
                  case .lanes(let lanes) = value.carried
            else { continue }

            XCTAssertEqual(MountedElement.value(of: lanes, as: Value.laneKind), value.propValue, member)
            read = true
        }

        return read
    }
}

/// An optional value's own type, which a state of it carries.
private protocol OptionalValue {
    static var wrapped: Any.Type { get }
}

extension Optional: OptionalValue {
    static var wrapped: Any.Type { Wrapped.self }
}

private enum Signal: Int32, HostRepresentable, StateChoice {
    case stop, caution, go
}

private enum LampContract: ElementContract {
    static let nodeType: NodeType = "Test.Lamp"
    static let tiers: [any Contract.Type] = [ViewContract.self]

    static let isLit = ElementProperty<Self, Bool>("isLit")
    static let signal = ElementProperty<Self, Signal>("signal")

    static let members: [any ContractMember] = [isLit, signal]
}

private struct Lamp: ElementView {
    var node = Node(contract: LampContract.self)
}

private struct LampPage: View {
    @State private var isLit = false
    @State private var signal = Signal.go

    var body: some View {
        Lamp()
            .setValue(LampContract.isLit, on: $isLit, mode: .out, kind: .plain)
            .setValue(LampContract.signal, on: $signal, mode: .out, kind: .plain)
    }
}

private struct LampApplication: Application {
    var body: some Scene { WindowGroup { LampPage() } }
}
