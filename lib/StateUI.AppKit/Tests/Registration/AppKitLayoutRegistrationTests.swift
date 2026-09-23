// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

/// The layouts that move: the stacks and the grid, whose room around and
/// between their children comes through the registry. What ARRANGES those
/// children is the host's, and stays there - as does a scroll view, whose view
/// is made with the host's own closures, and an absolute layout, whose
/// placement a binding carries.
final class AppKitLayoutRegistrationTests: XCTestCase {
    /// The registry realizes the stacks and the grid, each with the members it
    /// takes - and claims nothing of the layouts it does not make.
    @MainActor
    func testTheRegistryRealizesTheStacksAndTheGrid() {
        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(realization.elements.isSuperset(of: ["VStack", "HStack", "Grid"]))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "VStack", owner: "StackBase", member: "spacing")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "HStack", owner: "PaddingElement", member: "padding")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "Grid", owner: "Grid", member: "rows")))

        XCTAssertFalse(
            realization.elements.contains("AbsoluteLayout"),
            "an absolute layout's placement is carried by a binding, and is not the registry's yet")
    }

    /// A scroll view's members come through the registry though its VIEW IS
    /// THE HOST'S: the registry realizes the element and makes nothing for it,
    /// so the host's own arm - which binds the reports that go through a
    /// user transaction, and the request for display frames - still stands.
    @MainActor
    func testTheRegistryRealizesAScrollViewWithoutMakingIt() {
        let realization = AppKitRegistrations.registry.realization

        XCTAssertTrue(realization.elements.contains("ScrollView"))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "ScrollView", owner: "ScrollView", member: "orientation")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "ScrollView", owner: "ScrollView", member: "scrollOffset")))
        XCTAssertTrue(realization.members.contains(
            HostRealizedMember(element: "ScrollView", owner: "PaddingElement", member: "padding")))

        XCTAssertNil(
            AppKitRegistrations.registry.makeView(
                for: .scrollView, sending: { _, _ in }, reporting: { _, _, _ in }),
            "the host makes this view, so the registry makes none for it")
    }

    /// A scroll view takes the members its registration names, and rests in
    /// its contract's default state where the tree describes none of them - a
    /// registration applies on CHANGE, so the view is born as the contract
    /// says rather than as AppKit would leave it.
    @MainActor
    func testAScrollViewTakesItsMembersAndRestsAtItsContractsDefault() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        let bare = HostPatch(id: .manual("bare"), type: .scrollView)
        renderer.applyForTesting(tree(bare))

        let resting = try XCTUnwrap(renderer.viewForTesting(id: .manual("bare")) as? AppKitScrollView)
        XCTAssertEqual(resting.orientation, .vertical, "the contract scrolls vertically unless told otherwise")
        XCTAssertTrue(resting.hasVerticalScroller, "which is a vertical scroller, described or not")

        var scroll = HostPatch(id: .manual("scroll"), type: .scrollView)
        scroll.properties[.orientation] = .enumeration(ScrollOrientation.horizontal.rawValue)
        scroll.properties[.padding] = .numbers([4, 8, 12, 16])
        scroll.properties[.verticalScrollBarVisibility] = .enumeration(ScrollBarVisibility.never.rawValue)
        renderer.applyForTesting(tree(scroll))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("scroll")) as? AppKitScrollView)
        XCTAssertEqual(native.orientation, .horizontal)
        XCTAssertEqual(native.padding.left, 4)
        XCTAssertEqual(native.padding.top, 8)
        XCTAssertEqual(native.padding.right, 12)
        XCTAssertEqual(native.padding.bottom, 16)
        XCTAssertFalse(native.hasVerticalScroller, "`.never` takes the bar away")
    }

    /// A stack takes the space between its children and the space inside its
    /// own edge, and follows the tree when either changes.
    @MainActor
    func testAStackTakesItsSpacingAndPadding() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.properties[.spacing] = .number(12)
        stack.properties[.padding] = .numbers([4, 8, 12, 16])
        renderer.applyForTesting(tree(stack))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        XCTAssertEqual(native.spacing, 12)
        XCTAssertEqual(native.padding.left, 4)
        XCTAssertEqual(native.padding.top, 8)
        XCTAssertEqual(native.padding.right, 12)
        XCTAssertEqual(native.padding.bottom, 16)

        var closer = HostPatch(id: .manual("stack"), type: .vStack)
        closer.properties[.spacing] = .number(2)
        renderer.applyForTesting(changedTree(closer))

        XCTAssertEqual(native.spacing, 2)
    }

    /// A grid takes its rows and columns as the kind-and-amount pairs they
    /// travel as, and the spacings between them.
    @MainActor
    func testAGridTakesItsRowsColumnsAndSpacings() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var grid = HostPatch(id: .manual("grid"), type: .grid)
        // An auto length carries a 1 rather than nothing, so every length
        // crosses as the same two parts - a kind and a number (`GridLength`).
        grid.properties[.rows] = .values([
            .values([.enumeration(0), .number(40)]),
            .values([.enumeration(2), .number(1)]),
        ])
        grid.properties[.columns] = .values([
            .values([.enumeration(1), .number(1)]),
        ])
        grid.properties[.rowSpacing] = .number(6)
        grid.properties[.columnSpacing] = .number(9)
        renderer.applyForTesting(tree(grid))

        let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("grid")) as? AppKitGridView)

        XCTAssertEqual(native.rows, [.fixed(40), .auto])
        XCTAssertEqual(native.columns, [.proportional(1)])
        XCTAssertEqual(native.rowSpacing, 6)
        XCTAssertEqual(native.columnSpacing, 9)
    }
}
#endif
