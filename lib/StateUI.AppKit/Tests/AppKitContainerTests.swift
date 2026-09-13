// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitContainerTests: XCTestCase {
    func testGridLengthsDecodeStateUISemantics() throws {
        let absolute = try XCTUnwrap(AppKitGridLength(.values([.enumeration(0), .number(48)])))
        let star = try XCTUnwrap(AppKitGridLength(.values([.enumeration(1), .number(2)])))
        let auto = try XCTUnwrap(AppKitGridLength(.values([.enumeration(2), .number(1)])))

        guard case .absolute = absolute.kind else { return XCTFail("expected an absolute track") }
        guard case .star = star.kind else { return XCTFail("expected a star track") }
        guard case .auto = auto.kind else { return XCTFail("expected an automatic track") }
        XCTAssertEqual(absolute.value, 48)
        XCTAssertEqual(star.value, 2)
    }

    @MainActor
    func testAStackPlacesChildrenInStableSourceOrder() {
        let first = NSView()
        let second = NSView()
        let stack = AppKitStackView(axis: .vertical)
        stack.frame = NSRect(x: 0, y: 0, width: 100, height: 80)
        stack.spacing = 5
        stack.setItems([
            AppKitLayoutItem(view: first, width: 30, height: 10),
            AppKitLayoutItem(view: second, width: 40, height: 20),
        ])

        stack.layout()

        XCTAssertEqual(stack.subviews.count, 2)
        XCTAssertTrue(stack.subviews[0] === first)
        XCTAssertTrue(stack.subviews[1] === second)
        XCTAssertEqual(first.frame, NSRect(x: 0, y: 0, width: 100, height: 10))
        XCTAssertEqual(second.frame, NSRect(x: 0, y: 15, width: 100, height: 20))
    }

    @MainActor
    func testAStackAppliesAChangedSourceOrderToNativeSubviews() {
        let first = NSView()
        let second = NSView()
        let stack = AppKitStackView(axis: .vertical)

        stack.setItems([
            AppKitLayoutItem(view: first),
            AppKitLayoutItem(view: second),
        ])
        stack.setItems([
            AppKitLayoutItem(view: second),
            AppKitLayoutItem(view: first),
        ])

        XCTAssertTrue(stack.subviews[0] === second)
        XCTAssertTrue(stack.subviews[1] === first)
    }

    @MainActor
    func testHStackGivesAPaddedLabelItsCompleteNativeTextWidth() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string("One"),
            .fontSize: .number(13),
            .padding: .numbers([14, 8, 14, 8]),
        ]
        var stack = HostPatch(id: .manual("stack"), type: .hStack)
        stack.children = .arranged([label])
        renderer.applyForTesting(tree(stack))

        let nativeStack = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        let nativeLabel = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("label")) as? AppKitLabelView)
        nativeStack.frame = NSRect(origin: .zero, size: nativeStack.intrinsicContentSize)
        nativeStack.layoutSubtreeIfNeeded()

        XCTAssertGreaterThanOrEqual(
            nativeLabel.textFrame.width,
            nativeLabel.nativeTextSizeForTesting.width)
    }

    @MainActor
    func testACompleteChildReplacementRemovesTheOldNativeView() {
        let first = NSView()
        let second = NSView()
        let page = AppKitSingleChildView()

        page.setItem(AppKitLayoutItem(view: first))
        page.setItem(AppKitLayoutItem(view: second))

        XCTAssertNil(first.superview)
        XCTAssertTrue(second.superview === page)
        XCTAssertEqual(page.subviews.count, 1)
    }

    @MainActor
    func testANegativeSizeRequestMeansNoExplicitNativeExtent() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string("Measured by AppKit"),
            .widthRequest: .number(-1),
            .heightRequest: .number(-1),
        ]
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([label])
        renderer.applyForTesting(tree(stack))

        let nativeStack = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        let nativeLabel = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        nativeStack.frame = NSRect(x: 0, y: 0, width: 240, height: 80)
        nativeStack.layoutSubtreeIfNeeded()

        XCTAssertEqual(nativeLabel.frame.width, 240)
        XCTAssertGreaterThan(nativeLabel.frame.height, 0)
        XCTAssertFalse(nativeLabel.constraints.contains {
            ($0.firstAttribute == .width || $0.firstAttribute == .height)
                && $0.relation == .equal && $0.constant < 0
        })
    }

    @MainActor
    func testAnExplicitExtentIsClampedToItsAuthoredBounds() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string("Bounded"),
            .widthRequest: .number(200),
            .minimumWidthRequest: .number(100),
            .maximumWidthRequest: .number(120),
        ]
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([label])
        renderer.applyForTesting(tree(stack))

        let nativeStack = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        let nativeLabel = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        nativeStack.frame = NSRect(x: 0, y: 0, width: 300, height: 80)
        nativeStack.layoutSubtreeIfNeeded()

        XCTAssertEqual(nativeLabel.frame.width, 120)
        XCTAssertTrue(nativeLabel.constraints.contains {
            $0.firstAttribute == .width && $0.relation == .equal && $0.constant == 120
        })
    }

    @MainActor
    func testAFillAlignmentStillRespectsAMaximumExtent() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string("Maximum"),
            .maximumWidthRequest: .number(80),
        ]
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([label])
        renderer.applyForTesting(tree(stack))

        let nativeStack = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        let nativeLabel = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        nativeStack.frame = NSRect(x: 0, y: 0, width: 300, height: 80)
        nativeStack.layoutSubtreeIfNeeded()

        XCTAssertEqual(nativeLabel.frame.width, 80)
    }

    @MainActor
    func testAMinimumExtentRaisesTheNativeMeasuredSize() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string("Minimum"),
            .minimumHeightRequest: .number(44),
        ]
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([label])
        renderer.applyForTesting(tree(stack))

        let nativeStack = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        let nativeLabel = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        nativeStack.frame = NSRect(x: 0, y: 0, width: 200, height: 80)
        nativeStack.layoutSubtreeIfNeeded()

        XCTAssertEqual(nativeLabel.frame.height, 44)
        XCTAssertTrue(nativeLabel.constraints.contains {
            $0.firstAttribute == .height && $0.relation == .greaterThanOrEqual
                && $0.constant == 44
        })
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
