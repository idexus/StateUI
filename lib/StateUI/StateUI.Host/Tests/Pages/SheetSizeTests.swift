// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How large a sheet stands on a wide screen, the same on every host: as large as its page asks within the
/// platform's room, the room's standard size for a page that asks none.
@MainActor
final class SheetSizeTests: XCTestCase {
    private let room = SheetRoom(
        least: LayoutSize(width: 320, height: 180),
        standard: LayoutSize(width: 560, height: 480),
        most: LayoutSize(width: 900, height: 700))

    private func node(_ id: String, _ type: NodeType, _ children: [HostPatch] = []) -> HostPatch {
        var patch = HostPatch(id: .manual(id), type: type)
        patch.children = .arranged(children)
        return patch
    }

    /// The page the window's one sheet presents, the sheet holding `presented`.
    private func presented(_ presented: HostPatch) throws -> MountedElement {
        var sheet = node("sheet", .sheet, [presented])
        sheet.properties[.isPresented] = .bool(true)
        let runtime = HostRuntime.still()
        runtime.tree.apply(node("window", .window, [node("beneath", .page, [sheet])]), complete: true)
        let window = try XCTUnwrap(runtime.tree.root)
        return try XCTUnwrap(window.first(id: .manual("sheet"))?.children.first)
    }

    func testAPageStandsAsLargeAsItAsksWithinTheRoom() throws {
        let page = try presented(node("page", .page, [node("words", .text)]))
        var offered: [Double] = []

        let size = SheetSize.size(of: page, in: room) { width in
            offered.append(width)
            return LayoutSize(width: 400, height: 260)
        }

        XCTAssertEqual(size, LayoutSize(width: 400, height: 260))
        XCTAssertEqual(offered, [900], "measured at the most width")
        XCTAssertEqual(SheetSize.size(of: page, in: room) { _ in LayoutSize(width: 80, height: 40) },
                       LayoutSize(width: 320, height: 180), "no smaller than the least")
        XCTAssertEqual(SheetSize.size(of: page, in: room) { _ in LayoutSize(width: 900, height: 2000) },
                       LayoutSize(width: 900, height: 700), "no larger than the most: the page scrolls in it")
    }

    func testAStackTabsAndASplitViewStandAtTheStandardSize() throws {
        for type in [NodeType.navigationStack, .tabView, .splitView] {
            let arrangement = try presented(node("arrangement", type, [node("page", .page)]))
            XCTAssertFalse(SheetSize.asks(arrangement), "\(type)")
            XCTAssertEqual(SheetSize.size(of: arrangement, in: room) { _ in LayoutSize(width: 10, height: 10) },
                           room.standard, "\(type)")
        }
    }

    func testAPageHoldingAViewThatTakesItsRoomStandsAtTheStandardSize() throws {
        for type in NodeType.roomTakingTypes {
            let page = try presented(node("page", .page, [node("column", .vStack, [node("words", .text), node("taker", type)])]))
            XCTAssertFalse(SheetSize.asks(page), "\(type)")
        }
    }

    func testAPageAnAnchorHoldsAsksAsThePage() throws {
        XCTAssertTrue(SheetSize.asks(try presented(node("anchor", .anchor, [node("page", .page, [node("words", .text)])]))))
        XCTAssertFalse(SheetSize.asks(try presented(node("anchor", .anchor, [node("stack", .navigationStack)]))))
    }

    func testAWindowSmallerThanTheLeastHoldsASheetAtTheLeast() throws {
        let page = try presented(node("page", .page, [node("words", .text)]))
        let stack = try presented(node("stack", .navigationStack, [node("page", .page)]))
        let unsized = SheetRoom(least: room.least, standard: room.standard, most: LayoutSize(width: -48, height: -48))

        XCTAssertEqual(SheetSize.size(of: page, in: unsized) { _ in .init(width: 400, height: 300) }, room.least)
        XCTAssertEqual(SheetSize.size(of: stack, in: unsized) { _ in .init(width: 0, height: 0) }, room.least)
    }

    func testTheStandardSizeStaysWithinTheMost() throws {
        let stack = try presented(node("stack", .navigationStack, [node("page", .page)]))
        let small = SheetRoom(least: room.least, standard: room.standard, most: LayoutSize(width: 500, height: 400))

        XCTAssertEqual(SheetSize.size(of: stack, in: small) { _ in .init(width: 0, height: 0) }, small.most)
    }
}
