// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// The typed host boundary carries every part of the sparse patch that Wire
/// carries. A native host may ignore a capability it has not implemented yet,
/// but the boundary must not make that capability impossible to add.
final class HostRenderTests: XCTestCase {
    func testAHostPatchCarriesTheWholeSparseChangeWithoutWire() throws {
        var child = Patch(id: .auto(8), type: .label)
        child.fresh = true
        child.props[.text] = .string("Ready")

        var patch = Patch(id: .manual("save"), type: .button)
        patch.replace = true
        patch.fresh = true
        patch.props[.text] = .string("Save")
        patch.cleared = [.margin]
        patch.motion = .spring(response: 240, damping: 0.8)
        patch.lanes = [.x, .height]
        patch.transitions[.opacity] = Transition(motion: .eased(120, .linear))
        patch.driven = [
            .opacity: StateEntry(number: 17, mode: .inOut, kind: .property),
        ]
        patch.events = [.clicked: 23]
        patch.shape = 42
        patch.recycles = true
        patch.arranged = true
        patch.children = [child]

        let host = HostPatch(patch)

        XCTAssertEqual(host.id, .manual("save"))
        XCTAssertEqual(host.type, .button)
        XCTAssertTrue(host.replace)
        XCTAssertEqual(host.properties[.text], .string("Save"))
        XCTAssertEqual(host.clearedProperties, [.margin])
        XCTAssertEqual(host.motion?.motion.law, .spring)
        XCTAssertEqual(host.motion?.motion.millis, 240)
        XCTAssertEqual(host.motion?.motion.factor, 0.8)
        XCTAssertEqual(host.motion?.lanes, [.x, .height])
        XCTAssertEqual(host.transitions[.opacity]?.motion.millis, 120)

        guard case .replace(let driven)? = host.driven else {
            return XCTFail("expected a complete driven-state replacement")
        }
        XCTAssertEqual(driven[.opacity]?.state, 17)
        XCTAssertEqual(driven[.opacity]?.mode, .inOut)
        XCTAssertEqual(driven[.opacity]?.kind, .property)

        guard case .replace(let events)? = host.events else {
            return XCTFail("expected a complete event replacement")
        }
        XCTAssertEqual(events[.clicked], 23)
        XCTAssertEqual(host.shape, 42)
        XCTAssertEqual(host.recycles, true)

        guard case .arranged(let children) = host.children else {
            return XCTFail("expected a complete child arrangement")
        }
        let carriedChild = try XCTUnwrap(children.first)
        XCTAssertEqual(carriedChild.id, .auto(8))
        XCTAssertEqual(carriedChild.type, .label)
        XCTAssertEqual(carriedChild.properties[.text], .string("Ready"))
    }

    func testAHostPatchDistinguishesUnchangedFromEmptyReplacements() {
        let unchanged = HostPatch(Patch(id: .auto(1), type: .button))

        XCTAssertNil(unchanged.driven)
        XCTAssertNil(unchanged.events)
        guard case .unchanged = unchanged.children else {
            return XCTFail("an absent child field must mean unchanged")
        }

        var cleared = Patch(id: .auto(1), type: .button)
        cleared.driven = [:]
        cleared.events = [:]
        cleared.arranged = true

        let host = HostPatch(cleared)

        guard case .replace(let driven)? = host.driven else {
            return XCTFail("expected an empty driven-state replacement")
        }
        XCTAssertTrue(driven.isEmpty)

        guard case .replace(let events)? = host.events else {
            return XCTFail("expected an empty event replacement")
        }
        XCTAssertTrue(events.isEmpty)

        guard case .arranged(let children) = host.children else {
            return XCTFail("expected an empty child arrangement")
        }
        XCTAssertTrue(children.isEmpty)

        var sparse = Patch(id: .auto(1), type: .button)
        sparse.children = [Patch(id: .auto(2), type: .label)]

        guard case .changed(let changed) = HostPatch(sparse).children else {
            return XCTFail("expected only the changed descendant")
        }
        XCTAssertEqual(changed.map(\.id), [.auto(2)])
    }
}
