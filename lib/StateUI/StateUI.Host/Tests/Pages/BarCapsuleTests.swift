// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Which of a bar's buttons stand on a capsule, and where on it.
@MainActor
final class BarCapsuleTests: XCTestCase {
    /// Every button of a group its author declared stands on one capsule - its first at the start, its last at the
    /// end, any between in the middle, one alone on the whole of it.
    func testADeclaredGroupStandsOnOneCapsule() {
        XCTAssertEqual(BarCapsule.places(count: 2, standsAlone: false), [.start, .end])
        XCTAssertEqual(BarCapsule.places(count: 3, standsAlone: false), [.start, .middle, .end])
        XCTAssertEqual(BarCapsule.places(count: 1, standsAlone: false), [.whole])
    }

    /// A lone item's own group stands bare.
    func testALoneItemStandsBare() {
        XCTAssertEqual(BarCapsule.places(count: 1, standsAlone: true), [.none])
    }

    /// A page's toolbar: the group it declares, of one, stands on a capsule; the item standing alone beside it,
    /// in the group StateUI stands it in, stands bare.
    func testTheGroupsOfAPagesToolbarAreToldApart() throws {
        stateUIUseApp(ToolbarApplication())
        let runtime = HostRuntime.still()
        runtime.connectWindow()
        runtime.pump.turn()
        let page = try XCTUnwrap(runtime.tree.root?.first(type: .page))
        let groups = page.chromeActions.end

        XCTAssertEqual(groups.map(BarCapsule.places(of:)), [[.whole], [.none]])
    }
}

private struct ToolbarApplication: Application {
    var body: some Scene {
        WindowGroup {
            Text("Notes").title("Notes").toolbar {
                ToolbarGroup { ToolbarButton("Save") }
                ToolbarButton("Sort")
            }
        }
    }
}
