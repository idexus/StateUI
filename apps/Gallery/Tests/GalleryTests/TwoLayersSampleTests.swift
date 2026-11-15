// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import GalleryUI
import StateUI
import StateUITesting
import XCTest

/// The Two layers sample's cost, read as its user reads it: what a press costs the block that reads the count.
@MainActor
final class TwoLayersSampleTests: XCTestCase {
    /// A press describes the reading block again and times that describe alone: however long the user waited before
    /// pressing, the figure is the describe's, not the wait's.
    func testAPressTimesTheDescribeItCaused() async throws {
        let cost = try XCTUnwrap(TwoLayersSample().examples.last?.view)
        let window = try await TestWindow(motion: .none) { AnyView(cost) }
        let add = try window.element("cost.add")
        let described = try window.element("cost.described")
        func spent() throws -> Double {
            let words = try described.value(TextElementContract.text) ?? ""
            return Double(words.split(separator: " ").dropLast().last ?? "") ?? .infinity
        }

        for _ in 0..<2 {
            try await Task.sleep(for: .milliseconds(300))
            try await add.perform(.activate)
            XCTAssertLessThan(try spent(), 250_000, "the press timed the 300 ms waited before it")
        }
    }
}
