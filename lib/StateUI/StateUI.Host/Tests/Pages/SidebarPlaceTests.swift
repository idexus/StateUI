// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// Where a split view's sidebar stands, said onto the application's state the same on every host.
@MainActor
final class SidebarPlaceTests: XCTestCase {
    /// A SPLIT VIEW SAYS WHERE ITS SIDEBAR STANDS onto the state its place drives, each change once: a host saying
    /// the same place again, as it stands the split again, writes nothing.
    func testASplitViewSaysWhereItsSidebarStands() throws {
        seen = []
        stateUIUseApp(PlaceApplication())
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let split = try XCTUnwrap(runtime.tree.root?.first(type: .splitView))
        XCTAssertEqual(seen, [false])
        XCTAssertTrue(split.readsOwnFrame, "said with its frame, once laid out")

        split.reportSidebarOverlays(true, in: runtime)
        runtime.pump.turn()
        XCTAssertEqual(seen, [false, true], "over the detail")

        split.reportSidebarOverlays(true, in: runtime)
        runtime.pump.turn()
        XCTAssertEqual(seen, [false, true], "the same place, nothing written")

        split.reportSidebarOverlays(false, in: runtime)
        runtime.pump.turn()
        XCTAssertEqual(seen, [false, true, false], "and beside it again")
    }
}

/// Where the page read the sidebar standing, each time its body was built.
@MainActor private var seen: [Bool] = []

private struct PlacePage: View {
    @State private var menu = true
    @State private var over = false

    var body: some View {
        seen.append(over)
        return SplitView {
            Text("Menu")
        } detail: {
            Text(over ? "Over" : "Beside")
        }
        .showsSidebar($menu)
        .sidebarOverlays($over)
    }
}

private struct PlaceApplication: Application {
    var body: some Scene { WindowGroup { PlacePage() } }
}
