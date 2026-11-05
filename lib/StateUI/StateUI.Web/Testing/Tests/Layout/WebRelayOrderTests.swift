// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

@MainActor
final class WebRelayOrderTests: XCTestCase {
    func testMovedViewsWriteOnceInCreationOrderWithoutReadingLayout() {
        let placements = WebPlacements()
        let retired = WebDOMView(tag: "div")
        let first = WebDOMView(tag: "div")
        retired.release()
        let views = [first] + (0..<11).map { _ in WebDOMView(tag: "div") }
        defer { for view in views { view.release() } }
        for (index, view) in views.enumerated() {
            view.slot = Rect(x: 0, y: 0, width: 100, height: 20)
            view.traveling = Rect(x: Double(index + 1), y: 0, width: 100, height: 20)
        }
        for view in views.reversed() { placements.moved(view) }
        for view in views.prefix(4) { placements.moved(view) }
        views.last?.release()

        let trace = WebPage.traceStyles { placements.settle() }
        let expected = views.dropLast().enumerated().map { index, view in
            "\(view.node)\ttransform\ttranslate(\(index + 1)px, 0px)"
        }

        XCTAssertEqual(trace.writes, expected)
        XCTAssertEqual(trace.layoutReads, 0)
        for (index, view) in views.dropLast().enumerated() {
            XCTAssertEqual(WebPage.style(of: view.node, "transform"), "translate(\(index + 1)px, 0px)")
        }
        XCTAssertEqual(WebPage.traceStyles { placements.settle() }.writes, [], "the queue was drained")
    }

    func testOverriddenPropertiesRestoreInNameOrderWithoutChangingTheirValues() {
        let view = WebDOMView(tag: "div")
        defer { view.release() }
        view.style("width", "90px")
        view.style("min-width", "10px")
        view.slot = Rect(x: 0, y: 0, width: 100, height: 100)
        let names = ["width", "height", "min-width", "min-height", "max-width", "max-height",
                     "margin-inline-end", "margin-block-end"].sorted()
        let expected = names.map { "\(view.node)\t\($0)\t\(view.styled($0) ?? "")" }
        var traces: Set<[String]> = []
        var reads: Int32 = 0

        for _ in 0..<12 {
            view.traveling = Rect(x: 0, y: 0, width: 50, height: 80)
            view.writePlace()
            let trace = WebPage.traceStyles { view.clearSizeOverride() }
            traces.insert(trace.writes)
            reads += trace.layoutReads
        }

        XCTAssertEqual(traces, [expected])
        XCTAssertEqual(reads, 0)
        XCTAssertTrue(view.overridden.isEmpty)
        for name in names { XCTAssertEqual(WebPage.style(of: view.node, name), view.styled(name) ?? "") }
    }
}
