// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How every host carries what the user changes: the value a state takes, the program's write heard by nobody,
/// and a radio set's other checks taken away.
@MainActor
final class UserChangeTests: XCTestCase {
    /// A reported value becomes the value a state carries: words as text, flags, numbers and choices as lanes.
    func testAReportedValueIsTheValueAStateCarries() {
        XCTAssertEqual(HostStateValue(carrying: .string("Ada")), .text("Ada"))
        XCTAssertEqual(HostStateValue(carrying: .name("size")), .text("size"))
        XCTAssertEqual(HostStateValue(carrying: .bool(true)), .lanes([1]))
        XCTAssertEqual(HostStateValue(carrying: .number(0.5)), .lanes([0.5]))
        XCTAssertEqual(HostStateValue(carrying: .numbers([1, 2])), .lanes([1, 2]))
        XCTAssertEqual(HostStateValue(carrying: .enumeration(3)), .lanes([3]))
        XCTAssertNil(HostStateValue(carrying: .nothing))
    }

    /// A radio button the user checks turns off the checked peers of its set, and only those; what the program
    /// writes turns nothing off.
    func testARadioCheckedTakesItsSetsOtherChecksAway() throws {
        let runtime = HostRuntime.still()
        func radio(_ id: String, on: Bool) -> HostPatch {
            var radio = HostPatch(id: .manual(id), type: .radioButton)
            radio.properties = [.isOn: .bool(on)]
            return radio
        }
        var root = HostPatch(id: .manual("root"), type: .vStack)
        root.children = .arranged([radio("a", on: true), radio("b", on: false), radio("c", on: false)])
        runtime.tree.apply(root, complete: true)
        let b = try XCTUnwrap(runtime.tree.root?.first(id: .manual("b")))
        var turnedOff: [String] = []

        ProgramWrite.perform {
            b.reportUserChange(.isOn, .toggled, .bool(true), in: runtime) { turnedOff.append("\($0.id)") }
        }
        XCTAssertEqual(turnedOff, [], "the program's write reports nothing")

        b.reportUserChange(.isOn, .toggled, .bool(true), in: runtime) { turnedOff.append("\($0.id)") }
        XCTAssertEqual(turnedOff, ["\(ElementId.manual("a"))"], "the checked peer, and only it")
    }
}
