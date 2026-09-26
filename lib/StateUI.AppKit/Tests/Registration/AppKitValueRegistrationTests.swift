// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// The values, realized through the registry: a slider and a stepper made by
/// their registrations, their range and value reaching the native controls, and
/// the number their user moves reported by member - onto the journey the host
/// carries it in, and to the handler that listens for it.
final class AppKitValueRegistrationTests: XCTestCase {
    /// The registry realizes both: the number each carries, the events each
    /// raises, and the tint a slider takes from the tier it wears.
    @MainActor
    func testTheRegistryRealizesTheValues() {
        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(realization.elements.isSuperset(of: ["Slider", "Stepper"]))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Slider", owner: "Slider", member: "value")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Slider", owner: "Slider", member: "valueChanged")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Slider", owner: "Slider", member: "dragStarted")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Slider", owner: "TintElement", member: "tint")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Stepper", owner: "Stepper", member: "step")))
    }

    /// A slider takes the range the tree describes before the value that must
    /// fit inside it, and follows the tree when either changes.
    @MainActor
    func testASliderShowsItsRangeAndItsValue() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var slider = HostPatch(id: .manual("slider"), type: .slider)
        slider.properties[.minimum] = .number(0)
        slider.properties[.maximum] = .number(10)
        slider.properties[.value] = .number(2.5)
        renderer.applyForTesting(tree(slider))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("slider")) as? AppKitSliderView)
        XCTAssertEqual(native.minValue, 0)
        XCTAssertEqual(native.maxValue, 10)
        XCTAssertEqual(native.doubleValue, 2.5, accuracy: 1e-9)

        var moved = HostPatch(id: .manual("slider"), type: .slider)
        moved.properties[.value] = .number(7.5)
        renderer.applyForTesting(changedTree(moved))

        XCTAssertEqual(native.doubleValue, 7.5, accuracy: 1e-9)
    }

    /// A slider the tree describes no value for keeps the value it has: the
    /// registration writes the number only where the tree changed it, so a
    /// hand on the thumb is never argued with.
    @MainActor
    func testASliderWhoseValueTheTreeLeavesAloneKeepsIts() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var slider = HostPatch(id: .manual("slider"), type: .slider)
        slider.properties[.minimum] = .number(0)
        slider.properties[.maximum] = .number(1)
        slider.properties[.value] = .number(0.25)
        renderer.applyForTesting(tree(slider))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("slider")) as? AppKitSliderView)
        native.doubleValue = 0.8

        var elsewhere = HostPatch(id: .manual("slider"), type: .slider)
        elsewhere.properties[.isEnabled] = .bool(true)
        renderer.applyForTesting(changedTree(elsewhere))

        XCTAssertEqual(native.doubleValue, 0.8, accuracy: 1e-9)
    }

    /// What the user moves reaches both halves at once: the journey the host
    /// carries the number in takes it where the hand left it, and the handler
    /// listening for the change hears it.
    @MainActor
    func testAUsersMoveTakesTheJourneyAndIsHeard() throws {
        let volume = State(wrappedValue: 0.25)
        let heard = Received<Double>()
        let renderer = AppKitRenderer.running {
            VStack {
                Slider(volume.projectedValue)
                    .onValueChanged { heard.values.append($0) }
            }
        }
        defer { renderer.closeForTesting() }

        let native = try XCTUnwrap(renderer.nativeViews(AppKitSliderView.self).first)
        native.doubleValue = 0.625
        native.valueChanged(native)

        XCTAssertEqual(volume.wrappedValue, 0.625, accuracy: 1e-9, "the journey took the user's position")
        XCTAssertEqual(heard.values, [0.625], "and the handler heard the change once")
    }

    /// A stepper takes its range and its step, and what its user steps to is
    /// reported the same way.
    @MainActor
    func testAStepperShowsItsRangeAndReportsWhatTheUserSteps() throws {
        let servings = State(wrappedValue: 2.0)
        let heard = Received<Double>()
        let renderer = AppKitRenderer.running {
            VStack {
                Stepper(servings.projectedValue)
                    .minimum(0)
                    .maximum(8)
                    .step(2)
                    .onValueChanged { heard.values.append($0) }
            }
        }
        defer { renderer.closeForTesting() }

        let native = try XCTUnwrap(renderer.nativeViews(AppKitStepperView.self).first)
        XCTAssertEqual(native.minValue, 0)
        XCTAssertEqual(native.maxValue, 8)
        XCTAssertEqual(native.increment, 2)

        native.stepForTesting(to: 4)

        XCTAssertEqual(servings.wrappedValue, 4, accuracy: 1e-9)
        XCTAssertEqual(heard.values, [4])
    }
}
#endif
