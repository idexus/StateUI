// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitContainerTests: XCTestCase {
    /// A container handed the arrangement it already has asks nothing. A patch
    /// on its way to a descendant applies every ancestor again, and a split
    /// view that laid out its panes on each one - every scroll report of a
    /// label reading the offset - held every scroll event of the Gallery
    /// ~110 ms.
    @MainActor
    func testAContainerHandedTheArrangementItHasAsksNothing() {
        func item(_ view: NSView) -> AppKitLayoutItem { AppKitLayoutItem(view: view) }
        let room = NSRect(x: 0, y: 0, width: 400, height: 300)
        var containers: [(name: String, view: NSView, arrange: () -> Void)] = []

        let stack = AppKitStackView(axis: .vertical)
        let stacked = NSView()
        containers.append(("stack", stack, { stack.setItems([item(stacked)]) }))

        let grid = AppKitGridView()
        let cell = NSView()
        containers.append(("grid", grid, { grid.setItems([item(cell)]) }))

        let layers = AppKitZStackView()
        let placed = NSView()
        containers.append(("ZStack", layers, { layers.setItems([item(placed)]) }))

        let navigation = AppKitNavigationView()
        let page = NSView()
        containers.append(("navigation", navigation, { navigation.setItems([item(page)]) }))

        let holder = AppKitSingleChildView()
        let held = NSView()
        containers.append(("single child", holder, { holder.setItem(item(held)) }))

        let scroll = AppKitScrollView(frame: room)
        let scrolled = NSView()
        containers.append(("scroller", scroll, { scroll.setItems([item(scrolled)]) }))

        let split = AppKitSplitView(frame: room)
        let sidebar = NSView()
        let detail = NSView()
        containers.append(("split view", split, { split.setItems([item(sidebar), item(detail)]) }))

        let tabs = AppKitTabbedView(frame: room)
        let tab = NSView()
        containers.append(("tabbed view", tabs, {
            _ = tabs.setItems(
                [AppKitTabItem(layout: item(tab), title: "One", image: nil)],
                requestedIndex: 0)
        }))

        for container in containers {
            container.view.frame = room
            container.arrange()
            container.view.layoutSubtreeIfNeeded()
            XCTAssertFalse(container.view.needsLayout, "the \(container.name) starts laid out")

            container.arrange()

            XCTAssertFalse(
                container.view.needsLayout,
                "the \(container.name) asks nothing of an arrangement it has")
        }
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
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
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
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
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
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        let binding = HostStateBinding(state: 71, mode: .inOut, kind: .property)

        var border = HostPatch(id: .manual("border"), type: .border)
        border.properties[.height] = .number(90)
        border.driven = .replace([.height: binding])
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
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string("Measured by AppKit"),
            .width: .number(-1),
            .height: .number(-1),
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
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string("Bounded"),
            .width: .number(200),
            .minimumWidth: .number(100),
            .maximumWidth: .number(120),
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
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string("Maximum"),
            .maximumWidth: .number(80),
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
            let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            var box = HostPatch(id: .manual("box"), type: .colorBox)
            box.properties = [.width: .number(44), .height: .number(20)]
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
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var label = HostPatch(id: .manual("label"), type: .label)
        label.properties = [
            .text: .string("Minimum"),
            .minimumHeight: .number(44),
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

    /// A border paints its own background, a colour and a gradient brush
    /// alike: the colour fills it, and the gradient runs from its first stop
    /// at its start to its last at its end.
    @MainActor
    func testABorderDrawsItsColourAndGradientBackgrounds() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                Border().background(.red)
                Border().background(.linearGradient(
                    [GradientStop(.red, 0), GradientStop(.blue, 1)],
                    startPoint: Point(0, 0),
                    endPoint: Point(1, 0)))
            }
        }
        defer { renderer.closeForTesting() }
        let borders = renderer.nativeViews(AppKitBorderView.self)
        XCTAssertEqual(borders.count, 2)
        guard borders.count == 2 else { return }
        for border in borders { border.frame = NSRect(x: 0, y: 0, width: 40, height: 20) }

        let colour = try bitmap(of: borders[0])
        let gradient = try bitmap(of: borders[1])

        let middle = try XCTUnwrap(colour.colorAt(x: 20, y: 10))
        XCTAssertGreaterThan(middle.redComponent, 0.9)
        XCTAssertLessThan(middle.blueComponent, 0.1)
        let start = try XCTUnwrap(gradient.colorAt(x: 2, y: 10))
        let end = try XCTUnwrap(gradient.colorAt(x: 37, y: 10))
        XCTAssertGreaterThan(start.redComponent, start.blueComponent)
        XCTAssertGreaterThan(end.blueComponent, end.redComponent)
    }

    /// A border cuts what it holds to its shape, on a layer of its own: a
    /// picture in a rounded card has rounded corners, as the card does, and one
    /// in an ellipse is cut by its outline.
    @MainActor
    func testABorderClipsWhatItHoldsToItsShape() throws {
        let renderer = AppKitRenderer.running {
            VStack {
                Border { ColorBox(Color("#FF0000")) }.shape(.roundedRectangle(16)).width(100).height(100)
                Border { ColorBox(Color("#FF0000")) }.shape(.ellipse).width(100).height(60)
                Border { ColorBox(Color("#FF0000")) }.width(100).height(40)
            }
        }
        defer { renderer.closeForTesting() }
        let borders = renderer.nativeViews(AppKitBorderView.self)
        XCTAssertEqual(borders.count, 3)
        borders.first?.window?.contentView?.layoutSubtreeIfNeeded()

        let rounded = try XCTUnwrap(borders[0].layer, "the border clips on a layer of its own")
        XCTAssertTrue(rounded.masksToBounds, "what the border holds is clipped")
        XCTAssertEqual(rounded.cornerRadius, 16)

        let ellipse = try XCTUnwrap(borders[1].layer)
        let outline = try XCTUnwrap(ellipse.mask as? CAShapeLayer, "an ellipse cuts by its outline")
        XCTAssertEqual(outline.path?.boundingBox, CGRect(x: 0, y: 0, width: 100, height: 60))

        let plain = try XCTUnwrap(borders[2].layer)
        XCTAssertTrue(plain.masksToBounds, "a rectangle clips to its bounds")
        XCTAssertEqual(plain.cornerRadius, 0)
    }

    /// A child written invisible is hidden and takes no room: what follows it
    /// in a stack stands where it would have stood.
    @MainActor
    func testAnInvisibleChildIsHiddenAndTakesNoRoom() throws {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([
            box("first", [.height: .number(10)]),
            box("hidden", [.height: .number(10), .isVisible: .bool(false)]),
            box("last", [.height: .number(10), .isVisible: .bool(true)]),
        ])
        let renderer = arranged(stack, in: NSSize(width: 100, height: 100))
        defer { renderer.closeForTesting() }

        let nativeStack = try XCTUnwrap(renderer.viewForTesting(id: .manual("stack")))
        XCTAssertEqual(renderer.viewForTesting(id: .manual("hidden"))?.isHidden, true)
        XCTAssertEqual(renderer.viewForTesting(id: .manual("last"))?.frame.minY, 10)
        XCTAssertEqual(nativeStack.intrinsicContentSize.height, 20)
    }

    /// A stack stands each child inside the stack's padding, by the child's
    /// margin and its alignment across the stack, with the stack's spacing
    /// between the children.
    @MainActor
    func testAStackPlacesChildrenByMarginAlignmentPaddingAndSpacing() throws {
        func sized(_ width: Double, _ properties: [Prop: HostValue]) -> [Prop: HostValue] {
            properties.merging([.width: .number(width), .height: .number(10)]) { $1 }
        }
        var column = HostPatch(id: .manual("column"), type: .vStack)
        column.properties = [.padding: .numbers([10, 8, 12, 6]), .spacing: .number(4)]
        column.children = .arranged([
            box("start", sized(30, [
                .margin: .numbers([5, 2, 0, 3]),
                .horizontalAlignment: .enumeration(Alignment.start.rawValue),
            ])),
            box("end", sized(30, [.horizontalAlignment: .enumeration(Alignment.end.rawValue)])),
            box("center", sized(30, [.horizontalAlignment: .enumeration(Alignment.center.rawValue)])),
        ])
        var row = HostPatch(id: .manual("row"), type: .hStack)
        row.properties[.padding] = .numbers([6, 4, 6, 4])
        row.children = .arranged([
            box("bottom", sized(10, [
                .margin: .numbers([3, 0, 0, 0]),
                .verticalAlignment: .enumeration(Alignment.end.rawValue),
            ])),
            box("middle", sized(10, [.verticalAlignment: .enumeration(Alignment.center.rawValue)])),
        ])
        let columnRenderer = arranged(column, in: NSSize(width: 200, height: 200))
        defer { columnRenderer.closeForTesting() }
        let rowRenderer = arranged(row, in: NSSize(width: 200, height: 100))
        defer { rowRenderer.closeForTesting() }

        XCTAssertEqual(
            columnRenderer.viewForTesting(id: .manual("start"))?.frame,
            NSRect(x: 15, y: 10, width: 30, height: 10))
        XCTAssertEqual(
            columnRenderer.viewForTesting(id: .manual("end"))?.frame,
            NSRect(x: 158, y: 27, width: 30, height: 10))
        XCTAssertEqual(
            columnRenderer.viewForTesting(id: .manual("center"))?.frame,
            NSRect(x: 84, y: 41, width: 30, height: 10))
        XCTAssertEqual(
            rowRenderer.viewForTesting(id: .manual("bottom"))?.frame,
            NSRect(x: 9, y: 86, width: 10, height: 10))
        XCTAssertEqual(
            rowRenderer.viewForTesting(id: .manual("middle"))?.frame,
            NSRect(x: 19, y: 45, width: 10, height: 10))
    }

    /// A child's minimum raises it where it would be smaller, and its maximum
    /// stops it where it would fill.
    @MainActor
    func testAMinimumRaisesAndAMaximumStopsAStacksChild() throws {
        var column = HostPatch(id: .manual("column"), type: .vStack)
        column.children = .arranged([
            box("raised", [
                .height: .number(10),
                .horizontalAlignment: .enumeration(Alignment.start.rawValue),
                .minimumWidth: .number(50),
            ]),
            box("stopped", [.height: .number(10), .maximumWidth: .number(60)]),
        ])
        var row = HostPatch(id: .manual("row"), type: .hStack)
        row.children = .arranged([
            box("tall", [
                .width: .number(10),
                .verticalAlignment: .enumeration(Alignment.start.rawValue),
                .minimumHeight: .number(40),
            ]),
            box("short", [.width: .number(10), .maximumHeight: .number(30)]),
        ])
        let columnRenderer = arranged(column, in: NSSize(width: 200, height: 200))
        defer { columnRenderer.closeForTesting() }
        let rowRenderer = arranged(row, in: NSSize(width: 200, height: 100))
        defer { rowRenderer.closeForTesting() }

        XCTAssertEqual(
            columnRenderer.viewForTesting(id: .manual("raised"))?.frame,
            NSRect(x: 0, y: 0, width: 50, height: 10))
        XCTAssertEqual(
            columnRenderer.viewForTesting(id: .manual("stopped"))?.frame,
            NSRect(x: 70, y: 10, width: 60, height: 10))
        XCTAssertEqual(
            rowRenderer.viewForTesting(id: .manual("tall"))?.frame,
            NSRect(x: 0, y: 0, width: 10, height: 40))
        XCTAssertEqual(
            rowRenderer.viewForTesting(id: .manual("short"))?.frame,
            NSRect(x: 10, y: 35, width: 10, height: 30))
    }

    /// A grid gives its fixed tracks their size and shares what remains among
    /// its proportional ones, keeps its spacing between the tracks and its
    /// padding around them, and stands each child in the cells its row, its
    /// column and its spans name.
    @MainActor
    func testAGridStandsEachChildInTheCellsItNames() throws {
        func track(_ kind: Int32, _ value: Double) -> HostValue {
            .values([.enumeration(kind), .number(value)])
        }
        func cell(_ id: String, row: Int, column: Int, rowSpan: Int = 1, columnSpan: Int = 1) -> HostPatch {
            box(id, [
                .gridRow: .number(Double(row)),
                .gridColumn: .number(Double(column)),
                .gridRowSpan: .number(Double(rowSpan)),
                .gridColumnSpan: .number(Double(columnSpan)),
            ])
        }
        var grid = HostPatch(id: .manual("grid"), type: .grid)
        grid.properties = [
            .rows: .values([track(0, 30), track(1, 1)]),
            .columns: .values([track(0, 50), track(1, 1)]),
            .rowSpacing: .number(5),
            .columnSpacing: .number(10),
            .padding: .numbers([4, 4, 4, 4]),
        ]
        grid.children = .arranged([
            cell("corner", row: 0, column: 0),
            cell("beside", row: 0, column: 1),
            cell("across", row: 1, column: 0, columnSpan: 2),
            cell("down", row: 0, column: 0, rowSpan: 2),
        ])
        let renderer = arranged(grid, in: NSSize(width: 200, height: 100))
        defer { renderer.closeForTesting() }

        XCTAssertEqual(
            renderer.viewForTesting(id: .manual("corner"))?.frame,
            NSRect(x: 4, y: 4, width: 50, height: 30))
        XCTAssertEqual(
            renderer.viewForTesting(id: .manual("beside"))?.frame,
            NSRect(x: 64, y: 4, width: 132, height: 30))
        XCTAssertEqual(
            renderer.viewForTesting(id: .manual("across"))?.frame,
            NSRect(x: 4, y: 39, width: 192, height: 57))
        XCTAssertEqual(
            renderer.viewForTesting(id: .manual("down"))?.frame,
            NSRect(x: 4, y: 4, width: 50, height: 92))
    }

    /// A ZStack stands a child in the area it names, in points or in fractions
    /// of the stack's room.
    @MainActor
    func testAZStackStandsChildrenInTheirAreas() throws {
        var layout = HostPatch(id: .manual("layout"), type: .zStack)
        layout.children = .arranged([
            box("fixed", [.area: Area.absolute(10, 20, 30, 40).propValue]),
            box("proportional", [.area: Area.proportional(0.375, 0.5, 0.25, 0.5).propValue]),
        ])
        let renderer = arranged(layout, in: NSSize(width: 200, height: 100))
        defer { renderer.closeForTesting() }

        XCTAssertEqual(
            renderer.viewForTesting(id: .manual("fixed"))?.frame,
            NSRect(x: 10, y: 20, width: 30, height: 40))
        XCTAssertEqual(
            renderer.viewForTesting(id: .manual("proportional"))?.frame,
            NSRect(x: 75, y: 50, width: 50, height: 50))
    }

    /// A border keeps its padding between its outline and what it holds, and
    /// strokes its outline in its stroke's colour, as wide as its stroke width.
    @MainActor
    func testABorderPadsWhatItHoldsAndStrokesItsOutline() throws {
        var border = HostPatch(id: .manual("border"), type: .border)
        border.properties = [
            .padding: .numbers([4, 6, 8, 10]),
            .background: .color(red: 0, green: 0, blue: 255, alpha: 255),
            .stroke: Brush.solidColor(Color("#FF0000")).propValue,
            .strokeWidth: .number(6),
        ]
        border.children = .arranged([box("inside", [:])])
        let renderer = arranged(border, in: NSSize(width: 100, height: 60))
        defer { renderer.closeForTesting() }

        XCTAssertEqual(
            renderer.viewForTesting(id: .manual("inside"))?.frame,
            NSRect(x: 4, y: 6, width: 88, height: 44))

        let drawn = try bitmap(of: try XCTUnwrap(renderer.viewForTesting(id: .manual("border"))))
        let outline = try XCTUnwrap(drawn.colorAt(x: 2, y: 30))
        let within = try XCTUnwrap(drawn.colorAt(x: 10, y: 30))
        XCTAssertGreaterThan(outline.redComponent, 0.9, "the stroke's colour at the edge")
        XCTAssertLessThan(outline.blueComponent, 0.1)
        XCTAssertGreaterThan(within.blueComponent, 0.9, "the background beyond the stroke's width")
        XCTAssertLessThan(within.redComponent, 0.1)
    }

    /// A scroller keeps its padding around what it holds.
    @MainActor
    func testAScrollViewKeepsItsPaddingAroundWhatItHolds() throws {
        var scroll = HostPatch(id: .manual("scroll"), type: .scrollView)
        scroll.properties = [
            .orientation: .enumeration(ScrollOrientation.horizontal.rawValue),
            .padding: .numbers([5, 3, 11, 7]),
        ]
        scroll.children = .arranged([box("wide", [.width: .number(500), .height: .number(36)])])
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        renderer.applyForTesting(tree(scroll))

        let nativeScroll = try XCTUnwrap(renderer.viewForTesting(id: .manual("scroll")))
        XCTAssertEqual(nativeScroll.intrinsicContentSize, NSSize(width: 516, height: 46))
    }

    // MARK: - Helpers

    private func box(_ id: String, _ properties: [Prop: HostValue]) -> HostPatch {
        var box = HostPatch(id: .manual(id), type: .colorBox)
        box.properties = properties
        return box
    }

    /// A renderer showing `layout` arranged in a room of `size`.
    @MainActor
    private func arranged(_ layout: HostPatch, in size: NSSize) -> AppKitRenderer {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        renderer.applyForTesting(tree(layout))
        if let native = renderer.viewForTesting(id: layout.id) {
            native.frame = NSRect(origin: .zero, size: size)
            native.layoutSubtreeIfNeeded()
        }
        return renderer
    }
}

#endif
