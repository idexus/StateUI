// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// The indicators, realized through the registry: a progress bar and an
/// activity indicator made by their registrations, their members reaching the
/// native views, and what the registry says it realizes.
final class AppKitIndicatorRegistrationTests: XCTestCase {
    /// The registry realizes both indicators, each with its own member.
    @MainActor
    func testTheRegistryRealizesTheIndicators() {
        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(realization.elements.isSuperset(of: ["ProgressBar", "ActivityIndicator"]))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "ProgressBar", owner: "ProgressBar", member: "progress")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "ActivityIndicator", owner: "ActivityIndicator", member: "isRunning")))
    }

    /// A progress bar is made by its registration, shows the fraction it is
    /// told, and shows none once the value is no longer described.
    @MainActor
    func testAProgressBarShowsItsProgressAndNoneOnceCleared() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var bar = HostPatch(id: .manual("bar"), type: .progressBar)
        bar.properties[.progress] = .number(0.4)
        renderer.applyForTesting(tree(bar))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("bar")) as? AppKitProgressView)
        XCTAssertEqual(native.doubleValue, 0.4, accuracy: 1e-9)

        var cleared = HostPatch(id: .manual("bar"), type: .progressBar)
        cleared.clearedProperties = [.progress]
        renderer.applyForTesting(changedTree(cleared))

        XCTAssertEqual(native.doubleValue, 0)
    }

    /// An activity indicator is made by its registration and spins exactly
    /// while it is told it runs.
    @MainActor
    func testAnActivityIndicatorSpinsWhileItRuns() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var running = HostPatch(id: .manual("activity"), type: .activityIndicator)
        running.properties[.isRunning] = .bool(true)
        renderer.applyForTesting(tree(running))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("activity")) as? AppKitActivityIndicatorView)
        XCTAssertTrue(native.isSpinning)

        var stopped = HostPatch(id: .manual("activity"), type: .activityIndicator)
        stopped.properties[.isRunning] = .bool(false)
        renderer.applyForTesting(changedTree(stopped))

        XCTAssertFalse(native.isSpinning)
    }

    /// An indicator the tree describes as stopped - or does not describe at
    /// all - starts when the tree says it runs and stops when it says it does
    /// not: the round a poll draws, where the spinner is made still and is
    /// started only for the work.
    @MainActor
    func testAnIndicatorMadeStillStartsWhenTheTreeSaysItRuns() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(HostPatch(id: .manual("activity"), type: .activityIndicator)))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("activity")) as? AppKitActivityIndicatorView)
        XCTAssertFalse(native.isSpinning, "nothing described, nothing spinning")

        var checking = HostPatch(id: .manual("activity"), type: .activityIndicator)
        checking.properties[.isRunning] = .bool(true)
        renderer.applyForTesting(changedTree(checking))

        XCTAssertTrue(native.isSpinning)

        var done = HostPatch(id: .manual("activity"), type: .activityIndicator)
        done.properties[.isRunning] = .bool(false)
        renderer.applyForTesting(changedTree(done))

        XCTAssertFalse(native.isSpinning)
    }
}
#endif
