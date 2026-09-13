// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// The typed host boundary carries every part of the sparse patch that Wire
/// carries. A native host may ignore a capability it has not implemented yet,
/// but the boundary must not make that capability impossible to add.
final class HostRenderTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    func testAHostPatchCarriesTheWholeSparseChangeWithoutWire() throws {
        var child = HostPatch(id: .auto(8), type: .label)
        child.fresh = true
        child.properties[.text] = .string("Ready")

        var patch = HostPatch(id: .manual("save"), type: .button)
        patch.replace = true
        patch.fresh = true
        patch.properties[.text] = .string("Save")
        patch.clearedProperties = [.margin]
        patch.motion = HostLayoutMotion(
            motion: .spring(response: 240, damping: 0.8),
            lanes: [.x, .height])
        patch.transitions[.opacity] = HostTransition(motion: .eased(120, .linear))
        patch.driven = .replace([
            .opacity: HostStateBinding(state: 17, mode: .inOut, kind: .property),
        ])
        patch.events = .replace([.clicked: 23])
        patch.shape = 42
        patch.recycles = true
        patch.children = .arranged([child])

        XCTAssertEqual(patch.id, .manual("save"))
        XCTAssertEqual(patch.type, .button)
        XCTAssertTrue(patch.replace)
        XCTAssertEqual(patch.properties[.text], .string("Save"))
        XCTAssertEqual(patch.clearedProperties, [.margin])
        XCTAssertEqual(patch.motion?.motion.law, .spring)
        XCTAssertEqual(patch.motion?.motion.millis, 240)
        XCTAssertEqual(patch.motion?.motion.factor, 0.8)
        XCTAssertEqual(patch.motion?.lanes, [.x, .height])
        XCTAssertEqual(patch.transitions[.opacity]?.motion.millis, 120)

        guard case .replace(let driven)? = patch.driven else {
            return XCTFail("expected a complete driven-state replacement")
        }
        XCTAssertEqual(driven[.opacity]?.state, 17)
        XCTAssertEqual(driven[.opacity]?.mode, .inOut)
        XCTAssertEqual(driven[.opacity]?.kind, .property)

        guard case .replace(let events)? = patch.events else {
            return XCTFail("expected a complete event replacement")
        }
        XCTAssertEqual(events[.clicked], 23)
        XCTAssertEqual(patch.shape, 42)
        XCTAssertEqual(patch.recycles, true)

        guard case .arranged(let children) = patch.children else {
            return XCTFail("expected a complete child arrangement")
        }
        let carriedChild = try XCTUnwrap(children.first)
        XCTAssertEqual(carriedChild.id, .auto(8))
        XCTAssertEqual(carriedChild.type, .label)
        XCTAssertEqual(carriedChild.properties[.text], .string("Ready"))
    }

    func testAHostPatchDistinguishesUnchangedFromEmptyReplacements() {
        let unchanged = HostPatch(id: .auto(1), type: .button)

        XCTAssertNil(unchanged.driven)
        XCTAssertNil(unchanged.events)
        guard case .unchanged = unchanged.children else {
            return XCTFail("an absent child field must mean unchanged")
        }

        var cleared = HostPatch(id: .auto(1), type: .button)
        cleared.driven = .replace([:])
        cleared.events = .replace([:])
        cleared.children = .arranged([])

        guard case .replace(let driven)? = cleared.driven else {
            return XCTFail("expected an empty driven-state replacement")
        }
        XCTAssertTrue(driven.isEmpty)

        guard case .replace(let events)? = cleared.events else {
            return XCTFail("expected an empty event replacement")
        }
        XCTAssertTrue(events.isEmpty)

        guard case .arranged(let children) = cleared.children else {
            return XCTFail("expected an empty child arrangement")
        }
        XCTAssertTrue(children.isEmpty)

        var sparse = HostPatch(id: .auto(1), type: .button)
        sparse.children = .changed([HostPatch(id: .auto(2), type: .label)])

        guard case .changed(let changed) = sparse.children else {
            return XCTFail("expected only the changed descendant")
        }
        XCTAssertEqual(changed.map(\.id), [.auto(2)])
    }

    func testANativeHostReadsAndReportsTwoWayTextWithoutWire() throws {
        let name = State("Ada")
        let renders = Renders()
        let patch = renders.render(Entry(name.projectedValue).body)

        guard case .replace(let driven)? = patch.driven else {
            return XCTFail("expected the Entry's state attachment")
        }

        let binding = try XCTUnwrap(driven[.text])

        XCTAssertEqual(StateUIHost.value(for: binding), .text("Ada"))
        XCTAssertTrue(StateUIHost.report(.text("Grace"), through: binding))
        XCTAssertEqual(name.get(), "Grace")
    }

    func testANativeHostRefusesAReportThroughAnOutOnlyAttachment() throws {
        let caption = State("Waiting")
        let renders = Renders()
        let patch = renders.render(Label().text(caption.projectedValue).body)

        guard case .replace(let driven)? = patch.driven else {
            return XCTFail("expected the Label's state attachment")
        }

        let binding = try XCTUnwrap(driven[.text])

        XCTAssertEqual(binding.mode, .out)
        XCTAssertFalse(StateUIHost.report(.text("Changed"), through: binding))
        XCTAssertEqual(caption.get(), "Waiting")
    }

    func testANativeHostCyclePublishesAnApplicationStateWrite() throws {
        let caption = State("Waiting")
        let renders = Renders()
        let patch = renders.render(Label().text(caption.projectedValue).body)

        guard case .replace(let driven)? = patch.driven else {
            return XCTFail("expected the Label's state attachment")
        }

        let binding = try XCTUnwrap(driven[.text])
        caption.projectedValue.wrappedValue = "Ready"

        XCTAssertTrue(StateUIHost.cyclesPending)

        let cycle = StateUIHost.cycle(.display, now: 100, reducesMotion: false)

        XCTAssertEqual(
            cycle.changes,
            [HostStateChange(state: binding.state, changed: ~0, value: .text("Ready"))])
        XCTAssertFalse(cycle.continues)
        XCTAssertFalse(StateUIHost.cyclesPending)
    }
}
