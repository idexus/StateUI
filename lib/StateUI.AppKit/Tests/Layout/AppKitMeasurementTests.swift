// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

/// A change measures only the native views whose size it can change. A frame
/// that moves one view's extent re-measures that view's ancestors and never
/// the unchanged text beside them; a frame that moves only presentation
/// arranges and measures nothing at all.
final class AppKitMeasurementTests: XCTestCase {
    @MainActor
    func testASizeFrameDoesNotMeasureUnchangedTextAgain() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(samplePage())
        let scroll = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("page")) as? AppKitScrollView)
        let code = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("code")) as? AppKitLabelView)
        let box = try XCTUnwrap(renderer.viewForTesting(id: .manual("box")))
        scroll.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        scroll.layoutSubtreeIfNeeded()
        let measuredBeforeMotion = code.nativeMeasurementCountForTesting

        var growing = HostPatch(id: .manual("box"), type: .colorBox)
        growing.properties[.width] = .number(300)
        growing.transitions[.width] = HostTransition(motion: .eased(200, .linear))
        renderer.applyForTesting(path(to: growing))
        scroll.layoutSubtreeIfNeeded()

        now = 100
        renderer.advanceAnimationsForTesting()
        scroll.layoutSubtreeIfNeeded()

        XCTAssertEqual(box.frame.width, 210, accuracy: 0.001)
        XCTAssertEqual(code.nativeMeasurementCountForTesting, measuredBeforeMotion)
    }

    @MainActor
    func testAPresentationOnlyJourneyFrameArrangesAndMeasuresNothing() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var card = HostPatch(id: .manual("card"), type: .colorBox)
        card.properties[.width] = .number(120)
        card.properties[.height] = .number(60)
        card.driven = .replace([
            .translationX: HostStateBinding(state: 91, mode: .inOut, kind: .property),
        ])
        var caption = HostPatch(id: .manual("caption"), type: .label)
        caption.properties[.text] = .string("A card that slides sideways")
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([card, caption])
        var outer = HostPatch(id: .manual("outer"), type: .vStack)
        outer.children = .arranged([stack])
        renderer.applyForTesting(outer)

        let nativeOuter = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("outer")) as? AppKitStackView)
        let nativeStack = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("stack")) as? AppKitStackView)
        let nativeCaption = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("caption")) as? AppKitLabelView)
        let nativeCard = try XCTUnwrap(renderer.viewForTesting(id: .manual("card")))
        nativeOuter.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        nativeOuter.layoutSubtreeIfNeeded()
        let stackArrangements = nativeStack.arrangementCountForTesting
        let outerArrangements = nativeOuter.arrangementCountForTesting
        let captionMeasurements = nativeCaption.nativeMeasurementCountForTesting

        renderer.applyStateForTesting(91, value: HostBoundary.value(of: HostJourney(
            value: [40],
            destination: [60],
            velocity: [0],
            motion: .eased(400, .linear),
            completion: nil,
            stopped: 0)))
        nativeOuter.layoutSubtreeIfNeeded()

        XCTAssertEqual(
            try XCTUnwrap(nativeCard.layer).affineTransform().tx, 40, accuracy: 0.001)
        XCTAssertEqual(nativeStack.arrangementCountForTesting, stackArrangements)
        XCTAssertEqual(nativeOuter.arrangementCountForTesting, outerArrangements)
        XCTAssertEqual(nativeCaption.nativeMeasurementCountForTesting, captionMeasurements)
    }

    @MainActor
    func testChangedNestedTextStillGrowsEveryAncestor() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        renderer.applyForTesting(samplePage())
        let scroll = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("page")) as? AppKitScrollView)
        let frame = try XCTUnwrap(renderer.viewForTesting(id: .manual("frame")))
        let notes = try XCTUnwrap(renderer.viewForTesting(id: .manual("notes")))
        scroll.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        scroll.layoutSubtreeIfNeeded()
        let shortHeight = frame.frame.height

        var longer = HostPatch(id: .manual("notes"), type: .label)
        longer.properties[.text] = .string(
            String(repeating: "Press Size and watch the panel grow smoothly. ", count: 30))
        renderer.applyForTesting(path(to: longer, through: Array(route.dropLast())))
        scroll.layoutSubtreeIfNeeded()

        XCTAssertGreaterThan(frame.frame.height, shortHeight + 20)
        let notesFrame = frame.convert(notes.bounds, from: notes)
        XCTAssertLessThanOrEqual(notesFrame.maxY, frame.bounds.maxY + 0.001)
    }

    @MainActor
    func testASpanTransitionReachesTheLabelThatPresentsIt() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var span = HostPatch(id: .manual("span"), type: .span)
        span.properties[.text] = .string("Sold out")
        span.properties[.textColor] = .color(red: 0, green: 0, blue: 0, alpha: 255)
        var formatted = HostPatch(id: .manual("formatted"), type: .spans)
        formatted.children = .arranged([span])
        var label = HostPatch(id: .manual("label"), type: .label)
        label.children = .arranged([formatted])
        renderer.applyForTesting(label)

        var red = HostPatch(id: .manual("span"), type: .span)
        red.properties[.textColor] = .color(red: 255, green: 0, blue: 0, alpha: 255)
        red.transitions[.textColor] = HostTransition(motion: .eased(200, .linear))
        var formattedPath = HostPatch(id: .manual("formatted"), type: .spans)
        formattedPath.children = .changed([red])
        var labelPath = HostPatch(id: .manual("label"), type: .label)
        labelPath.children = .changed([formattedPath])
        renderer.applyForTesting(labelPath)

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("label")) as? AppKitLabelView)
        func redComponent() throws -> CGFloat {
            let color = try XCTUnwrap(native.attributedStringValue.attribute(
                .foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
            return try XCTUnwrap(color.usingColorSpace(.sRGB)).redComponent
        }

        now = 100
        renderer.advanceAnimationsForTesting()
        let midpoint = try redComponent()
        XCTAssertGreaterThan(midpoint, 0.1)
        XCTAssertLessThan(midpoint, 0.9)

        now = 200
        renderer.advanceAnimationsForTesting()
        XCTAssertEqual(try redComponent(), 1, accuracy: 0.001)
    }

    @MainActor
    func testReapplyingAnUnchangedImageSourceKeepsTheNativeImage() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var image = HostPatch(id: .manual("image"), type: .image)
        image.properties[.source] = .string("picture.png")
        renderer.applyForTesting(image)
        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("image")) as? AppKitImageView)
        let shown = try XCTUnwrap(native.image)

        var faded = HostPatch(id: .manual("image"), type: .image)
        faded.properties[.opacity] = .number(0.5)
        renderer.applyForTesting(faded)

        XCTAssertTrue(native.image === shown)
    }

    @MainActor
    func testAPlacedChildsOwnFrameKeepsItsPlacement() throws {
        var now = 0.0
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var card = HostPatch(id: .manual("card"), type: .colorBox)
        card.properties[.opacity] = .number(1)
        var layout = HostPatch(id: .manual("layout"), type: .zStack)
        layout.driven = .replace([
            .area: HostStateBinding(state: 95, mode: .out, kind: .placement),
        ])
        layout.children = .arranged([card])
        renderer.applyForTesting(layout)
        let run = PlacedRun([Placement(Rect(0, 0, 100, 60), transform: .rotate(30))]).carried
        renderer.applyStateForTesting(95, value: run)

        let nativeLayout = try XCTUnwrap(renderer.viewForTesting(id: .manual("layout")))
        let nativeCard = try XCTUnwrap(renderer.viewForTesting(id: .manual("card")))
        nativeLayout.frame = NSRect(x: 0, y: 0, width: 300, height: 200)
        nativeLayout.layoutSubtreeIfNeeded()
        let placed = try XCTUnwrap(nativeCard.layer).affineTransform()
        XCTAssertEqual(placed.b, sin(30 * .pi / 180), accuracy: 0.001)

        var fading = HostPatch(id: .manual("card"), type: .colorBox)
        fading.properties[.opacity] = .number(0.4)
        fading.transitions[.opacity] = HostTransition(motion: .eased(200, .linear))
        var path = HostPatch(id: .manual("layout"), type: .zStack)
        path.children = .changed([fading])
        renderer.applyForTesting(path)
        // The layout reads its placement from StateUI's state on every apply;
        // this test's state lives only in the host, so it is delivered again.
        renderer.applyStateForTesting(95, value: run)
        nativeLayout.layoutSubtreeIfNeeded()

        now = 100
        renderer.advanceAnimationsForTesting()
        nativeLayout.layoutSubtreeIfNeeded()

        XCTAssertEqual(
            try XCTUnwrap(nativeCard.layer).affineTransform().b, placed.b, accuracy: 0.001)
    }

    /// A placing layout's run moves its children and nothing else: the run is
    /// the layout's own arithmetic over the room it was given, so a frame of it
    /// neither measures the page again nor arranges the layout's parent - what a
    /// run of cards turned by the hand does on every frame.
    @MainActor
    func testAPlacementRunFrameMovesItsChildrenAndMeasuresNothingElse() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var card = HostPatch(id: .manual("card"), type: .colorBox)
        card.properties[.opacity] = .number(1)
        var layout = HostPatch(id: .manual("layout"), type: .zStack)
        layout.properties[.height] = .number(120)
        layout.driven = .replace([
            .area: HostStateBinding(state: 96, mode: .out, kind: .placement),
        ])
        layout.children = .arranged([card])
        var caption = HostPatch(id: .manual("caption"), type: .label)
        caption.properties[.text] = .string("The card in front")
        var outer = HostPatch(id: .manual("outer"), type: .vStack)
        outer.children = .arranged([layout, caption])
        renderer.applyForTesting(outer)
        renderer.applyStateForTesting(96, value: PlacedRun([Placement(Rect(0, 0, 100, 60))]).carried)

        let nativeOuter = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("outer")) as? AppKitStackView)
        let nativeCaption = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("caption")) as? AppKitLabelView)
        let nativeCard = try XCTUnwrap(renderer.viewForTesting(id: .manual("card")))
        nativeOuter.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        nativeOuter.layoutSubtreeIfNeeded()
        let arrangements = nativeOuter.arrangementCountForTesting
        let measurements = nativeCaption.nativeMeasurementCountForTesting

        renderer.applyStateForTesting(96, value: PlacedRun([Placement(Rect(80, 20, 100, 60))]).carried)
        nativeOuter.layoutSubtreeIfNeeded()

        XCTAssertEqual(nativeCard.frame.origin.x, 80, accuracy: 0.001, "the run moved the card")
        XCTAssertEqual(nativeOuter.arrangementCountForTesting, arrangements, "the layout's parent arranged nothing")
        XCTAssertEqual(
            nativeCaption.nativeMeasurementCountForTesting, measurements,
            "nothing beside the layout was measured again")
    }

    /// The containers from the page scroller down to the moving box, in the
    /// order a sparse patch walks them.
    private let route: [(String, NodeType)] = [
        ("page", .scrollView),
        ("content", .vStack),
        ("part", .vStack),
        ("frame", .zStack),
        ("boxed", .vStack),
        ("sample", .vStack),
    ]

    /// A sparse patch reaching one element through its unchanged ancestors.
    private func path(
        to leaf: HostPatch,
        through ancestors: [(String, NodeType)]? = nil
    ) -> HostPatch {
        (ancestors ?? route).reversed().reduce(leaf) { child, ancestor in
            var parent = HostPatch(id: .manual(ancestor.0), type: ancestor.1)
            parent.children = .changed([child])
            return parent
        }
    }

    /// A page shaped like a Gallery sample: an example in a bordered card,
    /// its notes, and a long code listing in a horizontal scroller below it.
    /// A change inside a pane is laid out inside it: a pane gives its page all
    /// of its room, so neither the pane nor anything around it is asked. A
    /// label's report that reached a split view item's glass container held
    /// every scroll event of the Gallery ~90 ms.
    @MainActor
    func testAChangeInsideAPaneIsLaidOutInsideIt() {
        let label = NSTextField(labelWithString: "12")
        let stack = AppKitStackView(axis: .vertical)
        stack.setItems([AppKitLayoutItem(view: label)])
        let page = AppKitSingleChildView()
        page.setItem(AppKitLayoutItem(view: stack))
        let pane = AppKitPaneView()
        pane.setItem(AppKitLayoutItem(view: page))
        let plain = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        plain.addSubview(pane)
        pane.frame = plain.bounds
        let holder = AppKitSingleChildView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        holder.setItem(AppKitLayoutItem(view: plain))
        holder.layoutSubtreeIfNeeded()
        pane.layoutSubtreeIfNeeded()
        for view in [holder, plain, pane, page, stack] {
            XCTAssertFalse(view.needsLayout, "\(type(of: view)) starts laid out")
        }

        label.invalidateMeasurements()

        XCTAssertTrue(stack.needsLayout, "the stack holding the change lays out")
        XCTAssertTrue(page.needsLayout, "and the page")
        XCTAssertFalse(pane.needsLayout, "the pane is not asked")
        XCTAssertFalse(plain.needsLayout, "nor anything around it")
        XCTAssertFalse(holder.needsLayout)
    }

    /// A change inside a window's page is laid out by the page: the window's
    /// content gives its page all of its room and is not asked.
    @MainActor
    func testAChangeInsideAWindowsPageDoesNotAskTheWindow() {
        let label = NSTextField(labelWithString: "12")
        let page = AppKitSingleChildView()
        page.setItem(AppKitLayoutItem(view: label))
        let content = AppKitWindowContentView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        content.set(page: page, overlay: nil)
        content.layoutSubtreeIfNeeded()

        label.invalidateMeasurements()

        XCTAssertTrue(page.needsLayout)
        XCTAssertFalse(content.needsLayout)
    }

    /// A change in a scroller reaches the scroller over the clip view it keeps,
    /// because the scroller measures what it holds.
    @MainActor
    func testAChangeInAScrollerReachesTheScrollerOverItsClipView() {
        let label = NSTextField(labelWithString: "12")
        let scroll = AppKitScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        scroll.setItems([AppKitLayoutItem(view: label)])
        scroll.layoutSubtreeIfNeeded()

        label.invalidateMeasurements()

        XCTAssertTrue(scroll.needsLayout)
    }

    /// A change in a tab reaches its tabbed view over the native tab view,
    /// because the tabbed view measures its pages.
    @MainActor
    func testAChangeInATabReachesItsTabbedView() {
        let label = NSTextField(labelWithString: "12")
        let page = AppKitSingleChildView()
        page.setItem(AppKitLayoutItem(view: label))
        let tabs = AppKitTabbedView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        _ = tabs.setItems(
            [AppKitTabItem(layout: AppKitLayoutItem(view: page), title: "One", image: nil)],
            requestedIndex: 0)
        tabs.layoutSubtreeIfNeeded()

        label.invalidateMeasurements()

        XCTAssertTrue(tabs.needsLayout)
    }

    /// A plain native view that counts how often it is asked its size.
    private final class CountingView: NSView {
        private(set) var measured = 0

        override var intrinsicContentSize: NSSize {
            measured += 1
            return NSSize(width: 40, height: 20)
        }
    }

    /// Every StateUI container measures itself. One a parent measured through
    /// AppKit's fitting built a constraint engine for every question: the
    /// grids of the Gallery's scroll sample, asked again on each scroll report,
    /// held every scroll event ~110 ms.
    @MainActor
    func testEveryContainerMeasuresItself() {
        let containers: [NSView] = [
            AppKitStackView(axis: .vertical),
            AppKitGridView(),
            AppKitZStackView(),
            AppKitNavigationView(),
            AppKitSingleChildView(),
            AppKitScrollView(frame: .zero),
            AppKitTabbedView(frame: .zero),
        ]

        for container in containers {
            XCTAssertTrue(
                container is AppKitWidthConstrainedMeasuring,
                "\(type(of: container)) measures itself")
        }
    }

    /// A grid keeps what it measured: asked again, it asks its children
    /// nothing until something under it changes.
    @MainActor
    func testAGridMeasuredAgainAsksItsChildrenNothing() {
        let child = CountingView()
        let grid = AppKitGridView()
        grid.rows = [.auto]
        grid.columns = [.auto]
        grid.setItems([AppKitLayoutItem(view: child)])

        let first = AppKitLayoutItem(view: grid).fittingSize()
        let measured = child.measured
        let again = AppKitLayoutItem(view: grid).fittingSize()

        XCTAssertEqual(again, first)
        XCTAssertGreaterThan(measured, 0)
        XCTAssertEqual(child.measured, measured, "the grid kept its answer")

        child.invalidateMeasurements()
        _ = AppKitLayoutItem(view: grid).fittingSize()
        XCTAssertGreaterThan(child.measured, measured, "and forgets it when a child changes")
    }

    /// A child that fills its holder is laid out without being measured: its
    /// natural size decides nothing.
    @MainActor
    func testAChildThatFillsItsHolderIsNotMeasuredToBeLaidOut() {
        let child = CountingView()
        let holder = AppKitSingleChildView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        holder.setItem(AppKitLayoutItem(view: child))

        holder.layoutSubtreeIfNeeded()

        XCTAssertEqual(child.frame, holder.bounds)
        XCTAssertEqual(child.measured, 0)
    }

    private func samplePage() -> HostPatch {
        func label(_ id: String, _ text: String) -> HostPatch {
            var label = HostPatch(id: .manual(id), type: .label)
            label.properties[.text] = .string(text)
            label.properties[.fontSize] = .number(13)
            return label
        }

        func node(
            _ id: String,
            _ type: NodeType,
            _ properties: [Prop: HostValue] = [:],
            _ children: [HostPatch]
        ) -> HostPatch {
            var node = HostPatch(id: .manual(id), type: type)
            node.properties = properties
            node.children = .arranged(children)
            return node
        }

        var box = HostPatch(id: .manual("box"), type: .colorBox)
        box.properties[.width] = .number(120)
        box.properties[.height] = .number(56)
        box.properties[.horizontalAlignment] = .enumeration(Alignment.start.rawValue)
        var button = HostPatch(id: .manual("size"), type: .button)
        button.properties[.text] = .string("Size")

        let listing = (1...80)
            .map { "        let line\($0) = panel.width(wide ? 300 : 120) // \($0)" }
            .joined(separator: "\n")

        return node("page", .scrollView, [
            .orientation: .enumeration(ScrollOrientation.vertical.rawValue),
        ], [
            node("content", .vStack, [
                .padding: .numbers([24, 24, 24, 24]),
                .spacing: .number(16),
            ], [
                node("part", .vStack, [.spacing: .number(16)], [
                    label("title", "EXAMPLE"),
                    node("frame", .zStack, [:], [
                        node("boxed", .vStack, [
                            .padding: .numbers([16, 16, 16, 16]),
                            .spacing: .number(10),
                        ], [
                            node("sample", .vStack, [.spacing: .number(10)], [
                                box,
                                node("buttons", .hStack, [.spacing: .number(8)], [button]),
                            ]),
                            label("notes", "Press Size."),
                        ]),
                    ]),
                ]),
                node("listing", .vStack, [.spacing: .number(8)], [
                    label("heading", "IN SWIFT"),
                    node("codeFrame", .zStack, [:], [
                        node("codeScroll", .scrollView, [
                            .orientation: .enumeration(ScrollOrientation.horizontal.rawValue),
                        ], [
                            node("codeStack", .vStack, [:], [label("code", listing)]),
                        ]),
                    ]),
                ]),
            ]),
        ])
    }
}
#endif
