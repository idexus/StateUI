// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitRecyclingTests: XCTestCase {
    @MainActor
    func testARecyclableRowStaysAttachedAndItsWholeSubtreeChangesIdentity() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(rows: [
            row("one", text: "One", shape: 41),
            row("two", text: "Two", shape: 41),
        ]))

        let layout = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("list")) as? AppKitAbsoluteLayoutView)
        let leavingRow = try XCTUnwrap(renderer.viewForTesting(id: .manual("one")))
        let leavingLabel = try XCTUnwrap(renderer.viewForTesting(id: .manual("one-label")))

        renderer.applyForTesting(tree(rows: [
            row("two", text: "Two", shape: 41),
        ]))

        XCTAssertNil(renderer.viewForTesting(id: .manual("one")))
        XCTAssertTrue(leavingRow.superview === layout)
        XCTAssertTrue(leavingRow.isHidden)

        renderer.applyForTesting(tree(rows: [
            row("two", text: "Two", shape: 41),
            row("three", text: "Three", shape: 41),
        ]))

        XCTAssertTrue(renderer.viewForTesting(id: .manual("three")) === leavingRow)
        XCTAssertTrue(renderer.viewForTesting(id: .manual("three-label")) === leavingLabel)
        XCTAssertNil(renderer.viewForTesting(id: .manual("one-label")))
        XCTAssertFalse(leavingRow.isHidden)
        XCTAssertEqual(
            (leavingLabel as? AppKitLabelView)?.stringValue,
            "Three")
    }

    @MainActor
    func testAnAdoptedControlReportsOnlyTheArrivingRowsHandler() throws {
        var reports: [Int32] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { id, _ in reports.append(id) })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(rows: [
            row("one", text: "One", shape: 73, tapped: 100),
        ]))
        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("one-label")))
        let recognizer = try XCTUnwrap(
            native.gestureRecognizers.compactMap { $0 as? AppKitTapRecognizer }.first)

        renderer.applyForTesting(tree(rows: []))
        renderer.applyForTesting(tree(rows: [
            row("two", text: "Two", shape: 73, tapped: 200),
        ]))

        XCTAssertTrue(renderer.viewForTesting(id: .manual("two-label")) === native)
        XCTAssertTrue(
            native.gestureRecognizers.compactMap { $0 as? AppKitTapRecognizer }.first
                === recognizer)
        recognizer.fire()
        XCTAssertEqual(reports, [200])
    }

    @MainActor
    func testZeroOrDifferentShapesNeverAdoptAWaitingRow() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(tree(rows: [row("one", text: "One", shape: 11)]))
        let old = try XCTUnwrap(renderer.viewForTesting(id: .manual("one")))

        renderer.applyForTesting(tree(rows: []))
        renderer.applyForTesting(tree(rows: [row("two", text: "Two", shape: 12)]))
        let different = try XCTUnwrap(renderer.viewForTesting(id: .manual("two")))
        XCTAssertFalse(different === old)

        renderer.applyForTesting(tree(rows: []))
        renderer.applyForTesting(tree(rows: [row("three", text: "Three", shape: 0)]))
        XCTAssertFalse(renderer.viewForTesting(id: .manual("three")) === different)
    }

    @MainActor
    func testThePoolIsBoundedAndAnswersMostRecentlyRetiredFirst() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        let rows = (0..<40).map { row("\($0)", text: "\($0)", shape: 99) }

        renderer.applyForTesting(tree(rows: rows))
        let layout = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("list")) as? AppKitAbsoluteLayoutView)
        let lastKept = try XCTUnwrap(renderer.viewForTesting(id: .manual("31")))

        renderer.applyForTesting(tree(rows: []))

        XCTAssertEqual(layout.subviews.count, 32)
        XCTAssertTrue(layout.subviews.allSatisfy(\.isHidden))

        renderer.applyForTesting(tree(rows: [row("next", text: "Next", shape: 99)]))

        XCTAssertTrue(renderer.viewForTesting(id: .manual("next")) === lastKept)
        XCTAssertEqual(layout.subviews.count, 32)
    }


    private func row(
        _ id: String,
        text: String,
        shape: UInt64,
        tapped: Int32? = nil
    ) -> HostPatch {
        var label = HostPatch(id: .manual("\(id)-label"), type: .label)
        label.properties = [.text: .string(text)]
        if let tapped { label.events = .replace([.tapped: tapped]) }

        var row = HostPatch(id: .manual(id), type: .horizontalStackLayout)
        row.shape = shape
        row.children = .arranged([label])
        return row
    }

    private func tree(rows: [HostPatch]) -> HostPatch {
        var list = HostPatch(id: .manual("list"), type: .absoluteLayout)
        list.recycles = true
        list.children = .arranged(rows)
        return tree(list)
    }

    private func tree(_ content: HostPatch) -> HostPatch {
        var page = HostPatch(id: .manual("page"), type: .contentPage)
        page.children = .arranged([content])
        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([page])
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

}

#endif
