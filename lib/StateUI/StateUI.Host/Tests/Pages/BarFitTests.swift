// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// Which of a bar's groups stand on it where the host measures its bar: all around the title centered, then around
/// the title between, one group fewer each time; and what then stands behind More.
@MainActor
final class BarFitTests: XCTestCase {
    /// The standings a bar is tried in, in order, until one fits.
    func testABarIsTriedCenteredThenBetweenWithOneGroupFewerEachTime() {
        var tried: [BarFit.Standing] = []
        let none = BarFit.standing(groups: 3) { tried.append($0); return false }

        XCTAssertEqual(tried, [
            .init(groups: 3, title: .centered), .init(groups: 3, title: .between),
            .init(groups: 2, title: .between), .init(groups: 1, title: .between),
        ])
        XCTAssertEqual(none, .init(groups: 0, title: .between), "nothing fits: every group behind More")
    }

    /// The first standing that fits is the bar's: every group centered where they fit so.
    func testTheFirstStandingThatFitsIsTheBars() {
        XCTAssertEqual(BarFit.standing(groups: 3) { _ in true }, .init(groups: 3, title: .centered))
        XCTAssertEqual(BarFit.standing(groups: 3) { $0.title == .between }, .init(groups: 3, title: .between))
        XCTAssertEqual(BarFit.standing(groups: 3) { $0.groups <= 1 }, .init(groups: 1, title: .between))
        XCTAssertEqual(BarFit.standing(groups: 0) { _ in false }, .init(groups: 0, title: .between))
    }

    /// Behind More stand the items of each group that left the bar, each group apart, then those placed there.
    func testTheGroupsThatLeftStandBehindMoreAheadOfThosePlacedThere() throws {
        let runtime = HostRuntime.still()
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged(["a", "b", "c", "d"].map { HostPatch(id: .manual($0), type: .toolbarButton) })
        runtime.tree.apply(stack, complete: true)
        let items = try XCTUnwrap(runtime.tree.root).children
        let said = { (entries: [MenuEntry]) in entries.map { $0.kind == .separator ? "-" : $0.element.map { "\($0.id)" } ?? "?" } }

        XCTAssertEqual(
            said(BarFit.behind(left: [[items[0], items[1]], [items[2]]], placed: [items[3]])),
            ["manual(\"a\")", "manual(\"b\")", "-", "manual(\"c\")", "-", "manual(\"d\")"])
        XCTAssertEqual(said(BarFit.behind(left: [], placed: [items[3]])), ["manual(\"d\")"], "none left: as placed")
        XCTAssertEqual(said(BarFit.behind(left: [[items[0]]], placed: [])), ["manual(\"a\")"], "none placed")
    }
}
