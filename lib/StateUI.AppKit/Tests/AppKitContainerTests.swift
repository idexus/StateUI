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
        XCTAssertEqual(first.frame, NSRect(x: 35, y: 0, width: 30, height: 10))
        XCTAssertEqual(second.frame, NSRect(x: 30, y: 15, width: 40, height: 20))
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
    func testAWidthConstrainedNestedStackKeepsWrappedTextInsideItsBorder() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string(String(repeating: "A line that must wrap inside its card. ", count: 8)),
            .fontSize: .number(13),
        ]
        var innerStack = HostPatch(id: .manual("inner"), type: .vStack)
        innerStack.properties[.padding] = .numbers([16, 16, 16, 16])
        innerStack.children = .arranged([label])
        var border = HostPatch(id: .manual("border"), type: .border)
        border.children = .arranged([innerStack])
        var outerStack = HostPatch(id: .manual("outer"), type: .vStack)
        outerStack.children = .arranged([border])
        var scroll = HostPatch(id: .manual("scroll"), type: .scrollView)
        scroll.properties[.orientation] = .enumeration(ScrollOrientation.vertical.rawValue)
        scroll.children = .arranged([outerStack])
        renderer.applyForTesting(scroll)

        let nativeScroll = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("scroll")) as? AppKitScrollView)
        let nativeBorder = try XCTUnwrap(renderer.viewForTesting(id: .manual("border")))
        let nativeLabel = try XCTUnwrap(renderer.viewForTesting(id: .manual("label")))
        nativeScroll.frame = NSRect(x: 0, y: 0, width: 300, height: 120)
        nativeScroll.layoutSubtreeIfNeeded()

        let labelFrame = nativeBorder.convert(nativeLabel.bounds, from: nativeLabel)
        XCTAssertLessThanOrEqual(labelFrame.maxY, nativeBorder.bounds.maxY + 0.001)
    }

    @MainActor
    func testAHostDrivenChildHeightRefreshesItsAncestorLayoutItem() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        let binding = HostStateBinding(state: 71, mode: .inOut, kind: .property)

        var border = HostPatch(id: .manual("border"), type: .border)
        border.properties[.heightRequest] = .number(90)
        border.driven = .replace([.heightRequest: binding])
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([border])
        renderer.applyForTesting(stack)

        let nativeStack = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        let nativeBorder = try XCTUnwrap(renderer.viewForTesting(id: .manual("border")))
        nativeStack.frame = NSRect(x: 0, y: 0, width: 300, height: 300)
        nativeStack.layoutSubtreeIfNeeded()
        XCTAssertEqual(nativeBorder.frame.height, 90, accuracy: 0.001)

        let arrived = HostJourney(
            value: [160],
            destination: [160],
            velocity: [0],
            motion: .none,
            completion: nil,
            stopped: 0)
        renderer.applyStateForTesting(71, value: StateUIHost.value(of: arrived))
        nativeStack.layoutSubtreeIfNeeded()

        XCTAssertEqual(nativeBorder.frame.height, 160, accuracy: 0.001)
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

    /// An explicit size wins over a filling alignment in every StateUI
    /// layout: the child keeps its size and stands in the middle of its slot.
    @MainActor
    func testAnExplicitSizeWinsOverFillAndStandsInTheMiddleOfItsSlot() throws {
        let expected: [(NodeType, NSPoint)] = [
            (.vStack, NSPoint(x: 128, y: 0)),
            (.hStack, NSPoint(x: 0, y: 40)),
            (.border, NSPoint(x: 128, y: 40)),
            (.grid, NSPoint(x: 128, y: 40)),
            (.scrollView, NSPoint(x: 128, y: 40)),
        ]

        for (container, origin) in expected {
            let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            var box = HostPatch(id: .manual("box"), type: .boxView)
            box.properties = [.widthRequest: .number(44), .heightRequest: .number(20)]
            var layout = HostPatch(id: .manual("layout"), type: container)
            layout.children = .arranged([box])
            renderer.applyForTesting(tree(layout))

            let nativeLayout = try XCTUnwrap(renderer.viewForTesting(id: .manual("layout")))
            let nativeBox = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
            nativeLayout.frame = NSRect(x: 0, y: 0, width: 300, height: 100)
            nativeLayout.layoutSubtreeIfNeeded()

            XCTAssertEqual(nativeBox.frame.size, NSSize(width: 44, height: 20), container.name)
            XCTAssertEqual(nativeBox.frame.origin, origin, container.name)
        }
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

}

#endif
