// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
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
        let renderer = AppKitRenderer(
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
        renderer.advanceMotionsForTesting()
        scroll.layoutSubtreeIfNeeded()

        XCTAssertEqual(box.frame.width, 210, accuracy: 0.001)
        XCTAssertEqual(code.nativeMeasurementCountForTesting, measuredBeforeMotion)
    }

    @MainActor
    func testAPresentationOnlyJourneyFrameArrangesAndMeasuresNothing() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
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

        renderer.applyStateForTesting(91, value: StateUIHost.value(of: HostJourney(
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
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
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
        let renderer = AppKitRenderer(
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
        renderer.advanceMotionsForTesting()
        let midpoint = try redComponent()
        XCTAssertGreaterThan(midpoint, 0.1)
        XCTAssertLessThan(midpoint, 0.9)

        now = 200
        renderer.advanceMotionsForTesting()
        XCTAssertEqual(try redComponent(), 1, accuracy: 0.001)
    }

    @MainActor
    func testReapplyingAnUnchangedImageSourceKeepsTheNativeImage() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
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
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            clock: { now },
            reducesMotion: { false })
        defer { renderer.closeForTesting() }

        var card = HostPatch(id: .manual("card"), type: .colorBox)
        card.properties[.opacity] = .number(1)
        var layout = HostPatch(id: .manual("layout"), type: .absoluteLayout)
        layout.driven = .replace([
            .absoluteLayoutBounds: HostStateBinding(state: 95, mode: .out, kind: .placement),
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
        var path = HostPatch(id: .manual("layout"), type: .absoluteLayout)
        path.children = .changed([fading])
        renderer.applyForTesting(path)
        // The layout reads its placement from StateUI's state on every apply;
        // this test's state lives only in the host, so it is delivered again.
        renderer.applyStateForTesting(95, value: run)
        nativeLayout.layoutSubtreeIfNeeded()

        now = 100
        renderer.advanceMotionsForTesting()
        nativeLayout.layoutSubtreeIfNeeded()

        XCTAssertEqual(
            try XCTUnwrap(nativeCard.layer).affineTransform().b, placed.b, accuracy: 0.001)
    }

    /// The containers from the page scroller down to the moving box, in the
    /// order a sparse patch walks them.
    private let route: [(String, NodeType)] = [
        ("page", .scrollView),
        ("content", .vStack),
        ("part", .vStack),
        ("frame", .border),
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
                    node("frame", .border, [:], [
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
                    node("codeFrame", .border, [:], [
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
