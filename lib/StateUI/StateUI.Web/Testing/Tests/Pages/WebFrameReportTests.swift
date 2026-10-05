// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
@testable import StateUIWeb
import XCTest

/// A view says where it stands only where the browser lays it out: on a covered tab it says nothing, so the frame it
/// said last stands - never zeros, which a frame driving a size would turn into a page of no width. A host runs here,
/// so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebFrameReportTests: XCTestCase {
    override func setUp() {
        WebTestLoop.started
    }

    func testAViewOnACoveredTabSaysNoFrame() throws {
        let frames = Received<[Double]>()
        let host = WebRenderer.running {
            TabView([0, 1]) { tab in
                tab == 0 ? Text("Tab 0").onEvent(ViewContract.frameChanged) { frames.values.append($0) } : Text("Tab 1")
            }
        }
        host.settle { Aspects.laidOut(frames) }
        let tabs = try XCTUnwrap(host.views(WebTabView.self).first)

        for place in [1, 0] {
            try WebBrowser.run("e.querySelectorAll(':scope > .stateui-tab-strip > [role=tab]')[\(place)].click()", on: tabs.node)
            for _ in 0..<12 { host.step() }
        }

        XCTAssertTrue(Aspects.laidOut(frames), "laid out at a size again")
        XCTAssertFalse(frames.values.contains { FrameReport.size($0).allSatisfy { $0 == 0 } },
                       "a covered tab's view said it stood at no size: \(frames.values)")
    }
}
