// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

@MainActor
final class GeometryBoundsTests: XCTestCase {
    func testNonfiniteInsetsContributeNoDistanceToEveryHost() throws {
        let runtime = HostRuntime.still()
        var patch = HostPatch(id: .manual("item"), type: .button)
        patch.properties = [
            .padding: .numbers([.nan, 8, .infinity, -4]),
            .margin: .numbers([-12, -.infinity, .nan, 6]),
        ]
        runtime.tree.apply(patch, complete: true)
        let element = try XCTUnwrap(runtime.tree.root)
        XCTAssertEqual(element.value(.padding)?.numbers, [0, 8, 0, -4])
        XCTAssertEqual(element.insets(.padding), Insets(start: 0, top: 8, end: 0, bottom: -4))
        XCTAssertEqual(element.layoutValues.margin, Insets(start: -12, top: 0, end: 0, bottom: 6))
        let values = ElementValues<ButtonContract>(changed: [.padding], reading: { element.presented($0) })
        XCTAssertEqual(values[PaddingElementContract.padding], Insets(start: 0, top: 8, end: 0, bottom: -4))
        withExtendedLifetime(runtime) {}
    }

    func testFiniteSignedInsetsKeepTheirValuesWithoutAToolkitLimit() throws {
        let runtime = HostRuntime.still()
        var patch = HostPatch(id: .manual("item"), type: .button)
        let insets = Insets(start: -16, top: 0.25, end: 1e100, bottom: -1e100)
        patch.properties = [.padding: insets.propValue, .margin: insets.propValue]
        runtime.tree.apply(patch, complete: true)
        let element = try XCTUnwrap(runtime.tree.root)
        XCTAssertEqual(element.insets(.padding), insets)
        XCTAssertEqual(element.layoutValues.margin, insets)
        withExtendedLifetime(runtime) {}
    }

    func testPlainCarriedInsetsUseTheSameDistanceRule() throws {
        let runtime = HostRuntime.still()
        var patch = HostPatch(id: .manual("item"), type: .button)
        patch.driven = .replace([
            .padding: HostStateBinding(state: 900, mode: .inOut, kind: .plain, laneKind: .number),
        ])
        runtime.tree.apply(patch, complete: true)
        _ = runtime.tree.present(states: [900: .lanes([.nan, 8, .infinity, -4])], properties: [:])
        let element = try XCTUnwrap(runtime.tree.root)
        XCTAssertEqual(element.value(.padding)?.numbers, [0, 8, 0, -4])
        XCTAssertNil(element.destination(.padding), "a plain channel has no journey")
        withExtendedLifetime(runtime) {}
    }

    func testAMalformedJourneyKeepsTheDescribedFallback() throws {
        let runtime = HostRuntime.still()
        var patch = HostPatch(id: .manual("item"), type: .button)
        patch.properties = [.padding: .numbers([2, 4, 6, 8])]
        patch.driven = .replace([
            .padding: HostStateBinding(state: 900, mode: .inOut, kind: .property, laneKind: .number),
        ])
        runtime.tree.apply(patch, complete: true)
        let journey = HostJourney(
            value: [.nan, 8, .infinity, -4], destination: [-12, -.infinity, .nan, 6], velocity: [0, 0, 0, 0],
            motion: .none, completion: nil, stopped: 0)
        let malformed = HostBoundary.value(of: journey)
        XCTAssertNil(HostBoundary.journey(from: malformed), "the core refuses nonfinite journey images")
        _ = runtime.tree.present(states: [900: malformed], properties: [:])
        let element = try XCTUnwrap(runtime.tree.root)
        XCTAssertEqual(element.value(.padding)?.numbers, [2, 4, 6, 8])
        XCTAssertNil(element.destination(.padding))
        withExtendedLifetime(runtime) {}
    }

    func testAValidJourneyKeepsItsSignedDistancesAndDestination() throws {
        let runtime = HostRuntime.still()
        var patch = HostPatch(id: .manual("item"), type: .button)
        patch.driven = .replace([
            .padding: HostStateBinding(state: 900, mode: .inOut, kind: .property, laneKind: .number),
        ])
        runtime.tree.apply(patch, complete: true)
        let journey = HostJourney(
            value: [-1, 2, 3, -4], destination: [7, -8, 9, 10], velocity: [0, 0, 0, 0],
            motion: .spring(), completion: nil, stopped: 0)
        _ = runtime.tree.present(states: [900: HostBoundary.value(of: journey)], properties: [:])
        let element = try XCTUnwrap(runtime.tree.root)
        XCTAssertEqual(element.value(.padding)?.numbers, [-1, 2, 3, -4])
        XCTAssertEqual(element.destination(.padding)?.numbers, [7, -8, 9, 10])
        withExtendedLifetime(runtime) {}
    }

    func testPixelsAreWholeNumbersInt32HoldsOrNothing() {
        XCTAssertEqual(GeometryArithmetic.pixels(-3.5, density: 2), -7)
        XCTAssertEqual(GeometryArithmetic.pixels(2.2, rounding: .up), 3)
        XCTAssertEqual(GeometryArithmetic.pixels(-2.2, rounding: .down), -3)
        XCTAssertEqual(GeometryArithmetic.pixels(Double(Int32.max)), Int32.max)
        XCTAssertEqual(GeometryArithmetic.pixels(Double(Int32.min)), Int32.min)
        for points in [Double(Int32.max) + 1, Double(Int32.min) - 1, 3e9, 1e100, .infinity, -.infinity, .nan] {
            XCTAssertNil(GeometryArithmetic.pixels(points), "\(points)")
        }
        XCTAssertNil(GeometryArithmetic.pixels(Double(Int32.max), density: 2))
        for density in [0, -1, Double.nan, .infinity] {
            XCTAssertNil(GeometryArithmetic.pixels(1, density: density), "density \(density)")
        }
    }
}
